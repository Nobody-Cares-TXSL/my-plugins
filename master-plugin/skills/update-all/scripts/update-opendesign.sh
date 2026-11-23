#!/usr/bin/env bash
# update-opendesign.sh — 安全更新本机 OpenDesign 源码（git pull → 按需装依赖 → 生产构建 → 按需重启 → 健康验证）
#
# 安全闸门：工作区不干净 / 无上游 / pull 失败 / 构建失败 → 停下报告，绝不 stash/reset/clean/强制合并。
# 重启策略：仅当更新前服务在运行时才重启；原本未运行则只构建、不擅自拉起。
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
NVM_BIN="$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1 || true)"
export PATH="${NVM_BIN:+$NVM_BIN:}$HOME/.local/bin:$PATH"

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

REPO=/home/duan/Project/open-design
PORT=7456
TMUX_SESSION=opendesign-prod
DAEMON_RE='^([^ ]*/)?node [^ ]*apps/daemon/dist/cli\.js'

log(){ echo "[opendesign] $*"; }
die(){ echo "[opendesign] ✗ $*" >&2; exit 1; }
healthy(){ curl -fsS --max-time 5 "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1; }

[ -d "$REPO/.git" ] || die "仓库不存在：$REPO"
cd "$REPO"

# 0. 预检（不修改文件）
branch=$(git branch --show-current)
[ -n "$branch" ] || die "detached HEAD，停止"
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
[ -n "$upstream" ] || die "分支 $branch 无上游，停止"
if [ -n "$(git status --porcelain)" ]; then
  git status --short >&2
  die "工作区不干净，停止（不 stash/reset/clean/checkout）"
fi
log "branch=$branch upstream=$upstream node=$(env node --version 2>/dev/null || echo '?') pnpm=$(env pnpm --version 2>/dev/null || echo '?')"

# 记录更新前服务是否在运行（决定更新后是否重启）
was_running=0
if ss -lnt 2>/dev/null | grep -q ":$PORT "; then was_running=1; fi
if [ -n "$(pgrep -f "$DAEMON_RE" || true)" ]; then was_running=1; fi
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then was_running=1; fi
log "更新前服务运行中: $was_running"

# 1. Git 拉取（仅本次命令强制 HTTP/1.1，不改全局配置）
BEFORE=$(git rev-parse HEAD)
log "git pull --ff-only (BEFORE=$BEFORE)"
git -c http.version=HTTP/1.1 pull --ff-only || die "git pull --ff-only 失败（不强制/不合并/不变基）"
AFTER=$(git rev-parse HEAD)
log "AFTER=$AFTER"

if [ "$BEFORE" = "$AFTER" ]; then
  if healthy; then
    log "✅ 已是最新且生产健康，无需重装/构建/重启"
  else
    log "⚠️  无新提交；生产服务未运行或健康检查失败——需单独诊断，本次不重启"
  fi
  exit 0
fi

changed=$(git diff --name-only "$BEFORE" "$AFTER")
log "变动文件："; printf '%s\n' "$changed" | sed 's/^/  /'

# 2. 依赖判断（仅相关文件变更时才安装）
if printf '%s\n' "$changed" | grep -Eq '(^|/)(package\.json|pnpm-lock\.yaml|pnpm-workspace\.yaml|\.npmrc)$|^patches/|^scripts/postinstall\.mjs$'; then
  log "依赖相关文件变更 → pnpm install --frozen-lockfile"
  env pnpm install --frozen-lockfile || die "frozen install 失败（不擅自改锁文件）"
else
  log "依赖相关文件未变 → 跳过安装"
fi

# 3. 停旧服务（只处理确认属于 OpenDesign 的进程，不使用宽泛 pkill）
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  log "停止 tmux 会话 $TMUX_SESSION"
  tmux send-keys -t "$TMUX_SESSION" C-c 2>/dev/null || true
  sleep 2
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
fi
pids=$(pgrep -f "$DAEMON_RE" || true)
if [ -n "$pids" ]; then
  log "终止 daemon 进程: $pids"
  # shellcheck disable=SC2086
  kill $pids 2>/dev/null || true
fi
for _ in $(seq 1 15); do
  ss -lnt 2>/dev/null | grep -q ":$PORT " || break
  sleep 1
done
ss -lnt 2>/dev/null | grep -q ":$PORT " && die "端口 $PORT 仍被占用，停止"

# 4. 生产构建
log "构建 daemon + web"
env pnpm --filter @open-design/daemon build || die "daemon 构建失败（旧服务已停）"
env pnpm --filter @open-design/web build || die "web 构建失败（旧服务已停）"
[ -f apps/daemon/dist/cli.js ] || die "缺少 apps/daemon/dist/cli.js"
[ -f apps/web/out/index.html ] || die "缺少 apps/web/out/index.html"
log "构建产物就绪"

# 5. 启动生产（仅原本在跑时重启；node 用绝对路径，规避 tmux 内懒加载函数失效）
if [ "$was_running" = 1 ]; then
  NODE_BIN="$(ls -d "$HOME"/.nvm/versions/node/*/bin | sort -V | tail -1)/node"
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
  tmux new-session -d -s "$TMUX_SESSION" \
    "cd $REPO && NODE_ENV=production exec $NODE_BIN apps/daemon/dist/cli.js --no-open"
  log "已启动 tmux 会话 $TMUX_SESSION"

  # 6. 健康验证（启动非瞬时，实测需 15–25s，最多等约 40s）
  ok=0
  for i in $(seq 1 20); do
    if healthy; then ok=1; log "健康接口就绪（第 ${i} 次探测）"; break; fi
    sleep 2
  done
  [ "$ok" = 1 ] || die "健康检查超时（daemon 未就绪；用 tmux attach -t $TMUX_SESSION 看日志）"
  health=$(curl -fsS --max-time 5 "http://127.0.0.1:$PORT/api/health")
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$PORT/" || true)
  log "health: $health"
  log "首页 HTTP: $code"
  [ "$code" = "200" ] || die "首页 HTTP $code（期望 200）"
else
  log "服务原本未运行 → 仅完成构建，未自动启动（需要时手动起生产模式）"
fi

log "✅ 更新完成：${BEFORE:0:9} → ${AFTER:0:9}"
