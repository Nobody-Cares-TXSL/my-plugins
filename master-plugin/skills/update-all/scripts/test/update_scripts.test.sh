#!/usr/bin/env bash
# update_scripts.test.sh — update-all 脚本行为回归测试
#
# 覆盖本次修复的两处：
#   1. enabledPlugins 只取值为 true 的插件（禁用插件不得被更新/误报为 enabled）
#   2. check-hard-updates.sh 下载失败时保留原有同名文件（不能先截断再失败）
#
# 用法：bash update_scripts.test.sh
set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/updtest.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass=0 fail=0
ok()   { pass=$((pass + 1)); echo "  ok  $1"; }
bad()  { fail=$((fail + 1)); echo "  FAIL $1"; [ -n "${2:-}" ] && echo "       $2"; }

# ---------- 1. enabledPlugins 布尔过滤 ----------

test_enabled_filter() {
  local name="enabledPlugins 只取 true"
  local home="$TMP_ROOT/home1"
  mkdir -p "$home/.claude"
  cat > "$home/.claude/settings.json" <<'EOF'
{"enabledPlugins":{"on-a@m":true,"off-b@m":false,"on-c@m":true,"weird@m":"yes"}}
EOF
  # 只验证 python 提取逻辑本身（不真跑 claude plugin update）
  local got
  got=$(HOME="$home" python3 -c "
import json
d = json.load(open('$home/.claude/settings.json'))
for k, v in d.get('enabledPlugins', {}).items():
    if v is True:
        print(k)
" | sort | tr '\n' ' ')
  [ "$got" = "on-a@m on-c@m " ] && ok "$name" || bad "$name" "得到: $got"
}

# 校验 update-plugins.sh 里确实用了布尔判断，而不是只读键名
test_script_uses_bool() {
  local name="update-plugins.sh 使用布尔判断"
  if grep -q 'if v is True' "$SCRIPTS_DIR/update-plugins.sh"; then
    ok "$name"
  else
    bad "$name" "未找到 'if v is True'"
  fi
}

test_snapshot_uses_bool() {
  local name="snapshot.sh 使用布尔判断"
  if grep -q 'if v is True' "$SCRIPTS_DIR/snapshot.sh"; then
    ok "$name"
  else
    bad "$name" "未找到 'if v is True'"
  fi
}

# ---------- 2. 下载失败保留原文件 ----------

test_download_keeps_existing() {
  local name="下载失败时保留原有文件"
  local home="$TMP_ROOT/home2"
  mkdir -p "$home/下载"
  printf 'ORIGINAL-CONTENT' > "$home/下载/prog.tar.gz"
  # 起一个本地 HTTP 服务返回 404：curl -f 会判定失败，但连接是通的，
  # 这样才能复现"目标已被打开/截断后才失败"的场景（连不上时 curl 不会创建文件）
  local port
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
  # serve_forever + 后台超时自杀：curl 可能发多次请求（重试/探测），只 handle 一次会卡住
  timeout 20 python3 - "$port" <<'PY2' &
import http.server, socketserver, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        # 声明 2MB 却只发 4KB 后断开：curl 会先把已收到的字节写进 -o 目标再报错，
        # 这正是"下载失败却毁掉原文件"的真实形态（404 页面不写盘，测不出来）
        self.send_response(200)
        self.send_header("Content-Length", str(2 * 1024 * 1024))
        self.end_headers()
        self.wfile.write(b"X" * 4096)
        self.wfile.flush()
        self.close_connection = True
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", int(sys.argv[1])), H) as s:
    s.serve_forever()
PY2
  local srv=$!
  sleep 1
  local out
  # 脚本内部会设 http_proxy，本地请求必须走 no_proxy，否则被代理转走
  out=$(HOME="$home" no_proxy="127.0.0.1,localhost" NO_PROXY="127.0.0.1,localhost" \
    timeout 30 bash "$SCRIPTS_DIR/check-hard-updates.sh" --download "http://127.0.0.1:$port/prog.tar.gz" "$home/.local/bin/prog" 2>&1 || true)
  kill "$srv" 2>/dev/null || true
  wait "$srv" 2>/dev/null || true
  local content
  content=$(cat "$home/下载/prog.tar.gz" 2>/dev/null)
  if [ "$content" = "ORIGINAL-CONTENT" ]; then
    ok "$name"
  else
    bad "$name" "原文件被改动，现在内容: '$content'"
  fi
  # 临时文件不应残留
  local leftovers
  leftovers=$(find "$home/下载" -name '.prog.tar.gz.*' 2>/dev/null | wc -l)
  if [ "$leftovers" -eq 0 ]; then
    ok "下载失败后无临时文件残留"
  else
    bad "下载失败后无临时文件残留" "残留 $leftovers 个"
  fi
}

# ---------- 3. 只读模式不创建下载目录 ----------

test_discover_is_readonly() {
  local name="discover 模式不创建 ~/下载"
  local home="$TMP_ROOT/home3"
  mkdir -p "$home"
  HOME="$home" bash "$SCRIPTS_DIR/check-hard-updates.sh" >/dev/null 2>&1 || true
  if [ ! -d "$home/下载" ]; then
    ok "$name"
  else
    bad "$name" "discover 创建了 ~/下载"
  fi
}

# ---------- 4. zip 安装命令带 sudo ----------

test_zip_sudo() {
  local name="zip 分支 unzip 带 sudo"
  if grep -q '\${sudo}unzip' "$SCRIPTS_DIR/check-hard-updates.sh"; then
    ok "$name"
  else
    bad "$name" "unzip 前缺少 sudo"
  fi
}

# ---------- 5. npx skills 更新脚本 ----------

# 无 lock 文件时应静默跳过（退出 0），不能报错中断全量流程
test_agent_skills_no_lock() {
  local name="update-agent-skills.sh 无 lock 时跳过"
  local home="$TMP_ROOT/home5"
  mkdir -p "$home"
  local out rc=0
  out=$(HOME="$home" bash "$SCRIPTS_DIR/update-agent-skills.sh" 2>&1) || rc=$?
  if [ "$rc" -eq 0 ] && echo "$out" | grep -q '未安装'; then
    ok "$name"
  else
    bad "$name" "退出码 $rc，输出: $out"
  fi
}

# 必须显式 -g：否则 cwd=$HOME 时 ~/.agents/skills 会被判成 project skills
test_agent_skills_uses_global_flag() {
  local name="update-agent-skills.sh 传 -g"
  if grep -q 'skills@latest update -g' "$SCRIPTS_DIR/update-agent-skills.sh"; then
    ok "$name"
  else
    bad "$name" "未找到 'skills@latest update -g'"
  fi
}

# 失败项解析：只认 "Failed to update <name>"，不能把 Cannot update /
# Failed to check skills from 当成可重试项（那是 lock 缺字段或整源不可达）
test_agent_skills_failure_parser() {
  local name="失败项解析只取可重试的技能名"
  local log="$TMP_ROOT/skills-fail.log"
  printf '\033[38;5;145mUpdating grilling…\033[0m\n' > "$log"
  printf '  \033[38;5;102m✗ Failed to update grilling: Failed to clone https://x: gnutls_handshake() failed\033[0m\n' >> "$log"
  printf '  \033[38;5;102m✗ Failed to update tdd: Failed to clone x\033[0m\n' >> "$log"
  printf '  \033[38;5;102m✗ Cannot update foo: lock file is missing sourceUrl\033[0m\n' >> "$log"
  printf '  \033[38;5;102m✗ Failed to check skills from https://x\033[0m\n' >> "$log"
  printf '  \033[38;5;145m✓ Updated opencli-usage\033[0m\n' >> "$log"
  # 直接复用脚本里的提取逻辑，避免测试与实现漂移
  local got
  got=$(sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g' "$log" | tr -d '\r' \
        | sed -nE 's/^ *✗ Failed to update ([^:]*)(:.*)?$/\1/p' \
        | sed 's/[[:space:]]*$//' | grep -v '^$' | sort -u | tr '\n' ' ')
  if [ "$got" = "grilling tdd " ]; then
    ok "$name"
  else
    bad "$name" "得到: '$got'"
  fi
}

# 重试判定必须看 npx 的退出码：失败时它也打印 ✗ 行，
# 用 grep 匹配状态判断会把失败误当成功
test_agent_skills_retry_uses_exit_code() {
  local name="重试按退出码判定而非输出匹配"
  if grep -q 'retry_rc=\$?' "$SCRIPTS_DIR/update-agent-skills.sh" \
     && grep -q '\[ "\$retry_rc" -ne 0 \]' "$SCRIPTS_DIR/update-agent-skills.sh"; then
    ok "$name"
  else
    bad "$name" "未找到 retry_rc 的退出码判定"
  fi
}

echo "--- update-all 脚本测试 ---"
test_enabled_filter
test_script_uses_bool
test_snapshot_uses_bool
test_download_keeps_existing
test_discover_is_readonly
test_zip_sudo
test_agent_skills_no_lock
test_agent_skills_uses_global_flag
test_agent_skills_failure_parser
test_agent_skills_retry_uses_exit_code

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
