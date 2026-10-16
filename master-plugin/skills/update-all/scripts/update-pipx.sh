#!/usr/bin/env bash
# update-pipx.sh — 更新所有 pipx 安装的 CLI
set -euo pipefail

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
# pip 走国内源（清华），不能经代理，否则 SSL 中断
export no_proxy="pypi.tuna.tsinghua.edu.cn,localhost,127.0.0.1"
export NO_PROXY="$no_proxy"

echo "--- Updating pipx packages ---"
pipx upgrade-all 2>&1
echo ""
echo "--- pipx update complete ---"
