#!/usr/bin/env bash
# update-gstack-opencode.sh — 同步 gstack skills 到 opencode 符号链接
set -euo pipefail

: "${TMPDIR:=/tmp}"

GSTACK="$HOME/.claude/skills/gstack"
OCSKILLS="$HOME/.config/opencode/skills"

if [ ! -d "$GSTACK" ]; then
  echo "  gstack not found at $GSTACK"
  exit 0
fi

if [ ! -d "$OCSKILLS" ]; then
  echo "  opencode skills dir not found at $OCSKILLS, creating..."
  mkdir -p "$OCSKILLS"
fi

echo "--- Syncing gstack skills to opencode ---"

# 获取 gstack 仓库中的 skill 列表
# 有效 skill = 有 SKILL.md + name 字段与目录名一致（自动过滤非 skill 目录和 name 重定向）
get_gstack_skills() {
  for d in "$GSTACK"/*/; do
    [ -f "${d}SKILL.md" ] || continue
    dir_name=$(basename "$d")
    skill_name=$(awk '/^name:/{print $2; exit}' "${d}SKILL.md")
    [ -n "$skill_name" ] && [ "$skill_name" = "$dir_name" ] && echo "$dir_name"
  done
}

# 获取 opencode 已有的 gstack 符号链接列表
get_opencode_skills() {
  for d in "$OCSKILLS"/*/; do
    [ -L "${d}SKILL.md" ] && basename "$d" || true
  done
}

GSTACK_LIST=$(get_gstack_skills | sort)
OCLIST=$(get_opencode_skills | sort)

ADDED=$(comm -23 <(echo "$GSTACK_LIST") <(echo "$OCLIST") | tr '\n' ' ')
REMOVED=$(comm -13 <(echo "$GSTACK_LIST") <(echo "$OCLIST") | tr '\n' ' ')

[ -n "$ADDED" ] && echo "  New: $ADDED"
[ -n "$REMOVED" ] && echo "  Removed: $REMOVED"
[ -z "$ADDED$REMOVED" ] && echo "  No changes"

# 新增：创建符号链接
for skill_name in $GSTACK_LIST; do
  link_dir="$OCSKILLS/$skill_name"
  link_file="$link_dir/SKILL.md"
  target="$GSTACK/$skill_name/SKILL.md"

  if [ ! -e "$link_file" ]; then
    mkdir -p "$link_dir"
    ln -sf "$target" "$link_file"
  elif [ "$(readlink -f "$link_file")" != "$(readlink -f "$target")" ]; then
    # 目标路径变了，更新符号链接
    ln -sf "$target" "$link_file"
  fi
done

# 删除：移除不再存在的 gstack skill
for skill_name in $REMOVED; do
  rm -rf "$OCSKILLS/$skill_name"
done

echo ""
echo "--- gstack → opencode sync complete ---"
