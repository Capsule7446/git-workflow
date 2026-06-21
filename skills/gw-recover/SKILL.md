---
name: gw-recover
description: "Git 误操作救援:用 reflog 找回丢失的提交/分支、撤销错误的 rebase/merge/reset、区分 revert(共享安全) 与 reset(私有可用)、cherry-pick 捡回提交、应对错推的密钥。优先可逆、可追溯的手段。当发生误删分支、rebase 搞乱历史、reset 丢工作、合并引入回归、或密钥被推上远端时触发。"
risk: caution
stage: recover
scope: local
source: self
tags: "[git, recover, reflog, revert, reset]"
---

# GW Recover(误操作救援 / 回溯)

git 几乎不真正丢东西——只要提交曾存在过,`reflog` 与悬空对象在垃圾回收前都还在。本工序是整套体系的**安全网**:任何一站出事都能回到这里。核心判断是**共享 vs 私有**:共享历史只能用**前向、可追溯**的修复(`revert`),私有历史才可用**改写**(`reset`/`rebase`)。`risk` 跨度大,`reset --hard`、改写已推送历史属 `danger`,先确认再动。

> 完整救援食谱(reflog 定位、各种 reset 模式、revert 合并提交、cherry-pick、恢复 stash、找回 detached HEAD)见 `${CLAUDE_PLUGIN_ROOT}/references/recovery-cookbook.md`。

## 使用时机

- 误删分支、误 `reset --hard`、`rebase`/`merge` 把历史搞乱。
- 合并到共享主线后发现引入回归,要安全回退。
- 提交/分支"不见了",或处于 detached HEAD 不知如何回去。
- **密钥被 commit 并推上远端**(需改写历史 + 轮换密钥)。
- 被任何 skill 的回溯触发指向这里。

## 输入要求

- **必需**:出了什么事的描述(误删/误 reset/坏 rebase/回归/泄密)、涉及的分支是**私有还是共享**。
- **现场采集**:`git reflog`(HEAD 移动史,救援的主力)、`git reflog <branch>`、`git log --oneline --graph --all`、`git fsck --lost-found`(找悬空对象)、`git status`。
- **可选**:操作前是否记得某个 hash 或 `ORIG_HEAD`。

## 流程

1. **先别再动 + 快照现状**。停止任何会触发 GC 或继续改写的操作;`git reflog` 拉出 HEAD 的移动历史——绝大多数"丢失"都能在这里找到操作前的那一行。需要时 `git fsck --full --no-reflogs --lost-found` 找悬空提交。
2. **定位安全点**。从 reflog 找到"出事前"的提交 hash(如 `HEAD@{3}`)或 `ORIG_HEAD`(rebase/merge/reset 前 git 自动存的点)。
3. **判私有 vs 共享,选手段**:
   - **私有历史**(未推送 / 只你的分支):可用改写复原——
     - 撤销坏 rebase/reset:`git reset --hard ORIG_HEAD` 或 `git reset --hard HEAD@{n}`。
     - 找回工作但保留改动:`git reset --soft`(留暂存)/ `--mixed`(留工作区)。
   - **共享历史**(已推送 / 多人):**禁止改写**,只能前向修复——
     - 撤销已合并的提交/合并:`git revert <commit>`(普通)、`git revert -m 1 <merge>`(合并提交);产生一个"反向提交",可追溯、对协作者安全。
4. **找回丢失的分支/提交**:
   - 误删分支:`git branch <name> <hash-from-reflog>` 重建。
   - 捡回个别提交到当前分支:`git cherry-pick <hash>`。
   - 找回 detached HEAD 上的工作:`git branch <name>` 当场固定。
   - 找回误丢的 stash:`git fsck --lost-found` / `git stash list` 比对。
5. **泄密专项**(密钥已推送):**视为已泄露**——
   - 第一优先级:**轮换/吊销该密钥**(改写历史不等于没人拉过)。
   - 再清历史:`git filter-repo`(或 BFG)从全历史移除,强制推送,通知所有人重新 clone/rebase。这是 `danger`,务必与用户确认并协调团队。
6. **复原后回到正轨**:转 `gw-sync` 重新对齐基线,确认历史与远端一致。
7. **报告**:发生了什么、用何手段复原(reflog hash / revert / reset)、是否动了共享历史、后续待办(轮换密钥 / 通知协作者)。

## 输出

| 工件 | 内容 |
| :--- | :--- |
| 救援结论 | 故障类型、定位到的安全点(reflog/ORIG_HEAD)、采用的手段 |
| 复原结果 | 找回的分支/提交、当前 HEAD 状态 |
| 后续待办 | 是否需轮换密钥、通知协作者、回 `gw-sync` 对齐 |

## 校验清单

- [ ] 出事后**第一时间停手**,先 `git reflog` 而非继续操作
- [ ] 已正确区分私有/共享:**共享历史只 `revert`,绝不 `reset`/改写**
- [ ] `reset --hard` 等 `danger` 动作前已确认安全点 hash、已与用户确认
- [ ] 泄密场景**先轮换密钥**,再谈清历史;清历史已协调团队
- [ ] 复原后已转 `gw-sync` 对齐基线,历史与远端一致
- [ ] 记录了故障原因(供日后避免;如"对共享分支做了 rebase")

## 回溯触发

- reflog 里也找不到(可能已 GC 且无悬空对象)→ 检查远端/其他人本地/CI 缓存是否还有该提交;`git fsck` 最后一搏。
- 复原需要改写**共享**历史(除泄密外)→ 通常说明方向错了:改用 `revert` 前向修复,而非强行改写。
- 同类误操作反复发生(总在共享分支 rebase)→ 回 `gw-sync`/`gw-route` 复核分支可见性纪律与分支保护设置。

## 示例

```text
情形 A：私有 feature 分支上 rebase 搞乱了，想回到 rebase 前
  git reflog                          # 找到 rebase 前那行：HEAD@{5} 或看 ORIG_HEAD
  git reset --hard ORIG_HEAD          # 私有分支，可改写 → 复原
  → 转 gw-sync 重新干净地 rebase 一次

情形 B：合并进 main 后发现回归（main 是共享）
  git revert -m 1 <merge-commit>      # 前向反向提交，不改写共享历史
  git push                            # 安全；协作者拉到的是一个新提交
  → 修复后可重新开 PR 带正确改动

情形 C：误删了分支 feature/x
  git reflog | grep feature/x         # 或 git reflog 找到它最后的 hash
  git branch feature/x <hash>         # 重建
  git worktree prune                  # 若它的 worktree 也没了

情形 D：API key 被 commit 并 push 了
  1) 立刻去服务商 吊销/轮换 该 key（视为已泄露）
  2) git filter-repo --path config/secret.env --invert-paths   # 清全历史
  3) git push --force-with-lease（共享 → 与团队协调，通知重新 clone）── danger，确认
```
