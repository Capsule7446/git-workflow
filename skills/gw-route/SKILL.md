---
name: gw-route
description: "Git 工作流的统一入口路由与分支风格选择器:读清仓库现状,判定本次工作类型(feature/fix/hotfix/subtask/epic/release/chore),按环境从分支模型菜单(Trunk-Based / Git Flow / Epic 集成分支 / Feature Flags / 共享分支 / Stacked PR)选定一种风格,定下基线分支、PR 目标、是否用 worktree 隔离、命名约定。当用户要开始一段新工作,或 /commit、/ship、/worktree 被触发但当前分支/工作区状态不明时触发。"
risk: safe
stage: route
scope: local
source: self
tags: "[git, route, branching-model, epic]"
---

# GW Route(工作路由 / 分支风格选择器)

整套体系的**阶段 0**。它不动任何状态(`risk: safe`),只做决策:读清仓库的真实状态,判定这次要做的是哪类工作,**按环境从分支模型菜单里选一种风格**,再定基线、PR 目标、是否 worktree 隔离、分支命名。产出一张**路由单**,作为后续每一站(隔离 → 提交 → 同步 → 交付 → 整合)的共同前提。

> 本 skill 是**选择器**,不锁死风格。完整的分支模型菜单(各自适用环境、基线/PR 目标、取舍)见 `${CLAUDE_PLUGIN_ROOT}/references/branching-models.md`。

## 分支模型菜单(按环境选)

| 风格 | 适用环境 | feature 基线 | PR 目标 | 默认场景 |
| :--- | :--- | :--- | :--- | :--- |
| **Trunk-Based / GitHub Flow** | CI/CD、小步频繁合并、并行 worktree | `main` | `main` | **缺省默认** |
| **Git Flow** | 定期发版、多版本并行维护、强审批 | `develop` | `develop` | 多版本/发布列车 |
| **Epic 集成分支** | 大需求拆多小需求、多人/多 Agent 并行 | `epic/<name>` | `epic/<name>` | **大需求并行(默认)** |
| **Feature Flags on trunk** | 强 CI + 开关基建,要避免长命分支 | `main` | `main`(藏开关后) | 能小步上 main 时 |
| **共享分支** | 临时、2-3 人、直接 push 同一分支 | 共享分支本身 | 直接 push | 不得已的简化 |
| **Stacked PR** | 单人一串相互依赖的小改动 | 上一层分支 | 自底向上逐层 | 依赖链拆分 |

> Epic 集成分支 = 你画的 `master → feature → dev → master` 的正确形态:`dev` 不是永久 `develop`,而是**每个大需求一条、用完即删**的集成分支。详见 `workflow-epic`。

## 使用时机

- 用户表达「开始做某个功能/修个 bug/发版/接手大需求里的一个小需求」,但尚未建分支。
- `/git-workflow:ship` 启动 `workflow-deliver` / `workflow-epic` 时的开场站。
- `/git-workflow:commit` 或 `/git-workflow:worktree` 被触发,但当前在 `main`/`master`、或工作区脏、或分支与任务对不上时——先回这里定向。
- **被回溯触发**:`gw-ship` 发现 PR 范围过大/职责混杂时,回这里重新切分工作单元。

## 输入要求

- **必需**:用户的工作意图(一句话即可);可执行 `git` 的仓库。
- **现场采集(本 skill 自己跑只读命令)**:
  - `git rev-parse --is-inside-work-tree` 确认在仓库内;
  - `git symbolic-ref --short HEAD` 当前分支、`git status --porcelain` 工作区是否干净;
  - `git remote -v`、`git branch -a`、`git worktree list` 远端/已有分支/已有 worktree;基线(`origin/HEAD` 指向)。
- **可选**:团队的分支模型约定、发版节奏、CI/开关基建成熟度、团队规模、epic/工单号。

## 流程

1. **判定工作类型**。归入七类之一,它决定命名前缀与意图(基线/PR 目标随后由所选风格决定):

   | 类型 | 解决什么 | 前缀 |
   | :--- | :--- | :--- |
   | feature | 新增能力(独立) | `feature/` |
   | subtask | **某个 epic 下的小需求** | `feature/<epic>-` |
   | epic | 开一条集成分支收拢一个大需求 | `epic/` |
   | fix | 修常规缺陷 | `fix/` |
   | hotfix | 修生产紧急缺陷(基线为发布点) | `hotfix/` |
   | refactor/chore | 重构、依赖、配置 | `refactor/` `chore/` |
   | experiment | 验证性想法、可丢弃 | `spike/` |

