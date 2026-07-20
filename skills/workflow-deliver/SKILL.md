---
name: workflow-deliver
description: 执行 workflow-deliver 编排流程；这是由 Command 或其他 Skill 调用的注册 Workflow。
---

# Workflow：Deliver（标准交付链路）

> 主链路。把一段普通变更从"我要开始做"端到端推到"已合并、战场已清"。由 `/git-workflow:ship` 触发,以 `git-workflow:gw-route` 开场。
> 配套:`workflow-epic.md`(大需求并行)、`workflow-hotfix.md`(紧急修复)、`README.md`(体系蓝图与 risk 分级)。
> 命名空间:文中 `git-workflow:<skill>` 为插件内 Skill 的完整调用名(详见 README「命名空间约定」)。

## 1. 链路

```
git-workflow:gw-route          （选分支风格 / 定基线 / 标私有·共享）
   → git-workflow:gw-worktree  （隔离工作区,按需）          ★G1 隔离门禁
   →（用户在隔离工作区开发）
   → git-workflow:gw-commit    （原子提交 + Conventional Commits）★G2 提交门禁
   → git-workflow:gw-sync      （按可见性 rebase/merge 对齐基线）
   → git-workflow:gw-ship      （推送 + 开 PR,平台无关）      ★G3 交付门禁
   → git-workflow:gw-integrate （合并策略 + tag + 清理）
        ⟲ 任意阶段误操作 → git-workflow:gw-recover（reflog/revert/reset 救援）→ 回 gw-sync 对齐
```

## 2. 阶段工件衔接契约（上一站产出 = 下一站输入）

每一站的输出必须满足下一站的输入要求,否则不放行。

| 阶段 | 关键输入(来自上游) | 关键产出(喂给下游) |
| :--- | :--- | :--- |
| git-workflow:gw-route | 用户工作意图 + 仓库现状 | 路由单:工作类型、分支风格、基线、PR 目标、隔离方式、分支名、**私有/共享标记** |
| git-workflow:gw-worktree | 分支名 + 基线 | 隔离工作区路径 + worktree 清单 |
| git-workflow:gw-commit | 隔离工作区里的改动 | 原子提交序列(每条 Conventional Commits)+ 扫描清白结论 |
| git-workflow:gw-sync | 提交序列 + 基线 + 私有/共享标记 | 已对齐基线的分支(线性或合并)+ 冲突记录 |
| git-workflow:gw-ship | 已对齐的分支 + PR 目标 | PR(链接 + 承接提交的正文)+ 交付状态 |
| git-workflow:gw-integrate | 已批准、CI 绿的 PR + 合并策略 | 合入主线的提交/合并点 + tag + 清理报告 |
| git-workflow:gw-recover | 故障描述 + 私有/共享标记 | 复原结论 + 安全点 + 后续待办 |

## 3. 阶段门禁（gate）

每个 Skill 的"校验清单"全过才放行。三个**强门禁**额外要求停下与用户确认:

| 门禁 | 位置 | 放行条件 |
| :--- | :--- | :--- |
| G1 隔离门禁 | `git-workflow:gw-route`/`gw-worktree` 后 | 工作类型、分支风格、基线、**PR 目标**、命名经用户确认;工作区干净;隔离方式有理由 |
| G2 提交门禁 | `git-workflow:gw-commit` 后 | 每个提交原子;信息符合 Conventional Commits;**无密钥/调试残留/意外文件/冲突标记** |
| G3 交付门禁 | `git-workflow:gw-ship` 前 | 已同步基线且无冲突;本地检查绿或交代由 CI 把关;PR 正文完整;PR 目标分支正确 |

> 额外:`gw-integrate` 的合并与 `gw-sync` 的 force-push 属 **`danger`**——即便不在强门禁位,也必须停下确认并优先可逆形式(`--force-with-lease`、`revert` 而非 `reset --hard`)。

## 4. 回溯矩阵

| 触发条件 | 在哪发现 | 回退到 | 修复动作 |
| :--- | :--- | :--- | :--- |
| 一句话塞了多个目标 | gw-route | gw-route | 先拆成多个工作单元逐个路由 |
| 工作区脏/落后远端 | gw-route, gw-worktree | gw-sync | 先收尾/同步再切分支 |
| 同一分支已被检出 | gw-worktree | gw-worktree | 改建别的分支或转去既有 worktree |
| 提交混了多件事 | gw-commit, gw-ship | gw-commit | `reset` 撤出暂存,按 hunk 重拆 |
| 拆不出独立可测的原子提交 | gw-commit | gw-route | 工作单元划太粗,重新切分 |
| force-with-lease 被拒 | gw-sync | gw-sync | fetch 看对方改动,merge 进来再推,不升级 force |
| rebase 冲突连环、历史乱 | gw-sync | gw-recover | reflog/ORIG_HEAD 回到 rebase 前,改 merge 或重来 |
| PR 范围过大、职责混杂 | gw-ship | gw-route | 重新切分,拆小 PR 或 Stacked PR |
| 落后基线/有冲突(G3 不过) | gw-ship | gw-sync | 对齐基线再回交付 |
| 夹带密钥(未推送) | gw-commit, gw-ship | gw-commit | 撤出暂存/`reset --soft` 重来 |
| 夹带密钥(已推送) | gw-ship, gw-integrate | gw-recover | 先轮换密钥,再 filter-repo 清史 |
| 合并后引入回归 | gw-integrate | gw-recover | `git revert` 前向回退,不在主线 reset |
| 分支未真正合并却要删 | gw-integrate | gw-ship / gw-recover | 确认 PR 合入或核查,勿 `-D` 硬删 |

## 5. 端到端走查示例（订单导出）

```
/git-workflow:ship 给订单加导出 CSV

route    → 类型 feature；风格 Trunk-Based（确认 ✅）；基线 origin/main；PR 目标 main；
           私有分支；隔离 = 否（单线小改动）；名 feature/order-export    ── G1 ✅
（开发）  → 在 feature/order-export 上完成导出逻辑
commit   → 拆 3 条原子提交：feat 导出 / fix 空指针 / style 格式；扫描清白   ── G2 ✅
sync     → 私有分支 rebase origin/main（领先时基线前进了 4 个提交），解 1 处冲突
ship     → push -u；PR 正文承接提交（What/Why + 测试计划 + Closes #128）     ── G3 ✅
           gh pr create --base main
integrate→ review 通过、CI 绿 → squash 合入 main → 删分支
           （本次不发版，无 tag）
→ 已上主线，feature/order-export 已清理
```

## 6. 编排纪律

- **非一口气跑完**:在 G1/G3 停下与用户确认(分支策略、PR/合并)。
- **工件即输入**:严格按 §2 衔接契约传递路由单与各站产出,不丢信息(尤其"私有/共享标记"决定能否 rebase)。
- **风险分级守护**:`danger` 动作必停下确认、优先可逆形式;`gw-recover` 是任意阶段的安全网。
- **回溯是常态**:按 §4 矩阵退回不是失败,是把变更收敛干净;记录每次回溯与原因。
- **大需求并行改走 `workflow-epic`**,紧急生产修复改走 `workflow-hotfix`。
