---
description: 按照 Git 约定式提交规范创建提交并推送到远程
argument-hint: "<type>(<scope>): <description>"
allowed-tools: Read, Edit, Bash(git:*)
---

# Git 规范提交并推送

你是一个 Git 提交规范专家。请按照**约定式提交（Conventional Commits）**规范创建提交并推送。

## 提交信息格式

```
<type>([optional scope]): <description>

[optional body]

[optional footer(s)]
```

## Type 类型（必填其一）

使用标准 Conventional Commits 类型：`feat` | `fix` | `docs` | `style` | `refactor` | `perf` | `test` | `chore` | `ci` | `build`

## Footer 关键词

| 关键词 | 说明 |
|:-----|:-----|
| `Closes #123` | 关闭 Issue |
| `Fixes #123` | 修复 Issue |
| `BREAKING CHANGE:` | 破坏性变更声明 |

## Git 提交规范（强制遵守）

- **仅应要求创建提交**：不主动创建提交
- **NEW 永远优先**：失败后创建新提交，永不 AMEND（除非明确要求）
- **精确暂存**：用具体文件名，**禁止** `git add .` 或 `-A`
- **HEREDOC 格式**：所有提交必须使用此格式

```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

[optional body]

EOF
)"
```

## 执行步骤

1. **分析变更**：运行 `git status` 和 `git diff` 查看改动
2. **确定类型**：根据变更性质选择合适的 type
3. **生成提交信息**：
   - description 不超过 50 字符
   - body 说明"做了什么，为什么"
   - footer 关联 Issue（如有）
4. **精确暂存文件**：使用具体文件名，如 `git add src/main.py`
5. **展示并确认**：
   - 展示拟定好的提交信息（标题 + body）
   - 使用 `AskUserQuestion` 工具让用户确认
   - 选项：
     - "确认提交并推送" - 执行后续步骤
     - "修改提交信息" - 让用户输入新的提交信息
     - "取消" - 中止操作
6. **创建提交**：用户确认后，使用上面的 HEREDOC 格式
7. **再次确认推送**：
   - 展示即将推送的提交 hash 和标题
   - 使用 `AskUserQuestion` 工具让用户确认推送
   - 选项：
     - "确认推送" - 执行 git push
     - "仅提交不推送" - 跳过推送步骤
     - "取消" - 中止操作（保留本地提交）
8. **推送到远程**：用户确认后执行 `git push`

## 重要提醒

- **必须使用 AskUserQuestion 确认**：在 git commit 和 git push 之前都必须获得用户明确同意
- **不要自动执行**：禁止在用户未确认的情况下执行任何 git 操作
- **透明展示**：清楚展示即将执行的命令和提交信息

## 参数

- `$ARGUMENTS`：用户提供的提交信息，格式为 `<type>(<scope>): <description>`

## 示例

用户输入：`/push feat(auth): 添加 OAuth2 登录`

你将：
1. 查看当前变更，分析改动文件
2. 展示拟定提交信息并请求确认：
   ```
   拟定提交信息：
   feat(auth): 添加 OAuth2 登录

   - 集成 Google OAuth2 认证
   - 添加用户信息同步逻辑

   是否确认？(确认提交并推送 / 修改提交信息 / 取消)
   ```
3. 用户确认后创建提交
4. 再次确认推送：
   ```
   即将推送：feat(auth): 添加 OAuth2 登录
   是否确认推送？(确认推送 / 仅提交不推送 / 取消)
   ```
5. 执行推送
