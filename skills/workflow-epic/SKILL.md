---
name: workflow-epic
description: 执行 workflow-epic 编排流程，负责阶段顺序、输入输出交接、门禁和回溯。
risk: caution
source: self
---

## 做什么

执行 `workflow-epic` 的完整编排流程。

## 需要什么参数

- **必需**：项目路径、目标和当前上下文。
- **可选**：技术栈、约束、工单号和已有运行工件。

## 怎么做

按下方流程执行阶段、门禁和回溯。

## 返回什么

返回阶段工件、门禁结果、未解决风险和下一步建议。

# Workflow：Epic（大需求并行 / 集成分支)

> 大需求驱动。一个 epic(大需求)拆成多个小需求,多人/多 Agent 并行开发,先在一条**集成分支**上汇合,再整体收口到 `main`。由 `/git-workflow:ship --epic <name>` 触发,或 `gw-route` 判定为 epic 场景时进入。
> 这是用户直觉里 `master → feature → dev → master` 的**正确形态**:`dev` 不是永久 `develop`,而是**每个大需求一条、用完即删**的集成分支。
> 命名空间:`git-workflow:<skill>` 为插件内 Skill 完整调用名。

## 1. 形态图

```
main ──●──────────────────────────────────●────  ← 始终可部署
        \  (建 epic)                     ↑ 收口:epic 整体一个 PR/合并进 main
         epic/<name> ──●────●────●────────┘        ← 集成分支:禁直接 push、只接 PR、周期性 merge main
              ↑PR    ↑PR    ↑PR
              │      │      └ feature/<name>-sub3   (开发者C / Agent3,私有分支,可自由 rebase)
              │      └─────── feature/<name>-sub2   (开发者B / Agent2)
              └────────────── feature/<name>-sub1   (开发者A / Agent1)
```

## 2. 链路

```
git-workflow:gw-route   （判定 epic 场景；epic/<name> 不存在则先建并加分支保护）
   → 对每个小需求(并行):
        git-workflow:gw-worktree （基于 epic/<name> 建子需求 worktree）  ★G1
        →（开发）
        → git-workflow:gw-commit （原子提交）                          ★G2
        → git-workflow:gw-sync   （子分支【私有】rebase epic/<name> 整理）
        → git-workflow:gw-ship   （PR 目标 = epic/<name>，非 main）     ★G3
        → git-workflow:gw-integrate（子 PR 合进 epic/<name>）
   → 周期性:git-workflow:gw-sync （把 origin/main 【merge】进 epic/<name>，防收口巨冲突）
   → 全部子需求合齐后 收口:
        git-workflow:gw-integrate （epic/<name> 整体合入 main + 打 tag + 清理全家桶）★G4
        ⟲ 任意阶段误操作 → git-workflow:gw-recover
```

## 3. 关键纪律（Epic 模式特有）

1. **集成分支是共享的,只进不改写**:`epic/<name>` 禁止直接 push、禁止 rebase;开分支保护,只能通过子需求 PR 合入。
2. **子分支是私有的,可自由整理**:每个 `feature/<name>-subN` 只由一人/一个 Agent 用,可随意 `rebase epic/<name>` 保持线性。
3. **同步方向固定**:让 epic 跟上 main 用 `git merge origin/main`(把 main 合进 epic);**绝不**把 epic rebase 到 main。子分支跟上 epic 用 rebase。
4. **PR 目标是 epic 不是 main**:子需求 PR 的 base 必须是 `epic/<name>`;开错成 main 会把半成品漏给主线。
5. **周期性同步,别攒到最后**:epic 存活期间定期把 main merge 进来,避免收口时巨型冲突。
6. **用完即删**:epic 收口后,epic 分支、全部子分支、全部相关 worktree 一次清空——它不是常驻 `develop`。
7. **多 Agent 各守 worktree**:每个子需求一个基于 epic 的 worktree,Agent 只在自己目录内操作。

## 4. 门禁

