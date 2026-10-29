#!/usr/bin/env bash
# lib.sh — auto_answer 脚本公共库
#
# 提供：PATH 修复、opencli eval 封装、JS 组装（含答案 JSON 注入）
set -euo pipefail

# BASH_SOURCE[0] 仅在 bash 中存在；被 zsh source 时退回 $0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# NVM 懒加载环境下 opencli 不可见：自动选最新 node 的 bin 目录补进 PATH
_nvm_bin="$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1 || true)"
[ -n "$_nvm_bin" ] && export PATH="$_nvm_bin:$PATH"

command -v opencli >/dev/null 2>&1 || {
  echo "[auto_answer] 找不到 opencli，请先安装：npm install -g @jackwener/opencli" >&2
  exit 1
}

# aa_eval <会话名> <js> —— JS 作为单个 argv 传入，不经 shell 二次解析
# 设 AA_TAB 可显式指定标签页（多标签时 open 与 bind 可能不是同一个）
aa_eval() {
  local session="$1"; shift
  if [ -n "${AA_TAB:-}" ]; then
    opencli browser --session "$session" eval --tab "$AA_TAB" "$1"
  else
    opencli browser --session "$session" eval "$1"
  fi
}

# build_js <主脚本.js> [答案.json]
# 拼接 _common.js + _match.js + 主脚本；给了答案文件则把 __ANSWERS__ 替换为 JSON 字面量
# （json.dumps + ensure_ascii=False：中文不转义，引号由序列化器负责）
build_js() {
  python3 - "$SCRIPT_DIR/js/_common.js" "$SCRIPT_DIR/js/_match.js" "$1" "${2:-}" <<'PY'
import json, sys
common, match, main, ans = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
js = (open(common, encoding='utf-8').read()
      + open(match, encoding='utf-8').read()
      + open(main, encoding='utf-8').read())
if ans:
    payload = json.dumps(json.load(open(ans, encoding='utf-8')), ensure_ascii=False)
    js = js.replace('__ANSWERS__', payload)
sys.stdout.write(js)
PY
}

# aa_ensure_bound <会话名> —— 标签页丢失（about:blank）时自动重新绑定
# 返回 0 表示会话可用；重新 bind 后仍不可用则返回 1
aa_ensure_bound() {
  local session="$1" url
  # 加超时：会话失效时 eval 可能挂起，不能让守卫本身卡死流程
  url="$(timeout 15 opencli browser --session "$session" eval "location.href" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("data",""))' 2>/dev/null || true)"
  case "$url" in
    about:blank|"")
      timeout 30 opencli browser --session "$session" bind >/dev/null 2>&1 || true
      ;;
  esac
}

# aa_upload_file <会话名> <本地文件> —— 把文件注入页面 file input（支持同源 iframe）
# 大文件按块注入 base64，绕过 argv 长度上限；页面侧由 js/upload_file.js 组装
aa_upload_file() {
  local session="$1" file="$2"
  [ -f "$file" ] || { echo "[auto_answer] 文件不存在: $file" >&2; return 1; }

  local tmpdir n i
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/aa_upload.XXXXXX")"
  trap 'rm -rf "$tmpdir"' RETURN

  n="$(python3 - "$file" "$tmpdir" <<'PY'
import base64, json, os, sys
src, out = sys.argv[1], sys.argv[2]
b64 = base64.b64encode(open(src, 'rb').read()).decode()
chunk = 50000
n = (len(b64) + chunk - 1) // chunk
for i in range(n):
    part = b64[i * chunk:(i + 1) * chunk]
    with open(os.path.join(out, 'chunk_%d.js' % i), 'w', encoding='utf-8') as f:
        f.write('window.__aa_chunks=window.__aa_chunks||[];window.__aa_chunks.push(%s);window.__aa_chunks.length'
                % json.dumps(part))
print(n)
PY
)"

  aa_eval "$session" "window.__aa_chunks=[];0" >/dev/null
  for ((i = 0; i < n; i++)); do
    aa_eval "$session" "$(cat "$tmpdir/chunk_$i.js")" >/dev/null
  done

  # 文件名单独注入（供页面侧确定 MIME）
  aa_eval "$session" "window.__aa_file_name=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$(basename "$file")");0" >/dev/null
  aa_eval "$session" "$(build_js "$SCRIPT_DIR/js/upload_file.js")"
}
