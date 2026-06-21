---
name: gw-sync
description: "让当前分支与基线保持同步,并安全管理共享历史:按分支可见性(私有 vs 共享)选 rebase 或 merge、有纪律地解决冲突、保持线性历史、用 --force-with-lease 安全推送、把 main 周期性 merge 进 epic 集成分支。核心铁律:绝不改写共享分支的历史。当分支落后基线、要整理提交、或推送被远端拒绝(non-fast-forward)时触发。"
risk: caution
stage: sync
scope: remote
source: self
tags: "[git, sync, rebase, merge, conflict]"
---

# GW Sync(基线同步 / 历史管理)

让你的工作跟上基线,并决定历史长什么样。本工序的全部安全性压在一条铁律上:

> **rebase 黄金法则:绝不对共享分支改写历史。** 私有分支(只有你在用、未推送或只你推送)随便 rebase 整理;共享分支(`main`、`epic/*`、`develop`、任何多人推送的分支)只能 merge、只进不改写。

正因如此本工序 `risk` 跨度大:私有 rebase 是 `caution`,而 **force-push 共享分支、`rebase` 已被他人基于的分支属 `danger`**——必须停下确认并优先用可逆形式。

## 使用时机

- 当前分支落后基线(`git status` 显示 behind,或基线已前进)。
- 提交前/交付前要把分支**线性化**地接到最新基线之上。
- `git push` 被拒(`non-fast-forward` / `fetch first`)。
- **Epic 模式**:把最新 `main` 周期性同步进 `epic/<name>` 集成分支,避免收口时巨型冲突。
- **被回溯触发**:`gw-ship` 的 G3 门禁要求"已同步基线、无冲突";`gw-recover` 修完误操作后回这里重新对齐。

## 输入要求

- **必需**:目标基线(来自路由单)、**当前分支的可见性标记(私有/共享)**——决定能否 rebase。
- **现场采集**:`git fetch --all --prune` 后 `git status`、`git log --oneline --graph origin/<base>..HEAD`(本地领先)与 `HEAD..origin/<base>`(落后)、`git branch -r --contains HEAD`(是否已有他人基于本分支)。
- **可选**:团队对线性历史 vs 合并提交的偏好、分支保护规则。

## 流程

1. **先 fetch,看清分叉**。`git fetch origin --prune`;用 `--graph` 看本地与基线各自领先多少、是否真有分叉。
2. **判可见性(决定 rebase 还是 merge)**:
   - **私有分支**(未推送 / 只你推送 / 无人基于它):优先 **rebase** 接到最新基线,保持线性:`git rebase origin/<base>`。亦可 `git rebase -i` 整理(squash/reword)成干净提交序列。
   - **共享分支**(`main`/`epic/*`/`develop`/多人推送):**只能 merge**,绝不 rebase。
3. **Epic 同步方向要对**。让 epic 跟上 main:在 epic 分支上 `git merge origin/main`(把 main **合进** epic)——**不是**把 epic rebase 到 main。子需求分支(私有)则可 `git rebase epic/<name>` 自由整理。
4. **有纪律地解决冲突**:
   - 逐文件理解**双方意图**再改,不是无脑选一边;`git diff`/`git log` 看冲突两侧来历。
   - 解决后 `git add <file>`;rebase 用 `git rebase --continue`,merge 用 `git commit`。
   - 一旦发现解法越改越乱:`git rebase --abort` / `git merge --abort` 回到起点重来,**不在半截状态硬推**。
   - 重复同类冲突可开 `git rerere` 让 git 记忆解法。
5. **安全推送**:
   - 普通快进:`git push`。
   - rebase 后需覆盖**自己的私有远端分支**:**只用** `git push --force-with-lease`(它在远端被他人动过时会拒绝,避免覆盖别人;`--force` 严禁)。
   - 推**共享分支**前确认是 fast-forward;非快进说明有人先推了 → 先 `fetch` 再 merge,**绝不 force**。
6. **报告**:同步方式(rebase/merge)、是否 force-with-lease、解决了哪些冲突、当前与基线关系(应为 up to date 或仅领先)。

## 输出

| 工件 | 内容 |
| :--- | :--- |
| 同步结果 | 方式(rebase/merge)、基线、最终领先/落后状态(应已对齐) |
| 冲突记录 | 哪些文件冲突、各自如何取舍(供 review 追溯) |
| 推送结果 | 是否推送、是否 `--force-with-lease`、远端分支状态 |

## 校验清单

- [ ] 操作前已 `git fetch --prune`,基于最新远端判断分叉
- [ ] **私有分支才 rebase;共享分支(main/epic/develop/多人)一律只 merge**
- [ ] Epic 同步方向正确:`main` merge 进 `epic`,而非 epic rebase 到 main
- [ ] 冲突按双方意图解决,非无脑选边;乱了用 `--abort` 重来而非硬推
- [ ] 需覆盖远端时**只用 `--force-with-lease`**,从不 `--force`
- [ ] 共享分支推送是 fast-forward;非快进先 fetch+merge,绝不强推
- [ ] `danger` 级动作(force-push、rebase 可能被他人基于的分支)已停下与用户确认

## 回溯触发

- `--force-with-lease` 被拒 → 远端被他人更新了:先 `fetch`,看清对方改了什么,merge 进来再推;切勿升级成 `--force`。
- rebase 中冲突连环、历史越理越乱 → `git rebase --abort`,改用 merge,或转 `gw-recover` 用 reflog 回到 rebase 前。
- 发现自己**已经 rebase 了一条共享分支并 force 推了** → 立即转 `gw-recover`:用 reflog/`ORIG_HEAD` 复原,通知所有协作者,改用 merge 重做。
- 冲突根因是两个工作单元职责重叠(同处反复打架)→ 回 `gw-route` 重新切分边界。

## 示例

```text
情形 A：私有 feature 分支落后 origin/main 6 个提交，准备交付
  git fetch origin --prune
  git rebase origin/main            # 私有分支 → rebase 保持线性
  # 解决 2 处冲突 → git add → git rebase --continue
  git push --force-with-lease       # 覆盖自己的远端分支，安全
  → up to date，交给 gw-ship

情形 B：epic/checkout（共享）要跟上 main
  git switch epic/checkout
  git fetch origin
  git merge origin/main             # 合进来，绝不 rebase 共享分支
  git push                          # fast-forward 推送
  → 子需求分支随后各自 git rebase epic/checkout 自由整理（私有）

情形 C：push 被拒 non-fast-forward（共享分支有人先推）
  git fetch origin
  git merge origin/<branch>         # 先合别人的，再推；不 force
  git push
```
