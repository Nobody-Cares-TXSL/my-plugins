#!/usr/bin/env bash
# update-opencli.sh — 更新 opencli CLI 并同步 skills
set -euo pipefail

: "${TMPDIR:=/tmp}"

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

AGENT_SKILLS="$HOME/.agents/skills"
SKILLS_DIR="$HOME/.claude/skills"
TMPDIR_OPENCLI="$TMPDIR/opencli-update-$$"

cleanup() { rm -rf "$TMPDIR_OPENCLI"; }
trap cleanup EXIT

# 更新 CLI
echo "--- Updating opencli CLI ---"
npm update -g @jackwener/opencli 2>&1
echo ""

# 克隆最新 skills
echo "--- Syncing opencli skills ---"
rm -rf "$TMPDIR_OPENCLI"
mkdir -p "$TMPDIR_OPENCLI"
git clone --depth 1 https://github.com/jackwener/opencli.git "$TMPDIR_OPENCLI" 2>&1

# 获取远程和本地 skill 列表
get_skill_names() {
  local base="$1"
  for f in "$base"/*/SKILL.md; do
    [ -f "$f" ] && basename "$(dirname "$f")" || true
  done
}

REMOTE=$(get_skill_names "$TMPDIR_OPENCLI/skills" | sort)
LOCAL=$(get_skill_names "$AGENT_SKILLS" | sort)

# 检测增删
ADDED=$(comm -23 <(echo "$REMOTE") <(echo "$LOCAL") | tr '\n' ' ')
REMOVED=$(comm -13 <(echo "$REMOTE") <(echo "$LOCAL") | tr '\n' ' ')
UPDATED=$(comm -12 <(echo "$REMOTE") <(echo "$LOCAL") | tr '\n' ' ')

[ -n "$ADDED" ] && echo "  New: $ADDED"
[ -n "$REMOVED" ] && echo "  Removed: $REMOVED"
[ -n "$UPDATED" ] && echo "  Updated: $UPDATED"
[ -z "$ADDED$REMOVED$UPDATED" ] && echo "  No changes"

# 同步：更新已有 + 新增
for skill_name in $REMOTE; do
  mkdir -p "$AGENT_SKILLS/$skill_name"
  cp -r "$TMPDIR_OPENCLI/skills/$skill_name/"* "$AGENT_SKILLS/$skill_name/"
done

# 清理：只删除不再存在的 opencli skill 的符号链接（不删目录，不动非 opencli skill）
for skill_name in $REMOVED; do
  [ -L "$SKILLS_DIR/$skill_name" ] && rm "$SKILLS_DIR/$skill_name"
  [ -L "$AGENT_SKILLS/$skill_name" ] && rm "$AGENT_SKILLS/$skill_name"
done

# 重建 symlinks（只重建 opencli repo 中的 skills）
for skill_name in $REMOTE; do
  link_path="$SKILLS_DIR/$skill_name"
  ln -sf ../../.agents/skills/"$skill_name" "$link_path"
done

echo ""
echo "--- opencli sync complete ---"
