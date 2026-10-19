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
    opencli browser "$session" eval "$1" --tab "$AA_TAB"
  else
    opencli browser "$session" eval "$1"
  fi
}

# build_js <主脚本.js> [答案.json]
# 拼接 _common.js + 主脚本；给了答案文件则把 __ANSWERS__ 替换为 JSON 字面量
# （json.dumps + ensure_ascii=False：中文不转义，引号由序列化器负责）
build_js() {
  python3 - "$SCRIPT_DIR/js/_common.js" "$1" "${2:-}" <<'PY'
import json, sys
common, main, ans = sys.argv[1], sys.argv[2], sys.argv[3]
js = open(common, encoding='utf-8').read() + open(main, encoding='utf-8').read()
if ans:
    payload = json.dumps(json.load(open(ans, encoding='utf-8')), ensure_ascii=False)
    js = js.replace('__ANSWERS__', payload)
sys.stdout.write(js)
PY
}
