---
name: gw-worktree
description: "用 git worktree 把一段工作隔离到独立工作目录:按路由单从指定基线创建 worktree、列出现有 worktree、在其间切换、用完安全清理(remove + prune)。支持多人/多 Agent 并行、不打断当前工作的并行开发,以及 Epic 模式下基于集成分支建子需求工作区。当 gw-route 判定需隔离、或用户要并行做多件事/让多个 Agent 互不干扰时触发。"
risk: caution
stage: isolate
scope: local
source: self
tags: "[git, worktree, isolation, parallel]"
---

# GW Worktree(工作区隔离)

把「一条分支 = 一个独立目录」。`git worktree` 让同一个仓库的多个分支**同时**各占一个工作目录,共享同一份 `.git` 对象库——切任务不再靠 `git stash` 或反复 `checkout` 打断现场,多个 Agent/多人可在各自目录并行而互不干扰。`risk: caution`:创建是安全的,**移除会删目录**,故收尾要确认无未提交/未推送改动。

> 布局约定、并行 Agent 隔离模式、常见陷阱与清理细则见 `${CLAUDE_PLUGIN_ROOT}/references/worktree-patterns.md`。

## 使用时机

- `gw-route` 路由单标注「隔离方式 = worktree」。
- 用户要**并行**做多件事:在不打断当前分支的前提下并行修 bug、对照另一分支、跑长测试。
- **多 Agent / 多人并行**:每个任务一个 worktree,彼此文件系统隔离,避免互相踩。
- **Epic 模式**:为一个大需求的多个小需求,各自建一个**基于 epic 集成分支**的 worktree。
- 收尾:某分支已合并/废弃,回收其 worktree。

## 输入要求

- **必需**:目标分支名与**基线**(来自 `gw-route` 路由单:Trunk-Based→`origin/main`;Epic 子需求→`epic/<name>`;hotfix→发布点)。
- **现场采集**:`git worktree list`(现有 worktree 与其分支)、`git status`(主工作区是否干净)、仓库根路径。
- **可选**:worktree 存放位置约定(缺省放仓库同级的 `../<repo>-worktrees/<branch>`,避免嵌套在工作树内被工具误扫)。

## 流程

1. **选存放位置**。推荐**仓库目录之外**的同级目录:`../<repo>.worktrees/<branch-slug>`。不要放进仓库工作树内部(会被 lint/打包/IDE 误扫,也易误提交)。把该 worktree 根目录加入全局忽略或确认已被 `.gitignore` 顾及。
2. **据基线创建**。一条命令同时建分支 + 建目录:
   - 新分支:`git worktree add -b <branch> <path> <base>`
     - Trunk-Based:`git worktree add -b feature/x ../repo.worktrees/x origin/main`
     - Epic 子需求:`git worktree add -b feature/checkout-coupon ../repo.worktrees/coupon epic/checkout`
   - 检出已有分支:`git worktree add <path> <existing-branch>`
3. **铁律:一条分支只能被一个 worktree 检出**。若分支已在别处检出,`git` 会拒绝;改为检出不同分支,或先去那个 worktree 处理。
4. **进入并开工**。`cd <path>`;该目录是完整工作树,可独立 `commit / sync / ship`。多 Agent 场景:每个 Agent 固定在自己的 worktree 路径内操作,绝不跨目录改文件。
5. **列出 / 盘点**。`git worktree list` 看全部 worktree 及其分支与 HEAD;判断哪些已合并可回收(配合 `git branch --merged`)。
6. **安全清理(收尾)**。**移除前必查**该 worktree 无未提交改动(`git -C <path> status --porcelain` 为空)且分支已合并或已推送:
   - `git worktree remove <path>`(目录干净才成功;脏目录需先处理,勿轻易 `--force`)。
   - 分支已合并可删:`git branch -d <branch>`。
   - `git worktree prune` 清理已被手动删目录后残留的元数据。
7. **报告**。列出本次新建/移除了哪些 worktree、各自分支与路径、是否仍有未清理项。

## 输出

| 工件 | 内容 |
| :--- | :--- |
| worktree 清单 | 路径 → 分支 → 基线 → 用途(任务/Agent) |
| 进入指引 | 目标 worktree 的绝对路径,后续 `gw-commit`/`gw-ship` 在此执行 |
| 清理报告 | 已移除的 worktree、已删分支、`prune` 结果;仍有未清理项则列明原因 |

## 校验清单

- [ ] worktree 路径在仓库工作树**之外**,不会被工具误扫或误提交
- [ ] 创建时基线正确(Epic 子需求基于 `epic/<name>` 而非 `main`)
- [ ] 没有让同一分支在两个 worktree 被检出
- [ ] 多 Agent 场景:每个 Agent 只在自己的 worktree 路径内操作
- [ ] **移除前已确认目录无未提交改动、分支已合并或已推送**,未盲目 `--force`
- [ ] 移除后跑过 `git worktree prune`,`git worktree list` 与实际一致

## 回溯触发

- `git worktree add` 报「分支已被检出」→ 该分支已在别处,改建别的分支或转去既有 worktree。
- 要移除的 worktree 仍有未提交/未推送改动 → 转 `gw-commit` 收掉,或在该目录 `gw-ship` 推走,再回来移除;不可直接 `--force` 丢工作。
- 误删了 worktree 目录但没 `remove` → `git worktree prune` 后重建;若分支也丢,转 `gw-recover` 用 reflog 找回。
- 发现要在 worktree 里 rebase 一条**共享**分支 → 停,转 `gw-sync` 按可见性规则处理(共享分支不改写历史)。

## 示例

```text
路由单：epic 模式,2 个小需求并行,各开 worktree（base=epic/checkout）

gw-worktree：
  $ git worktree add -b feature/checkout-coupon  ../shop.worktrees/coupon  epic/checkout
  $ git worktree add -b feature/checkout-payment ../shop.worktrees/payment epic/checkout
  $ git worktree list
    /repo/shop                      a1b2c3 [main]
    /repo/shop.worktrees/coupon     d4e5f6 [feature/checkout-coupon]
    /repo/shop.worktrees/payment    a7b8c9 [feature/checkout-payment]

  → Agent A 固定在 .../coupon 开发优惠券；Agent B 固定在 .../payment 开发支付
    各自 gw-commit → gw-ship（PR 目标均为 epic/checkout）

收尾（coupon 已合并进 epic/checkout）：
  $ git -C ../shop.worktrees/coupon status --porcelain   # 空，干净 ✅
  $ git worktree remove ../shop.worktrees/coupon
  $ git branch -d feature/checkout-coupon
  $ git worktree prune
```
