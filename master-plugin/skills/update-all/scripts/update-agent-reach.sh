#!/usr/bin/env bash
# update-agent-reach.sh — 更新 agent-reach CLI 并刷新 skill
set -euo pipefail

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
# pip 走国内源（阿里云），不能经代理，否则 SSL 中断
export no_proxy="mirrors.aliyun.com,localhost,127.0.0.1"
export NO_PROXY="$no_proxy"

# 更新 CLI
echo "--- Updating agent-reach CLI ---"
pipx upgrade agent-reach 2>&1
echo ""

# 刷新 skill
# 用上游自己的 place_skill()：它会把 {{VERSION}} 和 {{CHANNEL_TABLE}} 渲染进去，
# 并为各 agent 建链接。手工 git clone + cp 拿到的是未渲染模板（版本号是字面量
# "{{VERSION}}"），这正是此前本地副本坏掉的原因。
# --sync-only 只走 manage.sync()，不会触发 manage.update() 里的 pipx→uv 迁移。
echo "--- Refreshing agent-reach skill ---"
agent-reach update --sync-only 2>&1

echo ""
echo "--- agent-reach update complete ---"
