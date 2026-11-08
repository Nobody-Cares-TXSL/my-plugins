#!/usr/bin/env bash
# run-all.sh — 一次跑完插件里所有测试
#
#   tests/*.test.ts              Claude Code mod 测试，需用 claude plugin test（有内建运行时）
#   skills/**/*.test.mjs         Node 原生测试，直接 node 跑
#   skills/**/*.test.sh          Shell 行为测试，直接 bash 跑
#
# 用法：bash tests/run-all.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# NVM 懒加载环境下 node 不可见：自动选最新版本补进 PATH
_nvm_bin="$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1 || true)"
[ -n "$_nvm_bin" ] && export PATH="$_nvm_bin:$PATH"

fail=0

echo "=== Claude Code mod 测试（claude plugin test）==="
if command -v claude >/dev/null 2>&1; then
  if ! claude plugin test . 2>&1 | tail -5; then
    fail=1
  fi
else
  echo "  SKIP claude 不在 PATH"
fi
echo ""

echo "=== Node 测试（*.test.mjs）==="
while IFS= read -r f; do
  echo "--- $f"
  if ! node "$f"; then
    fail=1
  fi
done < <(find skills -name '*.test.mjs' | sort)
echo ""

echo "=== Shell 测试（*.test.sh）==="
while IFS= read -r f; do
  echo "--- $f"
  if ! bash "$f"; then
    fail=1
  fi
done < <(find skills -name '*.test.sh' | sort)

echo ""
if [ "$fail" -eq 0 ]; then
  echo "全部通过"
else
  echo "有测试失败"
fi
exit "$fail"
