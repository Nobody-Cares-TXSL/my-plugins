#!/usr/bin/env bash
# update-pi.sh — 更新 pi（pi coding agent，自更新）
set -euo pipefail

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
# `pi update` 内部会 spawn npm；npm 是 nvm 管理的，必须把对应 node bin 补进 PATH
NVM_BIN="$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1 || true)"
export PATH="${NVM_BIN:+$NVM_BIN:}$HOME/.local/bin:$PATH"

echo "--- Updating pi ---"
if ! command -v pi >/dev/null 2>&1; then
  echo "  pi 未安装，跳过"
  exit 0
fi
# 默认目标是 self（只更新 pi 本身）并打印版本；--all 会连带更新已装扩展
pi update 2>&1
echo ""
echo "--- pi update complete ---"
