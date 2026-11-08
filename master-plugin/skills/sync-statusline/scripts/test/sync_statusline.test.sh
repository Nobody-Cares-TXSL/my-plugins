#!/usr/bin/env bash
# sync_statusline.test.sh — sync-statusline.sh 回归测试
#
# 核心用例：缓存目录里并存多个版本（2.0.10 / 2.0.27），字符串排序会把 2.0.10
# 排在前面、2.0.9 排到最后。脚本必须读 installed_plugins.json 指向的那一份，
# 否则状态栏会静默显示旧版本注册的命令名。
#
# 用法：bash sync_statusline.test.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sync-statusline.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/slstest.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass=0 fail=0
ok()  { pass=$((pass + 1)); echo "  ok  $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ -n "${2:-}" ] && echo "       $2"; }

# 搭一个假 HOME：两个版本目录，旧版本注册 OLDVER，新版本注册 NEWVER，
# installed_plugins.json 指向新版本。
make_fixture() {
  local home="$1"
  local cache="$home/.claude/plugins/cache/mkt/plug"
  mkdir -p "$cache/2.0.10/hooks" "$cache/2.0.27/hooks" "$home/.claude/skills"
  for pair in "2.0.10:OLDVER" "2.0.27:NEWVER"; do
    local v="${pair%%:*}" n="${pair##*:}"
    printf '{"modules":["./register.js"]}\n' > "$cache/$v/hooks/hooks.json"
    cat > "$cache/$v/hooks/register.js" <<EOF
export function register(on) {
  on('session.start', async (\$, e, next) => {
    await \$.command.register({ name: '$n' })
    return next(e)
  })
}
EOF
  done
  printf '{"enabledPlugins":{"plug@mkt":true}}\n' > "$home/.claude/settings.json"
  cat > "$home/.claude/plugins/installed_plugins.json" <<EOF
{"plugins":{"plug@mkt":[{"scope":"user","installPath":"$cache/2.0.27","version":"2.0.27"}]}}
EOF
  printf '# >>> sync-statusline: mods >>>\n# <<< sync-statusline: mods <<<\n# >>> sync-statusline: plugin >>>\n# <<< sync-statusline: plugin <<<\n' > "$home/.claude/statusline.zsh"
}

run_with_fixture() {
  local home="$1"
  # labels.txt 在脚本同目录，用 sed 换成本次的临时映射表
  local labels="$home/labels.txt"
  printf '# --- mods ---\nOLDVER\t/oldver:旧\nNEWVER\t/newver:新\n# --- ownmods ---\n# --- plugin ---\n' > "$labels"
  local runner="$home/runner.sh"
  sed "s|LABELS=\"\$SCRIPT_DIR/labels.txt\"|LABELS=\"$labels\"|" "$SCRIPT" > "$runner"
  HOME="$home" bash "$runner" --dry-run 2>&1
}

# ---------- 1. 选 installed_plugins 指向的版本 ----------

test_picks_installed_version() {
  local name="读 installed_plugins 指向的版本（2.0.27 而非排序靠前的 2.0.10）"
  local home="$TMP_ROOT/h1"
  make_fixture "$home"
  local out
  out=$(run_with_fixture "$home")
  if grep -q '/newver' <<<"$out" && ! grep -q '/oldver' <<<"$out"; then
    ok "$name"
  else
    bad "$name" "输出: $(tr '\n' ' ' <<<"$out")"
  fi
}

# ---------- 2. 无 installed 记录时回退扫缓存 ----------

test_falls_back_to_cache() {
  local name="installed_plugins.json 缺失时回退扫缓存目录"
  local home="$TMP_ROOT/h2"
  make_fixture "$home"
  rm -f "$home/.claude/plugins/installed_plugins.json"
  local out
  out=$(run_with_fixture "$home")
  # 没有 installed 时按字符串排序取第一个（2.0.10），至少不能崩溃、不能空输出
  if grep -qE '/oldver|/newver' <<<"$out"; then
    ok "$name"
  else
    bad "$name" "回退后无输出: $(tr '\n' ' ' <<<"$out")"
  fi
}

# ---------- 3. 脚本能递归跟进 import ----------

test_follows_imports() {
  local name="递归跟进 register.js 的 import 链"
  local home="$TMP_ROOT/h3"
  local cache="$home/.claude/plugins/cache/mkt/plug/2.0.27/hooks"
  mkdir -p "$cache" "$home/.claude/skills"
  printf '{"modules":["./register.js"]}\n' > "$cache/hooks.json"
  printf "import { register as r } from './mod-a.js'\nexport function register(on){ r(on) }\n" > "$cache/register.js"
  cat > "$cache/mod-a.js" <<'EOF'
export function register(on) {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'FROMIMPORT' })
    return next(e)
  })
}
EOF
  printf '{"enabledPlugins":{"plug@mkt":true}}\n' > "$home/.claude/settings.json"
  printf '{"plugins":{"plug@mkt":[{"installPath":"%s"}]}}\n' \
    "$home/.claude/plugins/cache/mkt/plug/2.0.27" > "$home/.claude/plugins/installed_plugins.json"
  printf '# >>> sync-statusline: mods >>>\n# <<< sync-statusline: mods <<<\n# >>> sync-statusline: plugin >>>\n# <<< sync-statusline: plugin <<<\n' > "$home/.claude/statusline.zsh"
  printf '# --- mods ---\nFROMIMPORT\t/fromimport:导入\n# --- ownmods ---\n# --- plugin ---\n' > "$home/labels.txt"
  local runner="$home/runner.sh"
  sed "s|LABELS=\"\$SCRIPT_DIR/labels.txt\"|LABELS=\"$home/labels.txt\"|" "$SCRIPT" > "$runner"
  local out
  out=$(HOME="$home" bash "$runner" --dry-run 2>&1)
  if grep -q '/fromimport' <<<"$out"; then
    ok "$name"
  else
    bad "$name" "未扫到 import 进来的命令: $(tr '\n' ' ' <<<"$out")"
  fi
}

echo "--- sync-statusline 测试 ---"
test_picks_installed_version
test_falls_back_to_cache
test_follows_imports

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
