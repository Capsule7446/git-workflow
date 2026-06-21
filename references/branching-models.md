# Reference：分支模型菜单（按环境选风格）

> `git-workflow:gw-route` 的选择依据。这里把常见的分支/集成风格摊开,给出**各自适用环境、基线/PR 目标、合并策略与取舍**。gw-route 是选择器——按团队规模、CI/开关成熟度、发版节奏、是否大需求并行,从中选一种并与用户确认,不锁死缺省。

## 0. 一张选择表

| 风格 | 长期分支 | feature 基线 | PR 目标 | 最适合 | 主要代价 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Trunk-Based / GitHub Flow | `main` | `main` | `main` | CI/CD、小步频繁合并、并行 worktree | 需要纪律保持 main 始终可部署 |
| Git Flow | `main` + `develop` | `develop` | `develop` | 定期发版、多版本并行维护、强审批 | 分支多、合并开销大、不适合持续部署 |
| Epic 集成分支 | `main`（epic 临时) | `epic/<name>` | `epic/<name>` | 大需求拆多小需求、多人/多 Agent 并行 | 要管同步与收口,集成分支需保护 |
| Feature Flags on trunk | `main` | `main` | `main`(藏开关后) | 强 CI + 开关基建,避免长命分支 | 需开关基建 + 清理欠债 |
| 共享分支 | 一条共享分支 | 共享分支本身 | 直接 push | 临时、2-3 人 | 易冲突、改写历史伤全员 |
| Stacked PR | `main` + 栈 | 上一层分支 | 自底向上逐层 | 单人一串相互依赖小改动 | 维护栈、变基繁琐 |

---

## 1. Trunk-Based / GitHub Flow（缺省默认）

```
main ──●──────────●───────────●────  ← 始终可部署
        \        ↑ PR 合并    ↑ tag v1.2.0
         feature/login ───────┘
```

- **一条**长期分支 `main`;`feature/*`/`fix/*` 短命,从 `main` 切、PR 合回 `main`。
- 无常驻 `dev`;发版靠 **tag**(需要时才开临时 `release/*`)。
- `main` 始终可部署——这是纪律,不是口号:每个 PR 进 main 前 CI 必绿。
- **何时选**:持续部署/小团队/频繁合并/并行 worktree、多 Agent。
- **代价**:要求成熟 CI 与小步提交习惯;大功能需配合短命分支或开关,避免长期分叉。

## 2. Git Flow（含常驻 develop）

```
main    ─────────────────●──────  tag v1.2.0（只接 release/hotfix）
                        ↑ release/1.2
develop ──●──────●───────●───────  ← 集成分支(常驻)
           \    ↑ PR
            feature/login
```

- **两条**长期分支:`main`(生产)+ `develop`(集成);外加 `release/*`、`hotfix/*`。
- `feature/*` 从 `develop` 切、合回 `develop`;`release/*` 从 develop 出 → 合入 `main` 打 tag,并回灌 develop;`hotfix/*` 从 `main` 出 → 合 `main` + `develop`。
- **何时选**:固定发版周期、需同时维护多个已发布版本、强审批关卡、CI 不够成熟。
- **代价**:分支多、合并/回灌开销大,与持续部署相冲突。现代 CI/CD 团队多已弃用。

## 3. Epic 集成分支（大需求并行,本插件重点)

```
main ──●──────────────────────────────●────  ← 始终可部署
        \  (建 epic)                 ↑ 收口:epic 整体一个 PR 合 main
         epic/checkout ──●────●────●──┘        ← 集成分支:禁直接 push、只接 PR、周期 merge main
              ↑PR    ↑PR    ↑PR
              │      │      └ feature/checkout-coupon
              │      └─────── feature/checkout-payment
              └────────────── feature/checkout-cart
```

- 一个大需求开一条 **`epic/<name>` 集成分支**(从 `main` 切),用完即删——**不是**永久 `develop`。
- 每个小需求 = 短命子分支 `feature/<name>-<sub>`,基线与 PR 目标都是 **epic 分支**(不是 main)。
- 集成分支**共享**:禁直接 push、禁 rebase,加分支保护,只接子需求 PR;周期性把 `main` **merge** 进来防收口巨冲突。
- 子分支**私有**:可自由 `rebase epic/<name>` 整理。
- 收口:epic 整体一个 PR 合 `main`,然后删 epic + 全部子分支 + 全部 worktree。
- **何时选**:大需求拆多小需求、多人/多 Agent 并行,既要"小需求一起开发并集成"又不想踩同一分支。
- **代价**:要管同步方向与收口时机;集成分支需分支保护。完整编排见 `workflow-epic.md`。
- 这正是 `master → feature → dev → master` 直觉的正确落地:`dev` 改为**每需求一条、临时**的 epic 分支。

