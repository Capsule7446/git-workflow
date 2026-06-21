# Reference：Worktree 模式（布局 · 并行 · 陷阱 · 清理）

> `git-workflow:gw-worktree` 的深度参考。`git worktree` 让一个仓库的多个分支**同时**各占一个独立工作目录,共享同一份 `.git` 对象库。切任务不再靠 `git stash` 或反复 `checkout` 打断现场。

## 1. 核心心智模型

- 一个仓库 = 一份对象库(`.git`)+ **多个**工作树。`git clone` 给你第一个(主)工作树;`git worktree add` 再加更多。
- 每个工作树有自己的 `HEAD`、索引、检出的分支、未提交改动——**互相隔离**。
- 对象、refs、reflog、配置、stash 是**共享**的(同一 `.git`)。所以在任一工作树提交,所有工作树都能立刻看到那个提交。
- **一条分支同一时刻只能被一个工作树检出**——这是最常撞的限制(见 §4)。

## 2. 目录布局约定

把 worktree 放在**主仓库目录之外**的同级位置:

```
~/code/
├── shop/                      ← 主工作树(git clone 来的)
│   └── .git/                  ← 唯一的对象库
└── shop.worktrees/            ← 所有附加 worktree 放这里
    ├── coupon/                ← feature/checkout-coupon
    ├── payment/               ← feature/checkout-payment
    └── hotfix-login/          ← hotfix/login-500
```

- **不要**把 worktree 建在主工作树内部(如 `shop/wt/...`):会被 lint / 打包脚本 / IDE 索引误扫,也容易被误 `git add`。
- 命名用分支的 slug,一眼对得上。
- 确认这些目录不被任何工具当作源码扫描(在工作树外天然规避)。

## 3. 常用命令速查

```bash
# 建:新分支 + 新目录,从指定基线
git worktree add -b feature/x ../shop.worktrees/x origin/main
git worktree add -b feature/checkout-coupon ../shop.worktrees/coupon epic/checkout

# 建:检出一条已存在的分支到新目录
git worktree add ../shop.worktrees/review origin/feature/y

# 临时看某个提交(detached),如对照调试
git worktree add --detach ../shop.worktrees/inspect <commit>

# 盘点
git worktree list                 # 路径 + HEAD + 分支
git worktree list --porcelain     # 脚本可解析

# 清理
git worktree remove ../shop.worktrees/coupon    # 目录干净才成功
git worktree prune                              # 清手动删目录后的残留元数据
git worktree move <from> <to>                   # 搬目录(别手动 mv)
git worktree lock/unlock <path>                 # 锁定(如在移动盘上)防被 prune
```

## 4. 陷阱与对策

| 陷阱 | 现象 | 对策 |
| :--- | :--- | :--- |
| 同分支双检出 | `add` 报 "already checked out" | 一条分支只能一个工作树;改检别的分支,或去那个工作树处理。需要并行看同一分支用 `--detach` |
| 手动 `rm -rf` 工作树 | `worktree list` 仍列着幽灵项 | 用 `git worktree remove`;已手删则 `git worktree prune` |
| 在工作树内嵌套建 | 被工具误扫/误提交 | 一律建在主工作树**之外** |
| 移动盘/网络盘上的工作树被 prune | 元数据丢失 | `git worktree lock` 锁定 |
| 共享的 stash 误用 | stash 是全仓库共享的,跨工作树可见 | 注意 `git stash` 不是按工作树隔离的;优先小步提交而非 stash |
| 大仓多工作树占盘 | 每个工作树是完整检出 | 对象库共享(省),但工作文件各占一份;及时清理用完的 |

## 5. 并行 Agent / 多人模式（本插件重点)

worktree 是"多 Agent 并行开发"的物理隔离层:

```
epic/checkout（集成分支)
├── Agent A → ../shop.worktrees/coupon   [feature/checkout-coupon]
├── Agent B → ../shop.worktrees/payment  [feature/checkout-payment]
└── Agent C → ../shop.worktrees/recon    [feature/checkout-recon]
```

纪律:

1. **一个任务/Agent = 一个 worktree = 一条分支**。Agent 只在自己的目录内读写,绝不跨目录改文件。
2. **基线对齐场景**:Epic 模式下全部子需求 worktree 基于同一 `epic/<name>`;各自 `rebase epic/<name>` 跟进(子分支私有,可 rebase)。
3. **对象库共享 = 零拷贝协作**:Agent A 提交的对象,Agent B 立刻可见,无需推拉远端即可 `cherry-pick`/对照。
4. **收尾集中清理**:大需求收口后,一次性 `remove` 所有子 worktree + `prune`(见 `workflow-epic.md` 的全家桶清理)。
5. **与本会话 harness 的关系**:本仓库所在的 agent harness 也支持 `isolation: worktree` 给子 Agent 开隔离工作区——同一原理;手动 `git worktree` 给你对布局与基线的完全掌控。

## 6. 安全清理清单（gw-worktree 收尾据此)

移除任何 worktree 前,逐项确认:

- [ ] `git -C <path> status --porcelain` 为空(无未提交改动)
- [ ] 该分支已合并(`git branch --merged` 含它)或已推送远端(工作不会丢)
- [ ] `git worktree remove <path>`(不轻易加 `--force`——`--force` 会连未提交改动一起丢)
- [ ] 分支不再需要 → `git branch -d <branch>`(`-d` 要求已合并)
- [ ] `git worktree prune` 清残留
- [ ] `git worktree list` 与实际目录一致
