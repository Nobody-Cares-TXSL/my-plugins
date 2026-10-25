#!/usr/bin/env bash
# update-agent-reach.sh — 更新 agent-reach CLI 并同步 skill 文件
set -euo pipefail

TMPDIR="${TMPDIR:-$HOME/.cache/tmp}"

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
# pip 走国内源（阿里云），不能经代理，否则 SSL 中断
export no_proxy="mirrors.aliyun.com,localhost,127.0.0.1"
export NO_PROXY="$no_proxy"

# 权威内容放 ~/.agents/skills（通用 agent skills 目录），~/.claude/skills 只放符号链接，
# 与 opencli 生态一致；避免两处各存一份真目录导致内容分裂
REACH_SKILL="$HOME/.agents/skills/agent-reach"
CLAUDE_SKILLS="$HOME/.claude/skills"
TMPDIR_AR="$TMPDIR/agent-reach-update-$$"

cleanup() { rm -rf "$TMPDIR_AR"; }
trap cleanup EXIT

# 更新 CLI
echo "--- Updating agent-reach CLI ---"
pipx upgrade agent-reach 2>&1
echo ""

# 同步 skill 文件
echo "--- Syncing agent-reach skill ---"
rm -rf "$TMPDIR_AR"
mkdir -p "$TMPDIR_AR"
git clone --depth 1 https://github.com/Panniantong/Agent-Reach.git "$TMPDIR_AR" 2>&1

mkdir -p "$REACH_SKILL"
rm -rf "${REACH_SKILL:?}"/*
cp -r "$TMPDIR_AR/agent_reach/skill/"* "$REACH_SKILL/"

# ~/.claude/skills 侧改为符号链接，删掉历史遗留的真目录副本
mkdir -p "$CLAUDE_SKILLS"
rm -rf "${CLAUDE_SKILLS:?}/agent-reach"
ln -s ../../.agents/skills/agent-reach "$CLAUDE_SKILLS/agent-reach"

echo ""
echo "--- agent-reach sync complete ---"
