#!/usr/bin/env bash
# update-npm.sh — 更新所有 npm 全局包（开发工具链锁定大版本）
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

# 开发工具链：只升小版本，跨大版本会破坏环境（npm/pnpm 大版本改动常伴行为变化）
LOCKED_TOOLS="npm pnpm corepack"

NPM_ROOT="$(npm root -g)"

# npm 11 起 install scripts 默认被沙箱拦截（allow-scripts），postinstall 不再自动执行。
# 下列包依赖 postinstall/install：pnpm/bun/corepack 生成 shim，
# better-sqlite3/koffi/node-pty 编译原生模块。不放行会留下"包在但不可用"的中间态。
ALLOW_SCRIPTS="pnpm,corepack,bun,core-js,better-sqlite3,@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs"
npm_major=$(npm --version 2>/dev/null | cut -d. -f1)
case "$npm_major" in
  ''|*[!0-9]*) npm_major=0 ;;
esac
# 空数组在 set -u 下按 0 个参数展开，两句调用点共享同一份条件
NPM_ALLOW=()
if [ "$npm_major" -ge 11 ]; then
  NPM_ALLOW=(--allow-scripts="$ALLOW_SCRIPTS")
fi

# 返回该包版本比较键：major>0 用 major，0.x 用 "0.minor"
# （0.x 的 minor 变更即破坏性，与 major 同等对待）
range_of() {
  local ver major minor _
  ver=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$NPM_ROOT/$1/package.json" 2>/dev/null | head -1)
  [ -n "$ver" ] || return 1
  IFS=. read -r major minor _ <<< "$ver"
  if [ "$major" = 0 ]; then echo "0.$minor"; else echo "$major"; fi
}

echo "--- Updating npm global packages ---"
# npm update -g 会重算整棵依赖树（实测空跑 ~5 分钟），先查 outdated（~14 秒）再决定是否真装
# 三种结果要分开：有更新 / 确实最新 / 检查失败（网络故障时输出为空，不能当成"最新"）
# 注意 npm outdated 有更新时也返回 1，所以先看输出，再看退出码
rc=0
outdated=$(npm outdated -g 2>/dev/null) || rc=$?
if [ -n "$outdated" ]; then
  echo "$outdated" | sed 's/^/  /'
  if [ "${#NPM_ALLOW[@]}" -gt 0 ]; then
    echo "  npm $npm_major：显式放行已知包的 install scripts"
  fi
  npm update -g "${NPM_ALLOW[@]}" 2>&1
elif [ "$rc" -eq 0 ]; then
  echo "  ✅ 全部已是最新，跳过 npm update -g"
else
  echo "  ⚠️  npm outdated 检查失败（退出码 $rc），未执行更新，请检查网络后重试"
fi
echo ""

# 把锁定工具钉回原大版本：显式给 semver 范围，避免"先升到新 major 再回退"的
# 窗口期（回退若失败，后续依赖 npm 的步骤会踩到不兼容版本）
echo "--- 锁定开发工具链大版本 ---"
for tool in $LOCKED_TOOLS; do
  key=$(range_of "$tool") || continue
  installed=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$NPM_ROOT/$tool/package.json" 2>/dev/null | head -1)
  # 用同一条比较键（major 或 0.minor）比对，避免 "11" 误匹配 "110.0.0"
  IFS=. read -r ma mi _ <<< "$installed"
  if [ "$ma" = 0 ]; then now="0.$mi"; else now="$ma"; fi
  if [ "$now" = "$key" ]; then
    echo "  ✅ $tool $installed 保持 $key.x"
  else
    echo "  ⚠️  $tool $installed 跨大版本（原 $key.x），钉回"
    npm install -g "$tool@^$key" "${NPM_ALLOW[@]}" 2>&1 | tail -3
  fi
done

echo ""
echo "--- npm update complete ---"
