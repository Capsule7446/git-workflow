---
name: gw-integrate
description: "把通过 review 的 PR 合入目标分支并彻底收尾:按策略选 squash/merge/rebase 合并、把 Epic 集成分支整体收口到 main、合并后清理(删分支、移除 worktree、prune)、衔接 tag/release。属 danger 级(改写共享分支),操作前停下确认并优先可逆形式。当 PR 已批准要合并、或 epic 大需求做完要收口时触发。"
risk: danger
stage: integrate
scope: remote
source: self
tags: "[git, integrate, merge-strategy, cleanup, release]"
---

# GW Integrate(合并 + 收尾 / 整合)

交付链路的终点:让变更真正进入共享主线,并把战场清干净。本工序动的是**共享分支**(`main`/`epic`),`risk: danger`——合并前确认 PR 已批准、CI 绿、目标正确;优先选可逆/可追溯的合并形式,清理前确认已合并、无未推送。

> Epic 模式的完整收口编排(子需求 → epic → main)见 `${CLAUDE_PLUGIN_ROOT}/workflows/workflow-epic.md`;合并策略取舍详见 `${CLAUDE_PLUGIN_ROOT}/references/branching-models.md`。

## 使用时机

- PR 已批准、CI 绿,要合入目标分支。
- **Epic 收口**:一个大需求的子需求都已合进 `epic/<name>`,要把 epic 整体合入 `main`。
- 合并后的清理:删分支、回收 worktree、打 tag。
- **被回溯触发**:合并后发现引入回归 → 转 `gw-recover` 用 `revert` 安全回退。

## 输入要求

- **必需**:已批准、CI 绿的 PR;确认的**目标分支**与**合并策略**。
- **现场采集**:PR 状态(`gh pr view` / `glab mr view`)、`git log` 确认 PR 提交、目标分支保护规则、关联的 worktree/子分支清单。
- **可选**:发版需求(是否随合并打 tag)、changelog 生成方式。

## 流程

1. **合并前确认(门禁)**:PR 已 approve、CI 绿、目标分支正确、冲突已解(否则回 `gw-ship`/`gw-sync`)。
2. **选合并策略**(按本仓库历史风格统一,别混用):

   | 策略 | 结果 | 适合 |
   | :--- | :--- | :--- |
   | **Squash** | 整个 PR 压成一个提交进主线 | 子需求小 PR、想要主线一 PR 一提交、历史干净(Trunk-Based 常用) |
   | **Merge commit** | 保留分支全部提交 + 一个合并点 | 想保留完整开发历史、可追溯分支拓扑 |
   | **Rebase merge** | 分支提交线性接到目标,无合并点 | 想要纯线性历史且每个提交都有价值 |

   - 平台执行:`gh pr merge --squash|--merge|--rebase --delete-branch`(GitLab `glab mr merge`)。
   - **Epic 收口到 main**:通常用 **merge commit** 或一个**汇总 squash**,让 main 上能看清"这是结算改版整块",并据团队策略决定是否保留子提交。
3. **打 tag / 衔接发版**(若该次合并触发发布):先获取并校验该 PR 的合并提交 OID，再直接对该确定提交创建 annotated tag；不得通过“拉取最新 main 后对当前 HEAD 打 tag”，避免并发合并把标签指向其他提交。
   - GitHub：`merge_oid=$(gh pr view <pr> --json mergeCommit --jq .mergeCommit.oid)`；确认 OID 非空且属于目标分支后，执行 `git fetch origin <target>`、`git tag -a vX.Y.Z "$merge_oid" -m "..."`、`git push origin vX.Y.Z`。
   - 遵循 SemVer：破坏性→major、新功能→minor、修复→patch。
4. **合并后清理(确认已合并再删)**:
   - 删远端分支:`gh pr merge --delete-branch` 已含,或 `git push origin --delete <branch>`。
   - 删本地分支:`git branch -d <branch>`(`-d` 要求已合并;用 `-D` 前必须确认)。
   - **回收 worktree**:对应 worktree `git worktree remove <path>` + `git worktree prune`(转 `gw-worktree` 的清理流程)。
   - **Epic 全家桶**:epic 合入 main 后,删 `epic/<name>` 及其**所有子分支**与**所有相关 worktree**。
5. **同步本地主线(按 worktree 现场选择)**:
   - 先执行 `git worktree list`，如果 `main` 已在某个 worktree 检出，就进入该路径执行 `git fetch origin main` 与 `git pull --ff-only`。
   - 如果没有可用主工作树，创建专用发布 worktree：`git worktree add ../<repo>.release origin/main`，在其中同步和执行需要目标分支上下文的发布操作，完成后按 `gw-worktree` 流程回收。
6. **报告**:合了什么(PR/提交)、用何策略、是否打 tag、清理了哪些分支/worktree、主线当前状态。

## 输出

| 工件 | 内容 |
| :--- | :--- |
| 合并结果 | PR、目标分支、合并策略、产生的主线提交/合并点 |
| 发版衔接 | 是否打 tag(版本号 + SemVer 依据)、是否触发 release |
| 清理报告 | 删除的远端/本地分支、回收的 worktree、prune 结果;epic 收口则列全家桶清理 |

## 校验清单

- [ ] 合并前 PR 已 approve、CI 绿、目标分支正确
- [ ] 合并策略与本仓库历史风格一致,未随意混用
- [ ] **danger 动作(合入共享分支、删分支)已停下与用户确认**
- [ ] 打 tag 遵循 SemVer,版本号与变更性质匹配(major/minor/patch)
- [ ] 清理前确认分支**已合并、无未推送**;`-D` 强删前已二次确认
- [ ] Epic 收口后,epic 分支、全部子分支、全部相关 worktree 均已回收
- [ ] 本地 `main` 已 `pull --ff-only` 跟上远端

## 回溯触发

- 合并后发现引入回归/破坏主线 → 转 `gw-recover`:用 `git revert <merge>`(可逆、可追溯)回退,**不在共享主线上 `reset`**。
- 清理时发现分支其实**未完全合并**(`git branch -d` 报错)→ 别 `-D` 硬删;回 `gw-ship` 确认 PR 真正合入,或转 `gw-recover` 核查。
- Epic 收口时与 main 巨型冲突 → 说明同步没跟上;回 `gw-sync` 先把 main 周期性 merge 进 epic 再收口(教训:epic 期间要定期同步)。

## 示例

```text
Epic「结算改版」收口：epic/checkout 下 4 个子需求 PR 均已合进 epic 并 CI 绿

gw-integrate：
1 确认 epic/checkout CI 绿、与 main 无冲突（期间已周期性 merge main 进来）✅
2 开 epic→main 的 PR，用 merge commit 收口（保留"结算改版"整块可追溯）
    gh pr merge 251 --merge --delete-branch     # 合入 main，删 epic 远端分支
3 发版：git tag -a v1.4.0 -m "结算改版：优惠券/支付/对账" && git push origin v1.4.0
    → 触发 release CI（minor：新增功能、无破坏性）
4 清理全家桶：
    git branch -d epic/checkout feature/checkout-coupon feature/checkout-payment ...
    git worktree remove ../shop.worktrees/coupon ../shop.worktrees/payment ...
    git worktree prune
5 git switch main && git pull --ff-only
→ 结算改版已上主线并发版 v1.4.0，战场清空
```