2. **选分支风格**。对照上面的菜单,按**环境**(团队规模、CI/开关成熟度、发版节奏、是否大需求并行)挑一种,**说清理由并让用户确认**,不默默套缺省:
   - 单线 / 持续部署 → **Trunk-Based**。
   - 大需求拆多小需求、多人或多 Agent 并行 → **Epic 集成分支**(本场景默认);若 CI + 开关基建强,可改 **Feature Flags on trunk** 避免长命分支。
   - 定期发版 / 多版本维护 → **Git Flow**。
   - 单人一串依赖小改动 → **Stacked PR**。
3. **据风格定基线与 PR 目标**。
   - Trunk-Based / Flags:基线 = 最新 `main`,PR → `main`。
   - **Epic 子需求**:基线 = 该 `epic/<name>` 分支(不存在则**先建 epic 分支**:`git switch -c epic/<name> origin/main` 并推送+开分支保护),PR → `epic/<name>`(**不是 main**)。
   - Git Flow:基线/PR = `develop`(release/hotfix 例外)。
   - hotfix:基线 = 最近发布 tag/分支。
   - 切分支前先确认基线已与远端同步,否则提示先 `gw-sync`。
4. **决定隔离方式**(交 `gw-worktree` 执行)。需并行多件事、不想 stash 打断、多 Agent 互不干扰、边改边对照 → 用 **worktree**;单线程小改动 → 普通分支即可。Epic 模式下,**每条子分支建一个基于 epic 分支的 worktree** 是推荐姿势。
5. **定命名**。`<前缀>/<简短-kebab-描述>`,可带工单:`feature/checkout-coupon`、`epic/checkout`、`feature/128-order-export`。用业务语言。
6. **标记分支可见性 + risk 预告**。明确目标分支是**私有**(只你用 → 可自由 rebase)还是**共享**(epic / main / 多人推送 → 绝不改写历史);预告后续哪些站触及远端或改写历史。这条直接喂给 `gw-sync` 的同步纪律。
7. **输出路由单**,移交下一站。

## 输出

| 工件 | 内容 |
| :--- | :--- |
| 路由单 | 工作类型、**所选分支风格**、基线分支、**PR 目标分支**、隔离方式、目标分支名、关联 epic/工单 |
| 分支可见性 | 目标分支 = 私有 / 共享(决定能否 rebase) |
| 现状快照 | 当前分支、工作区是否干净、本地是否落后远端、是否需先 `gw-sync`、是否需先建 epic 分支 |
| 下一站指令 | 用 worktree → `gw-worktree`;否则建分支进入开发;改动就绪 → `gw-commit`;epic 编排 → `workflow-epic` |

## 校验清单

- [ ] 已确认在 git 仓库内,且读到当前分支、工作区、worktree 状态
- [ ] 工作类型归入七类之一
- [ ] **分支风格从菜单中明确选定并经用户确认**,理由与环境匹配,不是默默假设
- [ ] 基线与 PR 目标随风格正确设定(尤其 epic 子需求 PR 目标是 epic 分支而非 main)
- [ ] 目标分支已标记私有/共享(供 `gw-sync` 判定能否 rebase)
- [ ] 若工作区脏或落后远端,已给出先收尾/先同步的指引,未在脏区盲目切分支
- [ ] 隔离方式(分支 vs worktree)有明确理由

## 回溯触发

- 一句话里塞了多个不相关目标 → 让用户**先拆成多个工作单元**逐个路由(一个分支只干一件事)。
- 这其实是「大需求」而非单点变更 → 升级为 `epic` 类型,先建集成分支,按 `workflow-epic` 编排子需求。
- 基线落后远端很多 / 本地有未推送分叉 → 先 `gw-sync` 对齐再定基线。
- 发现要动的是既有大块代码的领域模型 → 提示先走 `domain-driven-design`(若已安装)建模,再回来。

## 示例

```text
/git-workflow:ship 给结算流程加优惠券,这是"结算改版"大需求里的一块

gw-route 读现场：
  当前分支 = main，工作区干净；远端 github(origin)；已存在分支 epic/checkout
  团队：3 人 + 2 个并行 Agent 在做结算改版的不同小块

→ 路由单：
  类型     = subtask（隶属 epic「结算改版」）
  风格     = Epic 集成分支 ── 用户确认 ✅（大需求多小需求并行）
  基线     = epic/checkout（已存在，先确认其已 merge 最新 main）
  分支名   = feature/checkout-coupon
  PR 目标  = epic/checkout   ← 不是 main
  可见性   = 私有（只我开发 → 可自由 rebase 整理）
  隔离     = worktree（与另一个 Agent 并行）→ 交 gw-worktree，基于 epic/checkout 建
  工单     = #231

→ 下一站：gw-worktree 建 worktree（base=epic/checkout）→ 开发 → gw-commit
            收口编排见 workflow-epic（epic/checkout 最终一个 PR 合 main）
```
