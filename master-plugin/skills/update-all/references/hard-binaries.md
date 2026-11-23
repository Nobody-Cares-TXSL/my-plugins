# 散装二进制（apt/npm/pipx 管不到的）

> 从 `SKILL.md` 渐进披露出来，仅在处理散装二进制更新时按需阅读。
> 脚本路径中的 `${CLAUDE_SKILL_DIR}` 指 update-all 技能目录。

这些软件只能手动换二进制（如 fd、lazygit、yazi、starship、rtk、anki、px0）。流程：

1. **发现**：`bash ${CLAUDE_SKILL_DIR}/scripts/check-hard-updates.sh`（只读，列出候选 + 当前版本 + 属主 + 更新方式 + **上游/查新版**）
2. **查最新版**：按「上游/查新版」列执行，**并行查**——串行 8 个请求约 9 秒，并行约 3 秒：
   - `owner/repo` → `gh release view --repo <owner/repo> --json tagName -q .tagName`
   - `self: <cmd>` → 直接跑该命令（如 `uv self update --dry-run`、`magpie update check`、`rustup check`），**不要**用 `gh release` 查
   ```bash
   for r in <owner/repo>...; do
     env gh release view --repo "$r" --json tagName -q .tagName 2>/dev/null | sed "s|^|$r |" &
   done; wait
   ```
   > 表里显示 `-` 的，先 `gh search repos <name>` 定位仓库，**不要猜仓库名**（猜错会得到空结果，白跑一轮）。
   > 用 `gh` 而非 `curl api.github.com`：匿名 API 会 403 限流（实测 `API rate limit exceeded`）。
3. **让用户选**：用 AskUserQuestion 列出可更新项，用户勾选
4. **下载**：`bash ${CLAUDE_SKILL_DIR}/scripts/check-hard-updates.sh --download <url> <目标路径>`（下载到 `~/下载`，**不安装**；目标路径用于按属主生成准确的安装命令）
5. **用户手动安装**：脚本给出安装命令，由用户执行（目录不可写时自动带 sudo）

> 更新方式有五类，**按脚本输出的「更新方式」列照做，不要按路径猜**：
>
> | 更新方式 | 命令 | 说明 |
> |---|---|---|
> | `自更新` | 脚本最后一列给出的命令（`uv self update`、`rustup check` 等） | 走工具自带机制 |
> | `uv tool` | `uv tool upgrade <名>` | 与 pipx 独立 |
> | `cargo 更新` | `cargo install <名> --locked` | 来源是 **crates.io**，升级安全 |
> | `本地源码` | 在该包的源码目录执行 `cargo install --force --path .` | 来源是 **本地 `--path`**，见下方警告 |
> | `手动下载` | 下 release 包后手动装 | 无包管理器 |
>
> **`本地源码` 是危险项，不能当 `cargo 更新` 处理。** 这类包不在 crates.io 上，或虽同名但源码已被本地修改。若误用 `cargo install <名>`，cargo 会去 crates.io 装回同名上游版本，等于把本地改动全部覆盖掉——典型如 `tmux-expose`：本地是二开版 0.1.0，crates.io 上的同名上游是 0.8.0，装回会丢失全部二次开发功能。
>
> 脚本用 `~/.cargo/.crates.toml` 判定来源，判据是安装记录里的 `registry+https://...` 还是 `path+file:///...`，不靠路径前缀猜。遇到 `本地源码`，该行下方会另起一行给出源码目录和命令（不塞进表格是为了不撑破列对齐），直接照做即可。

## 有意不检查的类型

`check-hard-updates.sh` 只列 ELF 二进制。以下**没有出现在结果里是正常的**，不代表漏扫：

| 类型 | 例子 | 为什么不列 | 实际怎么维护 |
|---|---|---|---|
| shell / python 本机脚本 | `md-read-hd`、`tmux-suspend-ueberzug`、`mimeapps-guard.sh`、`check-hard-updates` | 不是 ELF，且无上游可查 | 手工改，随仓库/文档同步 |
| uv tool 命令 | `harlequin`、`hsql`、`laya` | 是 `~/.local/bin` 下的符号链接 | 已在结果中单列，走 `uv tool upgrade` |
| 软链兼容层 | `fd`→`fdfind`、`magick`→`convert` | 符号链接，指向 APT 管理的真实程序 | 随 APT 更新 |
| rustup 组件 | `cargo`、`rustc`、`rustfmt`、`clippy` | 都是指向 `rustup` 的符号链接 | `rustup update` |
| 备份/下载残留 | `*.bak*`、`*.new`、`*.old` | 不是已安装软件 | — |

> 看到某个工具"没被列出"时，先查上表。若它确实是有上游的 ELF 却没出现，多半是 `SCAN_DIRS` 没覆盖它的目录，或它是符号链接。
