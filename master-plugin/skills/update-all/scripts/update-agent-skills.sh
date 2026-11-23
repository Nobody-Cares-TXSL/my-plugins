#!/usr/bin/env bash
# update-agent-skills.sh — 用 npx skills 更新 ~/.agents/skills 下由它管理的 skill
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

AGENT_SKILLS="$HOME/.agents/skills"
LOCK="$HOME/.agents/.skill-lock.json"

# 没有 lock 文件说明 npx skills 没在这个 HOME 装过东西，跳过而不是报错
if [ ! -f "$LOCK" ]; then
  echo "--- npx skills: 未安装（$LOCK 不存在），跳过 ---"
  exit 0
fi

# npx skills 默认 4 路并发 clone（上游 DEFAULT_FETCH_CONCURRENCY），走代理时并发握手
# 容易被掐断，报 gnutls_handshake() failed。降到 2 路是从源头避免，比重试更根本。
# 该变量未写入 --help，但 cli.mjs 的 fetchConcurrency() 读取它，且与同族的
# SKILLS_CLONE_TIMEOUT_MS 一样是有意的调优入口。调用方已设则尊重。
export SKILLS_CLONE_CONCURRENCY="${SKILLS_CLONE_CONCURRENCY:-2}"

# 跑 npx skills 并过滤输出：成功时剥掉 spinner/ANSI，只留结果行（原输出 30KB+，结果仅十几行）；
# 失败时保留完整输出供排查。返回真实退出码。
_run_skills_update() {
  local conc="$1" out rc=0
  out="$(SKILLS_CLONE_CONCURRENCY="$conc" npx -y skills@latest update -g 2>&1)" || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '%s\n' "$out" \
      | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g; s/\r/\n/g' \
      | grep -aE 'Found|Updated|updated|✓|✗|complete|skipp|No updates?' || true
  else
    printf '%s\n' "$out"
  fi
  return "$rc"
}

echo "--- Updating npx-managed skills ($AGENT_SKILLS) ---"
# -g 必须显式指定：cwd 是 $HOME 时 $HOME/.agents/skills 会被 hasProjectSkills() 认成 project skills
# stdin 非 TTY 时上游已删除的 skill 只提示不删除，不会误删本地目录
# 退出码 1 表示有 skill 更新失败，不是「没有可更新项」
rc=0
_run_skills_update "$SKILLS_CLONE_CONCURRENCY" || rc=$?

# 降并发后仍可能偶发失败（代理瞬时抖动）。整轮重跑一次即可：
# update 是幂等的，已最新的 skill 会被跳过，不必解析输出定位具体哪一项。
if [ "$rc" -ne 0 ]; then
  echo ""
  echo "--- 首轮失败（退出码 $rc），降为单路并发重跑一次 ---"
  rc=0
  _run_skills_update 1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo ""
    echo "  ⚠️  npx skills update 仍失败（退出码 $rc），详见上方输出"
    exit "$rc"
  fi
  echo "  ✅ 重跑成功"
fi

echo ""
echo "--- npx skills update complete ---"
