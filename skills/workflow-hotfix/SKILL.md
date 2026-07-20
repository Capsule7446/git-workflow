---
name: workflow-hotfix
description: 执行 workflow-hotfix 编排流程，负责阶段顺序、输入输出交接、门禁和回溯。
risk: caution
source: self
---

## 做什么

执行 `workflow-hotfix` 的完整编排流程。

## 需要什么参数

- **必需**：项目路径、目标和当前上下文。
- **可选**：技术栈、约束、工单号和已有运行工件。

## 怎么做

按下方流程执行阶段、门禁和回溯。

## 返回什么

返回阶段工件、门禁结果、未解决风险和下一步建议。

# Workflow：Hotfix（紧急生产修复）

> 紧急驱动。生产出问题,要最快、最小、最安全地修复并发布,且不夹带未发布的改动。由 `/git-workflow:ship` 在 `gw-route` 判定为 hotfix 时进入。
> 与 `workflow-deliver` 的关键差异:**基线是生产发布点(tag/分支),而非 `main` 的最新提交**;修复要回灌(back-merge)到日常基线,避免下次发布把修复覆盖掉。
> 命名空间:`git-workflow:<skill>` 为插件内 Skill 完整调用名。

## 1. 链路

```
git-workflow:gw-route       （判定 hotfix；基线 = 最近的生产发布点 vX.Y.Z）
   → git-workflow:gw-worktree（基于发布 tag 建隔离工作区,不污染当前开发）  ★G1
   →（最小修复)
   → git-workflow:gw-commit  （单个最小原子提交:fix(scope): ...）        ★G2
   → git-workflow:gw-ship    （PR 目标 = 生产分支/main;CI 必须绿)         ★G3
   → git-workflow:gw-integrate（合入生产 → 打补丁版 tag vX.Y.Z+1 → 发布)  ★G-rel
   → git-workflow:gw-sync    （把修复 back-merge 回 main/develop/进行中的 epic)★G-back
        ⟲ 出错 → git-workflow:gw-recover
```

## 2. 与标准交付的差异（只列不同处）

| 维度 | workflow-deliver | workflow-hotfix |
| :--- | :--- | :--- |
| 基线 | 最新 `main` | **最近生产发布点(tag vX.Y.Z 或 release 分支)** |
| 改动范围 | 正常 | **最小**——只改导致故障的那一点,不顺手重构 |
| 隔离 | 按需 | **强烈建议 worktree**:基于发布点开,绝不把未发布的 main 改动带进热修 |
| 版本 | 视情况 | **patch +1**(SemVer:vX.Y.Z → vX.Y.(Z+1)) |
| 收尾 | 删分支 | 删分支 **+ 必须 back-merge 修复回日常基线** |
| 节奏 | 可停可等 | 快,但 G3「CI 绿」不可省——紧急≠不验证 |

## 3. 门禁

| 门禁 | 位置 | 放行条件 |
| :--- | :--- | :--- |
| G1 隔离门禁 | route/worktree 后 | 基线确为生产发布点;worktree 基于该 tag;未混入未发布改动 |
| G2 提交门禁 | gw-commit 后 | 单个最小原子提交;无密钥/残留;不夹带无关改动 |
| G3 交付门禁 | gw-ship 前 | **CI 绿**(紧急也要验证);PR 正文说清故障、根因、影响面、验证方式 |
| G-rel 发布门禁 | gw-integrate 时 | 合入生产分支;打 patch tag;触发发布 |
| G-back 回灌门禁 | 发布后 | 修复已 **back-merge** 回 `main`/`develop`/进行中的 `epic`,确认下次发布不会丢失它 |

## 4. 回溯矩阵（hotfix 特有项)

| 触发条件 | 在哪发现 | 回退到 | 修复动作 |
| :--- | :--- | :--- | :--- |
| 基线错用了最新 main | gw-route | gw-route | 改基线为最近生产发布点重新开分支 |
| 修复夹带了未发布改动 | gw-commit, gw-ship | gw-commit | 撤出无关 hunk,只留最小修复 |
| 急着发、想跳过 CI | gw-ship | gw-ship | 不放行;紧急不等于不验证,等 CI 绿 |
| 发布后忘记 back-merge | gw-integrate | gw-sync | 立即把修复合回 main/develop/epic,否则下次发布覆盖修复 |
| 修复本身又引入故障 | 发布后 | gw-recover | `git revert` 回退该补丁,重新最小修复 |

## 5. 走查示例（登录在生产 500）

```
/git-workflow:ship 修复生产登录 500（线上 v1.3.2 报错）

route     → 类型 hotfix；基线 = tag v1.3.2（不是 main，main 上有未发布的结算改版）
            分支 hotfix/login-500                                        ── G1 ✅
worktree  → git worktree add -b hotfix/login-500 ../app.worktrees/hot v1.3.2
（修复）  → 定位:空 session 未判空 → 加一行判空,不动其他
commit    → fix(auth): 登录时 session 为空导致 500（单个最小提交）        ── G2 ✅
ship      → push；PR 正文:故障/根因/影响/验证；CI 绿                       ── G3 ✅
integrate → 合入生产分支 → git tag -a v1.3.3 && push → 触发发布            ── G-rel ✅
back-merge→ 在 main/develop/epic 各自的 worktree 或 back-merge 分支中执行 git merge hotfix （把修复回灌 main 与进行中的 epic/checkout）── G-back ✅
清理      → 删 hotfix/login-500 分支与 worktree
→ 生产已修复发版 v1.3.3,修复已回灌,不会被下次发布覆盖
```

## 6. 编排纪律

- **最小改动**:hotfix 只修那一个故障点,任何"顺手"都推迟到正常 `workflow-deliver`。
- **基线是发布点**:绝不在最新 `main` 上做热修(会把未发布改动一起带上线)。
- **紧急也验证**:G3 的 CI 绿不可省。
- **必回灌**:G-back 是 hotfix 区别于普通修复的命脉——发布后立即把修复 back-merge 回所有日常基线(`main`/`develop`/进行中的 `epic`)。