| 门禁 | 位置 | 放行条件 |
| :--- | :--- | :--- |
| G1 隔离门禁 | 每个子需求 route/worktree 后 | 子需求基线 = `epic/<name>`;PR 目标 = `epic/<name>`;命名 `feature/<name>-subN`;worktree 基于 epic |
| G2 提交门禁 | 每个子需求 gw-commit 后 | 原子提交、信息规范、无密钥/残留 |
| G3 交付门禁 | 每个子需求 gw-ship 前 | 子分支已 rebase 最新 epic、无冲突、PR 目标是 epic、正文完整 |
| G4 收口门禁 | epic 合入 main 前 | 全部子需求已合进 epic;epic 已周期性同步 main 且与 main 无冲突;epic CI 绿;合并策略与 tag 经用户确认 |

## 5. 回溯矩阵（Epic 特有项,通用项见 workflow-deliver §4）

| 触发条件 | 在哪发现 | 回退到 | 修复动作 |
| :--- | :--- | :--- | :--- |
| 子需求 PR 误把 base 设成 main | gw-ship | gw-ship | 改 PR base 为 epic/<name> |
| 有人直接 push 了 epic 分支 | gw-sync, gw-integrate | gw-recover | 评估影响;补开分支保护;必要时 revert |
| 子分支落后 epic 太多、冲突大 | gw-sync | gw-sync | 私有子分支 rebase epic/<name> 跟上 |
| 收口时 epic 与 main 巨型冲突 | gw-integrate(G4) | gw-sync | 教训:应早做;现在把 main merge 进 epic 分步解冲突 |
| 误把 epic rebase 到了 main | gw-sync | gw-recover | reflog 复原 epic;改用 merge;通知协作者 |
| 一个子需求其实还能再拆 | gw-route | gw-route | 拆成更小子需求,各自分支 |
| 大需求迟迟收不了口、长期发散 | gw-integrate | gw-route | 考虑改 Feature Flags：小需求小步直接进 main(藏开关) |

## 6. 端到端走查示例（结算改版）

```
/git-workflow:ship 结算改版 --epic checkout    （大需求：优惠券 + 支付 + 对账，3 人 + 2 Agent）

route     → 场景 = epic；epic/checkout 不存在 → git switch -c epic/checkout origin/main
            && git push -u origin epic/checkout && 开分支保护（禁直接 push / 必经 PR）             ── 用户确认 ✅
并行子需求（各开 worktree，base=epic/checkout）：
  sub1 优惠券  → worktree coupon  → commit → rebase epic → PR base=epic/checkout → 合进 epic  G1-3 ✅
  sub2 支付    → worktree payment → commit → rebase epic → PR base=epic/checkout → 合进 epic  G1-3 ✅
  sub3 对账    → ...（Agent3 在 .../recon 目录，互不干扰）
周期同步   → 每隔几天在 epic/checkout 上 git merge origin/main（防收口巨冲突）
收口       → 3 子需求齐 → epic/checkout 与 main 无冲突、CI 绿                ── G4 ✅
            gh pr merge <epic-pr> --merge   （merge commit 收口，保留"结算改版"整块）
            merge_oid=$(gh pr view <epic-pr> --json mergeCommit --jq .mergeCommit.oid)
            test -n "$merge_oid"
            git fetch origin main
            git tag -a v1.4.0 "$merge_oid" -m "release: v1.4.0"
            git push origin v1.4.0
            # 不切换当前 worktree；若需同步 main，进入已检出的 main worktree，
            # 或创建专用发布 worktree 后执行 git pull --ff-only。
清理       → 删 epic/checkout + feature/checkout-* 全部子分支 + 全部 worktree
→ 结算改版上主线、发版 v1.4.0,集成分支用完即删
```

## 7. 与 workflow-deliver 的关系

Epic 链路 = 对每个小需求跑一遍 deliver 主链路(只是基线/PR 目标换成 epic 分支),外加**建集成分支**(前)、**周期同步**(中)、**收口 + 全家桶清理**(后)三道 epic 专属动作。子需求内部的门禁、工件契约、回溯与 `workflow-deliver` 完全一致——最大化复用,不维护两套战术工序。
