---
description: 用 git worktree 把一段工作隔离到独立目录:从指定基线创建、列出、安全清理。支持多人/多 Agent 并行与 Epic 模式下基于集成分支建子需求工作区。
argument-hint: <分支/任务名> [--base <基线>] [--list] [--remove <路径>] [--epic <name>]
---

# /git-workflow:worktree

你按 `git-workflow:gw-worktree` Skill 帮用户用 worktree **隔离并行工作**:一条分支一个独立目录,共享同一 `.git`,切任务不靠 stash 打断,多 Agent/多人互不干扰。

> 配套 skill:`git-workflow:gw-worktree`;布局/并行/陷阱/清理细则见 `${CLAUDE_PLUGIN_ROOT}/references/worktree-patterns.md`。若不确定基线与命名,先经 `git-workflow:gw-route`。

## 参数

- `$ARGUMENTS`:要隔离的分支/任务名(创建时必需),如 `feature/order-export`。
- `--base`:创建基线。缺省 `origin/main`;Epic 子需求应为 `epic/<name>`;hotfix 为发布点。
- `--epic <name>`:声明这是 epic `<name>` 下的子需求 → 基线自动取 `epic/<name>`、命名 `feature/<name>-<任务>`。
- `--list`:列出现有 worktree(`git worktree list`)及其分支、用途。
- `--remove <路径>`:安全回收某 worktree(先查干净再 remove + prune)。

## 你要做的(按 gw-worktree 流程)

1. **选位置**:放仓库**之外**的同级目录 `../<repo>.worktrees/<slug>`,不嵌在工作树内(避免被扫/误提交)。
2. **据基线创建**:`git worktree add -b <branch> <path> <base>`。Epic 子需求基于 `epic/<name>`,不是 main。
3. **铁律**:同一分支只能被一个 worktree 检出;冲突则改检出别的分支。
4. **多 Agent**:每个 Agent 固定在自己的 worktree 路径内操作,绝不跨目录改文件。
5. **列出/盘点**:`--list` 时给出路径→分支→用途,并标出哪些已合并可回收。
6. **安全清理**:`--remove` 时**先确认无未提交改动且分支已合并/已推送**,再 `git worktree remove` + `git branch -d` + `git worktree prune`;不盲目 `--force`。

## 原则

- 创建安全,**移除会删目录**——清理前必查干净度,绝不轻易 `--force` 丢工作。
- worktree 路径在工作树之外;多 Agent 严格各守其目录。
- 要在 worktree 里 rebase 一条共享分支 → 停,转 `gw-sync` 按可见性规则处理。

## 示例

```
/git-workflow:worktree feature/order-export                 # 基于 origin/main 建
/git-workflow:worktree coupon --epic checkout               # 基于 epic/checkout 建 feature/checkout-coupon
/git-workflow:worktree --list                               # 盘点全部 worktree
/git-workflow:worktree --remove ../shop.worktrees/coupon    # 安全回收
```
