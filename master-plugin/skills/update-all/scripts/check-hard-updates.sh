#!/usr/bin/env bash
# check-hard-updates.sh — 发现并检查非包管理器安装的散装二进制
#
# 用法:
#   check-hard-updates.sh                    自动发现所有散装二进制（只读）
#   check-hard-updates.sh --download <url>   下载指定 URL 到 ~/下载（通用下载器）
#
# 设计原则：
#   - 软件列表不写死，自动扫描 + dpkg 归属判断得出
#   - 只读检查；下载后由用户手动安装，脚本不安装、不 sudo
set -euo pipefail

DL_DIR="$HOME/下载"
SCAN_DIRS=("/usr/local/bin" "$HOME/.local/bin" "$HOME/.cargo/bin" "/opt")

mkdir -p "$DL_DIR"

# 判断是否散装：非符号链接 + 不属于 dpkg + 是 ELF
is_standalone() {
  local f="$1"
  [ -f "$f" ] || return 1
  [ -L "$f" ] && return 1
  dpkg -S "$f" >/dev/null 2>&1 && return 1
  file -b "$f" 2>/dev/null | grep -q '^ELF' || return 1
  return 0
}

probe_version() {
  local f="$1"
  timeout 5 "$f" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "?"
}

SELF_UPDATE_TOOLS=("uv" "uvx" "magpie" "rustup" "cargo" "gh")

has_self_update() {
  local name="$1"
  for t in "${SELF_UPDATE_TOOLS[@]}"; do [ "$name" = "$t" ] && return 0; done
  return 1
}

# 判断更新方式：自更新 / cargo 更新 / 手动下载
update_method() {
  local name="$1" path="$2"
  if has_self_update "$name"; then echo "自更新"
  elif [[ "$path" == *"/.cargo/bin/"* ]]; then echo "cargo 更新"
  else echo "手动下载"
  fi
}

discover() {
  printf '%-14s %-38s %-10s %-6s %s\n' "软件" "路径" "版本" "属主" "更新方式"
  printf '%-14s %-38s %-10s %-6s %s\n' "----" "----" "----" "----" "--------"
  for dir in "${SCAN_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*; do
      is_standalone "$f" || continue
      local name ver owner how
      name=$(basename "$f")
      ver=$(probe_version "$f")
      owner=$(stat -c '%U' "$f" 2>/dev/null || echo "?")
      how=$(update_method "$name" "$f")
      printf '%-14s %-38s %-10s %-6s %s\n' "$name" "$f" "$ver" "$owner" "$how"
    done
  done
}

download_url() {
  local url="$1"
  [ -n "$url" ] || { echo "用法: check-hard-updates.sh --download <url>"; exit 1; }
  local fname="${url%%\?*}"
  fname="${fname##*/}"
  [ -n "$fname" ] || { echo "无法从 URL 推断文件名"; exit 1; }
  export http_proxy="${http_proxy:-http://127.0.0.1:7890}"
  export https_proxy="${https_proxy:-http://127.0.0.1:7890}"
  echo "下载: $url"
  echo "到:   $DL_DIR/$fname"
  timeout 600 curl -L --progress-bar -o "$DL_DIR/$fname" "$url"
  echo "完成: $DL_DIR/$fname"
}

case "${1:-}" in
  --download) download_url "${2:-}" ;;
  "")         discover ;;
  *)          echo "未知参数: $1"; echo "用法: check-hard-updates.sh [--download <url>]"; exit 1 ;;
esac
