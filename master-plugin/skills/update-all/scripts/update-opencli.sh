#!/usr/bin/env bash
# update-opencli.sh — 更新 opencli CLI
#
# skill 不在这里同步：opencli-* 与 smart-search 都已登记在 ~/.agents/.skill-lock.json
# （source 均为 jackwener/opencli），由 update-agent-skills.sh 通过 npx skills 统一更新。
# 此前这里另有一份 git clone + rsync + 建链的实现，与 npx 争同一批目录，
# 只能靠执行顺序收敛——已删除，避免两个所有者互相覆盖。
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

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
echo "--- opencli update complete ---"
