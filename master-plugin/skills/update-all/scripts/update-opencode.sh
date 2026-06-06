#!/usr/bin/env bash
# update-opencode.sh — 更新 opencode CLI
set -euo pipefail

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

echo "=== 更新 opencode CLI ==="
if command -v opencode &>/dev/null; then
  echo "当前版本: $(opencode --version 2>&1 | head -1)"
  opencode upgrade --method curl 2>&1
  echo "更新后版本: $(opencode --version 2>&1 | head -1)"
else
  echo "opencode 未安装，跳过"
fi
