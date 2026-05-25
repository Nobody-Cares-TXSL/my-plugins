#!/usr/bin/env bash
# update-agent-reach.sh — 更新 agent-reach CLI 并同步 skill 文件
set -euo pipefail

: "${TMPDIR:=/tmp}"

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

REACH_SKILL="$HOME/.claude/skills/agent-reach"
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

rm -rf "$REACH_SKILL"/*
cp -r "$TMPDIR_AR/agent_reach/skill/"* "$REACH_SKILL/"

echo ""
echo "--- agent-reach sync complete ---"