## 4. Feature Flags on trunk（最纯 Trunk-Based 的大需求解法）

- 不开长命分支:小需求小步直接合进 `main`,但功能**藏在开关(feature flag)后面**,默认关闭。
- 大需求拼齐、验证完成后,才打开开关放量。
- **何时选**:CI 强、有开关基建(自建或 LaunchDarkly/Unleash 等)、想彻底避免长期分叉与巨型合并。
- **代价**:需要开关基建;开关是技术债——上线稳定后要及时清理死开关。
- 与 Epic 的取舍:能小步上 main 就用 Flags(合并痛苦最小);不能(改动需整体才自洽、或无开关基建)就用 Epic 集成分支。

## 5. 共享分支（多人直接 push 同一分支)

- 多人直接往同一条分支 push。简单,但脆弱。
- **唯一铁律**:**共享分支绝不改写历史**——不 rebase、不 force-push。只 `git pull --rebase` 整理**自己未推送**的提交,合并用 merge/fast-forward,开分支保护禁 force。
- **何时选**:临时、2-3 人、短周期协作,不值得开 PR 流程时。
- **代价**:人一多就频繁 non-fast-forward 冲突;一旦有人 force-push,全员历史错乱。多于 3 人应升级到 Epic 集成分支(各自分支 + PR)。

## 6. Stacked PR（单人依赖链)

```
main ──●
        \
         A: feature/api-types        ← PR1 → main
          \
           B: feature/api-impl       ← PR2 → A
            \
             C: feature/api-ui       ← PR3 → B
```

- 一个人做一串**相互依赖**的小改动:每层分支基于上一层,PR 自底向上逐层 review、逐层合并。
- 工具:`git rebase --update-refs`(一次 rebase 同步更新整条栈的引用)、或 Graphite/spr 等。
- **何时选**:单人想把一个大改动拆成多个**小而可独立 review** 的 PR,但它们有先后依赖。
- **代价**:底层 PR 一变,上层都要 rebase;需要工具或纪律维护栈的顺序。

---

## 7. 合并策略（gw-integrate 用）

| 策略 | 结果 | 适合 |
| :--- | :--- | :--- |
| **Squash** | 整个 PR 压成一个提交进主线 | 子需求小 PR、想要主线"一 PR 一提交"、历史干净(Trunk-Based 常用) |
| **Merge commit** | 保留分支全部提交 + 一个合并点 | 想保留完整开发历史与分支拓扑(epic 收口常用) |
| **Rebase merge** | 分支提交线性接到目标,无合并点 | 想要纯线性历史且每个提交都有保留价值 |

- 同一仓库**统一选一种**,别混用,否则历史风格分裂。
- Squash 让 `revert`/`bisect` 以 PR 为粒度,简单;但丢失分支内的细粒度历史。
- Merge commit 保留全部信息,但主线图复杂。
- 发版打 tag 遵循 **SemVer**:破坏性→major、新功能→minor、修复→patch。

## 8. 私有 vs 共享分支（贯穿全体系的安全轴)

| | 私有分支 | 共享分支 |
| :--- | :--- | :--- |
| 定义 | 只你在用、未推送或只你推送、无人基于 | `main`/`epic/*`/`develop`/任何多人推送 |
| 可否 rebase / 改写历史 | **可**(自由整理、squash、reword) | **绝不**(只 merge、只前向) |
| 覆盖远端 | `--force-with-lease`(覆盖自己的) | 禁止 force;非快进先 fetch+merge |
| 撤销手段 | `reset`/`rebase` | `revert`(前向、可追溯) |

> 这条轴决定了 `gw-sync`(rebase vs merge)与 `gw-recover`(reset vs revert)的全部安全行为。`gw-route` 在路由单里给每条目标分支打上私有/共享标记,下游据此行事。
