#!/usr/bin/env bash
# update-agent-skills.sh — 用 npx skills 更新 ~/.agents/skills 下由它管理的 skill
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

AGENT_SKILLS="$HOME/.agents/skills"
LOCK="$HOME/.agents/.skill-lock.json"
LOG="${TMPDIR:-$HOME/.cache/tmp}/skills-update-$$.log"

cleanup() { rm -f "$LOG" "$LOG.retry"; }
trap cleanup EXIT

# 没有 lock 文件说明 npx skills 没在这个 HOME 装过东西，跳过而不是报错
if [ ! -f "$LOCK" ]; then
  echo "--- npx skills: 未安装（$LOCK 不存在），跳过 ---"
  exit 0
fi

mkdir -p "$(dirname "$LOG")"

# 从输出里提取失败项：上游打印 `✗ Failed to update <name>: <原因>`（无原因时冒号省略），
# 需要先去掉 ANSI 转义与进度行的 \r，否则同一行会混进 spinner 字符
# 只认 "Failed to update"：另外两种失败信息（Cannot update / Failed to check skills from）
# 是 lock 缺字段或整源不可达，重试解决不了，交给最后的告警分支
failed_skills() {
  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g' "$1" \
    | tr -d '\r' \
    | sed -nE 's/^ *✗ Failed to update ([^:]*)(:.*)?$/\1/p' \
    | sed 's/[[:space:]]*$//' \
    | grep -v '^$' \
    | sort -u
}

echo "--- Updating npx-managed skills ($AGENT_SKILLS) ---"
# -g 必须显式指定：cwd 是 $HOME 时 $HOME/.agents/skills 会被 hasProjectSkills() 认成 project skills
# stdin 非 TTY 时上游已删除的 skill 只提示不删除，不会误删本地目录
# 退出码 1 表示有 skill 更新失败，不是「没有可更新项」
rc=0
npx -y skills@latest update -g 2>&1 | tee "$LOG" || rc=$?

# npx skills 会并发 clone 全部来源，代理不稳时部分仓库握手失败。
# 失败的逐个串行重试：单仓库 clone 是稳定的，并发才是失败原因。
FAILED=$(failed_skills "$LOG" || true)
if [ -n "$FAILED" ]; then
  echo ""
  echo "--- 并发阶段失败 $(echo "$FAILED" | wc -l) 个，逐个串行重试 ---"
  still_failed=""
  for skill in $FAILED; do
    echo "  → $skill"
    # 判定依据是 npx 自己的退出码，不是输出字样：失败时它同样打印 ✗ 行，
    # 用 grep 的匹配状态判断会把失败当成功。过滤只为了藏掉进度条。
    retry_rc=0
    npx -y skills@latest update -g "$skill" >"$LOG.retry" 2>&1 || retry_rc=$?
    sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g' "$LOG.retry" | tr '\r' '\n' \
      | grep -E '✓ Updated|✗ Failed|Failed to update' || true
    if [ "$retry_rc" -ne 0 ]; then
      still_failed="$still_failed $skill"
    fi
  done
  if [ -n "$still_failed" ]; then
    echo ""
    echo "  ⚠️  重试后仍失败:$still_failed"
    exit 1
  fi
  echo "  ✅ 全部重试成功"
  rc=0
elif [ "$rc" -ne 0 ]; then
  echo "  ⚠️  npx skills update 退出码 $rc，且未能从输出定位失败项，详见上方输出"
  exit "$rc"
fi

echo ""
echo "--- npx skills update complete ---"
