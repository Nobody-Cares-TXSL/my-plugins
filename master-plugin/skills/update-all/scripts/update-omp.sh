#!/usr/bin/env bash
# update-omp.sh — 更新 omp（@oh-my-pi/pi-coding-agent，bun 全局安装）
set -euo pipefail

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

echo "--- Updating omp ---"
if ! command -v omp >/dev/null 2>&1; then
  echo "  omp 未安装，跳过"
  exit 0
fi
# omp update 自带检查 + 安装并打印当前版本；--check 才是只查不装
omp update 2>&1
echo ""
echo "--- omp update complete ---"
