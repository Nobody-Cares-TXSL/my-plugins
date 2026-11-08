#!/usr/bin/env bash
# update-opencli.sh — 更新 opencli CLI 并同步 skills
set -euo pipefail

TMPDIR="${TMPDIR:-$HOME/.cache/tmp}"

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
# 单包 npm update 同样重算依赖树，先查再装
# npm outdated 有更新时返回 1，网络故障时输出为空；只看退出码会把两者混为一谈
rc=0
outdated=$(npm outdated -g @jackwener/opencli 2>/dev/null) || rc=$?
if [ -n "$outdated" ]; then
  npm update -g @jackwener/opencli 2>&1
elif [ "$rc" -eq 0 ]; then
  echo "  ✅ 已是最新"
else
  echo "  ⚠️  npm outdated 检查失败（退出码 $rc），跳过 opencli 更新"
fi
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
# 本地只统计 opencli 生态的 skill（opencli-* 前缀 + smart-search），
# 避免把独立 skill（find-skills、tdd 等）误判为"已移除"
# 首次运行时本地一个都没有，grep 无匹配返回 1，在 pipefail 下会直接终止脚本
LOCAL=$(get_skill_names "$AGENT_SKILLS" | grep -E '^(opencli-|smart-search$)' | sort || true)

# 检测增删
ADDED=$(comm -23 <(echo "$REMOTE") <(echo "$LOCAL") | tr '\n' ' ')
REMOVED=$(comm -13 <(echo "$REMOTE") <(echo "$LOCAL") | tr '\n' ' ')
UPDATED=$(comm -12 <(echo "$REMOTE") <(echo "$LOCAL") | tr '\n' ' ')

[ -n "$ADDED" ] && echo "  New: $ADDED"
[ -n "$REMOVED" ] && echo "  Removed: $REMOVED"
[ -n "$UPDATED" ] && echo "  Updated: $UPDATED"
[ -z "$ADDED$REMOVED$UPDATED" ] && echo "  No changes"

# 同步：更新已有 + 新增
# 用 rsync --delete 而不是 cp -r：上游删掉的文件也要从本地消失，
# 否则残留文件会让 Codex/Claude 继续发现已废弃的内容
for skill_name in $REMOTE; do
  mkdir -p "$AGENT_SKILLS/$skill_name"
  rsync -a --delete "$TMPDIR_OPENCLI/skills/$skill_name/" "$AGENT_SKILLS/$skill_name/"
done

# 清理：只删除不再存在的 opencli skill 的符号链接（不删目录，不动非 opencli skill）
for skill_name in $REMOVED; do
  [ -L "$SKILLS_DIR/$skill_name" ] && rm "$SKILLS_DIR/$skill_name"
  [ -L "$AGENT_SKILLS/$skill_name" ] && rm "$AGENT_SKILLS/$skill_name"
done

# 重建 symlinks（只重建 opencli repo 中的 skills）
# 目标是真实目录时不能静默覆盖（ln -sf 会在目录内建同名链接），先备份
for skill_name in $REMOTE; do
  link_path="$SKILLS_DIR/$skill_name"
  mkdir -p "$SKILLS_DIR"
  if [ -e "$link_path" ] && [ ! -L "$link_path" ]; then
    echo "  警告：$link_path 是真实目录，已备份为 .bak 后改为符号链接" >&2
    mv "$link_path" "$link_path.bak"
  fi
  ln -sfn ../../.agents/skills/"$skill_name" "$link_path"
done

echo ""
echo "--- opencli sync complete ---"
