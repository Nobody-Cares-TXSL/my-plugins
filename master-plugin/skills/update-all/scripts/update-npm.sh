#!/usr/bin/env bash
# update-npm.sh — 更新所有 npm 全局包
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

echo "--- Updating npm global packages ---"
npm update -g 2>&1
echo ""
echo "--- npm update complete ---"
