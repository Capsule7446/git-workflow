# Reference：救援食谱（reflog · reset · revert · cherry-pick)

> `git-workflow:gw-recover` 的操作手册。核心信念:git 几乎不真正丢东西——曾被提交过的内容,在垃圾回收(GC)前都还能从 `reflog` 或悬空对象里找回。第一反应永远是 **`git reflog`,而不是慌**。

## 0. 黄金判断:私有还是共享?

| | 私有历史(未推送/独占) | 共享历史(已推送/多人) |
| :--- | :--- | :--- |
| 可用手段 | `reset`、`rebase`(改写) | **只能** `revert`(前向) |
| 撤销已发布的提交 | `reset --hard <安全点>` | `git revert <commit>` |
| 原因 | 没人基于它,改写无害 | 改写会让所有协作者历史错乱 |

> 唯一例外:**已推送的密钥**——即便共享也必须改写历史清除,但**第一优先是轮换密钥**(见 §6)。

## 1. reflog:救援主力

```bash
git reflog                 # HEAD 的全部移动史:每次 commit/checkout/reset/rebase/merge 都留痕
git reflog show <branch>   # 某分支 ref 的移动史
```

- 每行形如 `a1b2c3d HEAD@{2}: rebase (finish): ...`。`HEAD@{n}` 可直接当提交引用用。
- 找到"出事前"那一行的 hash 或 `HEAD@{n}`,就有了安全点。
- reflog 默认保留 90 天(可达对象 30 天),期间 GC 不会清。

## 2. 撤销坏的 reset / rebase / merge（私有)

```bash
# git 在每次 reset/rebase/merge 前自动把原 HEAD 存进 ORIG_HEAD
git reset --hard ORIG_HEAD          # 一步回到操作前(最常用)

# 或从 reflog 精确定位
git reset --hard HEAD@{5}

# 进行中的 rebase/merge 想直接放弃
git rebase --abort
git merge  --abort
```

reset 三种模式(按"保留多少改动"):

| 模式 | HEAD | 暂存区 | 工作区 | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| `--soft` | 移动 | 不变 | 不变 | 撤提交但留全部改动在暂存区(重组提交) |
| `--mixed`(默认) | 移动 | 重置 | 不变 | 撤提交+撤暂存,改动留工作区 |
| `--hard` | 移动 | 重置 | **重置** | 彻底回到某点,**丢弃工作区改动**(danger) |

## 3. 撤销已发布的提交 / 合并（共享,前向)

```bash
git revert <commit>             # 生成一个"反向提交",抵消该提交;可追溯、对协作者安全
git revert -m 1 <merge-commit>  # 回退一个合并提交:-m 1 表示保留第一父(通常是主线)
git push                        # 安全推送;别人拉到的是一个新提交,无需 rebase
```

- 共享主线**永远用 revert,不用 reset**。
- 若 revert 后想重新引入(改对了再来),可 `git revert <那个revert>` 或重做改动。

## 4. 找回丢失的分支 / 提交

```bash
# 误删分支 → 从 reflog 找到它最后的 hash 重建
git reflog | grep <branch-name>          # 或翻 git reflog
git branch <branch-name> <hash>

# 捡回个别提交到当前分支
git cherry-pick <hash>
git cherry-pick <hashA>^..<hashB>        # 一段范围

# detached HEAD 上做了提交又切走 → 当场固定
git branch <name> <hash-from-reflog>

# 悬空对象(连 reflog 都没有时的最后一搏)
git fsck --full --no-reflogs --lost-found    # 列 dangling commit/blob
git show <dangling-hash>                      # 确认内容
```

## 5. 找回 stash / 工作区

```bash
git stash list
git stash apply stash@{2}        # 应用但保留
git stash pop                    # 应用并移除

# 误 drop 的 stash(stash 是 commit,也在悬空对象里)
git fsck --no-reflogs | grep commit
git stash apply <dangling-commit-hash>
```

## 6. 密钥误推专项（已推送 = 已泄露)

顺序不能错:

```bash
# 1) 第一优先级:去服务商 吊销/轮换 该密钥
#    —— 改写历史不代表没人在你清理前已经拉过/抓过。视为已泄露。

# 2) 从全历史移除(推荐 git-filter-repo;或 BFG Repo-Cleaner)
git filter-repo --path path/to/secret --invert-paths
#    或按内容:git filter-repo --replace-text <(echo 'SECRET==>REMOVED')

# 3) 强制推送 + 协调团队(danger,需确认)
git push --force-with-lease --all
git push --force-with-lease --tags
#    通知所有协作者:重新 clone,或对其本地分支 rebase 到新历史

# 4) 把该路径加入 .gitignore,改用环境变量/密钥管理器
```

## 7. 误操作 → 救援动作 速查

| 误操作 | 私有/共享 | 救援 |
| :--- | :--- | :--- |
| `reset --hard` 丢了提交 | 私有 | `git reset --hard ORIG_HEAD` 或 reflog hash |
| rebase 把历史搞乱 | 私有 | `git rebase --abort`(进行中)/ `reset --hard ORIG_HEAD`(已完成) |
| 删错了分支 | — | reflog 找 hash → `git branch <name> <hash>` |
| 提交到了错的分支 | 私有 | 在对的分支 `cherry-pick`,原分支 `reset` 掉 |
| 合并进主线引入回归 | 共享 | `git revert -m 1 <merge>` |
| amend 覆盖了上个提交 | 私有 | reflog 找 amend 前的 hash → `cherry-pick`/`reset` |
| detached HEAD 上的提交快丢了 | — | `git branch <name> <hash>` 固定 |
| 误 drop 的 stash | — | `git fsck` 找 dangling commit → `stash apply <hash>` |
| 密钥推上远端 | 共享 | **先轮换密钥** → filter-repo 清史 → 协调团队强推 |

## 8. 预防 > 救援

- 共享分支加**分支保护**(禁 force-push、禁直接 push、必经 PR)——从源头杜绝多数事故。
- 危险操作前先记 `git rev-parse HEAD` 或开个备份分支 `git branch backup/<now>`。
- 开 `git rerere` 让 git 记忆冲突解法,减少反复解冲突中的失误。
- `reset --hard` / `clean -fd` / force-push 前,养成"先确认安全点 hash"的习惯。
