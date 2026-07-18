# Git Workflow（可审计的 Git 工作流）

Git Workflow 是一个面向 Claude Code 的 Git 协作插件，将分支策略、worktree、提交、同步、恢复和交付流程变成可重复、可审计的操作。默认偏向 Trunk-Based / GitHub Flow，也支持按项目选择其他分支模型。

## 适用场景

- 开始一个功能、Epic 或紧急修复，需要选择安全的工作区和分支策略。
- 需要创建 worktree，避免多个任务互相覆盖。
- 需要生成 Conventional Commits、同步分支、创建 PR 或交付变更。
- rebase、冲突、误删分支或历史异常后，需要按恢复流程处理。

## Command

| Command | 用途 |
| --- | --- |
| [`commit`](commands/commit.md) | 检查变更并创建原子化、符合 Conventional Commits 的提交。 |
| [`ship`](commands/ship.md) | 执行从检查、同步到 PR/交付的完整流程。 |
| [`worktree`](commands/worktree.md) | 创建、切换和清理隔离 worktree。 |

## Workflow

| Workflow | 用途 |
| --- | --- |
| [`workflow-deliver`](workflows/workflow-deliver.md) | 常规功能或修复的交付流程。 |
| [`workflow-epic`](workflows/workflow-epic.md) | 多切片 Epic 的拆分、依赖和阶段性交付。 |
| [`workflow-hotfix`](workflows/workflow-hotfix.md) | 紧急修复的最小变更、验证和发布。 |

## Skill

| Skill | 用途 |
| --- | --- |
| [`gw-route`](skills/gw-route/SKILL.md) | 选择分支模型和下一步 Git 路径。 |
| [`gw-worktree`](skills/gw-worktree/SKILL.md) | 安全创建和管理隔离工作区。 |
| [`gw-commit`](skills/gw-commit/SKILL.md) | 生成原子提交和 Conventional Commit 消息。 |
| [`gw-sync`](skills/gw-sync/SKILL.md) | 同步远程、检查分叉和处理更新。 |
| [`gw-ship`](skills/gw-ship/SKILL.md) | 组织 PR、交付和合并前检查。 |
| [`gw-integrate`](skills/gw-integrate/SKILL.md) | 集成分支、解决冲突并验证结果。 |
| [`gw-recover`](skills/gw-recover/SKILL.md) | 使用 reflog 等手段恢复 Git 状态。 |

## 使用方式

```text
/git-workflow:worktree <任务名>
/git-workflow:commit
/git-workflow:ship
```

## 不适用场景

- 没有授权就执行删除远程分支、强制推送或破坏性历史改写。
- 只需要审查业务代码而不涉及 Git 交付。
