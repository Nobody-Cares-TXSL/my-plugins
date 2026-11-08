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
# 先克隆到 staging 并校验，再替换正式目录：上游结构变化时不能先把旧内容删空
echo "--- Syncing agent-reach skill ---"
rm -rf "$TMPDIR_AR"
mkdir -p "$TMPDIR_AR"
git clone --depth 1 https://github.com/Panniantong/Agent-Reach.git "$TMPDIR_AR" 2>&1

SRC_SKILL="$TMPDIR_AR/agent_reach/skill"
if [ ! -f "$SRC_SKILL/SKILL.md" ]; then
  echo "上游 skill 结构异常：$SRC_SKILL/SKILL.md 不存在，未改动本地副本" >&2
  exit 1
fi

# 组装完整副本，成功后再用目录交换替换：避免 rm 后 cp 失败导致目录半空
NEW="$REACH_SKILL.new.$$"
OLD="$REACH_SKILL.old.$$"
mkdir -p "$(dirname "$REACH_SKILL")"
rm -rf "$NEW"
cp -r "$SRC_SKILL" "$NEW"
[ -f "$NEW/SKILL.md" ] || { echo "组装失败：$NEW/SKILL.md 缺失，未改动本地副本" >&2; rm -rf "$NEW"; exit 1; }

# 交换：旧目录先改名，新目录就位，再删旧
if [ -e "$REACH_SKILL" ]; then mv "$REACH_SKILL" "$OLD"; fi
mv "$NEW" "$REACH_SKILL"
rm -rf "$OLD"

# ~/.claude/skills 侧改为符号链接，删掉历史遗留的真目录副本
mkdir -p "$CLAUDE_SKILLS"
if [ -e "$CLAUDE_SKILLS/agent-reach" ] && [ ! -L "$CLAUDE_SKILLS/agent-reach" ]; then
  echo "警告：$CLAUDE_SKILLS/agent-reach 是真实目录而非符号链接，已备份为 .bak 后替换" >&2
  mv "$CLAUDE_SKILLS/agent-reach" "$CLAUDE_SKILLS/agent-reach.bak"
fi
ln -sfn ../../.agents/skills/agent-reach "$CLAUDE_SKILLS/agent-reach"

echo ""
echo "--- agent-reach sync complete ---"
