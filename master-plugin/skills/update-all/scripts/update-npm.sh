#!/usr/bin/env bash
# update-npm.sh — 更新所有 npm 全局包（开发工具链锁定大版本）
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

# 开发工具链：只升小版本，跨大版本时回退（大版本变更易破坏环境）
LOCKED_TOOLS="npm pnpm corepack"

# 返回版本比较键：major>0 时用 major，0.x 包用 "0.minor"（0.x 的 minor 变更即破坏性）
major_of() {
  local pkg_json
  pkg_json="$(npm root -g)/$1/package.json"
  [ -f "$pkg_json" ] || return 1
  python3 -c '
import json, sys
parts = json.load(open(sys.argv[1]))["version"].split(".")
print(parts[0] if parts[0] != "0" else "0." + parts[1])
' "$pkg_json"
}

declare -A MAJOR_BEFORE
for tool in $LOCKED_TOOLS; do
  MAJOR_BEFORE[$tool]=$(major_of "$tool" || echo "")
done

echo "--- Updating npm global packages ---"
npm update -g 2>&1
echo ""

echo "--- 检查开发工具链大版本 ---"
for tool in $LOCKED_TOOLS; do
  before="${MAJOR_BEFORE[$tool]}"
  after=$(major_of "$tool" || echo "")
  if [ -z "$before" ] || [ -z "$after" ]; then
    continue
  fi
  if [ "$before" != "$after" ]; then
    echo "  ⚠️  $tool 跨大版本 $before → $after，回退到 $before.x"
    npm install -g "$tool@$before" 2>&1 | tail -3
  else
    echo "  ✅ $tool 保持 $after.x"
  fi
done

echo ""
echo "--- npm update complete ---"
