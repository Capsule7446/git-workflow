---
name: gw-commit
description: "把工作区改动整理成一串原子提交,每条配一条符合 Conventional Commits 的信息:按职责拆分暂存(可到 hunk 级)、为每个逻辑单元写 type(scope): subject + body + footer、标注破坏性变更与关联工单、提交前扫描密钥/调试残留/意外文件。当改动已就绪要落盘、或 /commit 被触发时使用。"
risk: caution
stage: commit
scope: local
source: self
tags: "[git, commit, conventional-commits, atomic]"
---

# GW Commit(原子提交 + 提交信息工艺)

提交是 git 历史的最小可读单元,也是后续 review、`git bisect`、`git revert`、自动生成 changelog 的依据。本工序两条命脉:**原子性**(一个提交 = 一个完整且独立的逻辑变更)与**信息规范**(Conventional Commits)。`risk: caution`:只改本地历史,可逆(`reset`/`commit --amend`),但**改写已推送的共享历史属 `danger`**——那归 `gw-sync`/`gw-recover` 管。

> Conventional Commits 完整规范(type 全集、scope、`!` 与 `BREAKING CHANGE`、footer、commitlint 配置、co-author 脚注)见 `${CLAUDE_PLUGIN_ROOT}/references/commit-conventions.md`。

## 使用时机

- 一段改动写完、要落盘为历史。
- `/git-workflow:commit` 被触发。
- 开发过程中**随手小步提交**(推荐:边做边原子提交,而非攒一大坨)。
- **被回溯触发**:`gw-ship`/review 发现某提交混了多件事、或信息不达标 → 回这里重切分、改信息。

## 输入要求

- **必需**:非空的工作区改动;已在正确分支(由 `gw-route`/`gw-worktree` 落定)。
- **现场采集**:`git status --porcelain`、`git diff`(未暂存)、`git diff --cached`(已暂存)、`git log --oneline -5`(对齐本仓库既有信息风格/scope 习惯)。
- **可选**:关联 issue/工单号、本仓库是否已配 commitlint、是否要 co-author 脚注。

## 流程

1. **先看清全部改动**。读 `git diff` 与新增文件,按**逻辑单元**归类:哪些 hunk 属于同一件事。一次改动里常混着「功能 + 顺手重构 + 改格式」,要拆开。
2. **按职责分批暂存(原子性核心)**。
   - 整文件属于一件事:`git add <file>`。
   - 一个文件里混了多件事:`git add -p <file>` 按 hunk 选;更细可 `git add -e` 手工编辑补丁。
   - 目标:每批暂存 = 一个能独立描述、能独立回滚、能独立通过测试的变更。
3. **提交前扫描(门禁)**。对**已暂存**内容核查,任一命中则停下处理而非提交:
   - **密钥/凭据**:API key、token、密码、`.env`、私钥——绝不入库(命中先撤出暂存,提醒改用环境变量/密钥管理)。
   - **调试残留**:`console.log`/`print`/`dbg!`/断点、注释掉的死代码、`TODO/FIXME`(确认是否该留)。
   - **意外文件**:构建产物、依赖目录、本地配置、大二进制——应进 `.gitignore`。
   - **合并冲突标记**:`<<<<<<<` / `=======` / `>>>>>>>` 残留。
4. **为每个单元写 Conventional Commits 信息**:

   ```
   <type>(<scope>): <subject>        # 祈使句、现在时、≤50 字、结尾不加句号

   <body>                            # 可选:解释"为什么"而非"改了什么";每行 ≤72
                                     # 复杂改动列要点

   <footer>                          # 可选:BREAKING CHANGE: ... / Refs #231 / Closes #128
   ```
   - **type**:`feat` `fix` `docs` `style` `refactor` `perf` `test` `build` `ci` `chore` `revert`。
   - **scope**:受影响模块(沿用本仓库既有习惯,如 `feat(checkout):`)。
   - **破坏性变更**:type 后加 `!`(`feat(api)!: ...`)**并**在 footer 写 `BREAKING CHANGE: <说明>`。
   - **关联工单**:footer `Closes #128`(合并即关闭)或 `Refs #231`。
5. **提交并复核**。`git commit`(多行信息用 `-m` 多次或编辑器);`git show --stat HEAD` 复核范围与信息;错了用 `git commit --amend`(**仅限未推送**)。
6. **报告**。列出本次产生的提交(hash + 信息首行 + 文件数),指明下一站(`gw-sync` 对齐基线或 `gw-ship` 交付)。

## 输出

| 工件 | 内容 |
| :--- | :--- |
| 提交序列 | 每条:hash、`type(scope): subject`、涉及文件、是否破坏性 |
| 扫描结论 | 密钥/调试残留/意外文件/冲突标记 的核查结果(应为全部清白) |
| 下一站指令 | 落后基线 → `gw-sync`;就绪交付 → `gw-ship`;需重切 → 回本站 |

## 校验清单

- [ ] 每个提交是**原子**的:一个逻辑变更,可独立描述、回滚、过测试,无"顺手夹带"
- [ ] 每条信息符合 Conventional Commits:type 合法、subject 祈使句且 ≤50 字、必要时有 body 解释"为什么"
- [ ] 破坏性变更已用 `!` + `BREAKING CHANGE:` footer 双重标注
- [ ] **无密钥/凭据入库**;无调试残留、注释死代码、意外构建产物、冲突标记
- [ ] 关联工单已在 footer 标注(Closes/Refs)
- [ ] 信息风格(scope 命名、语言)与本仓库 `git log` 既有习惯一致
- [ ] 未对**已推送的共享分支**做 `amend`/`rebase`(那属 `gw-sync`/`gw-recover`)

## 回溯触发

- 暂存后发现一个提交里仍混着多件事 → `git reset HEAD <file>` 撤出,回流程第 2 步重拆。
- 扫描发现已暂存了密钥 → 撤出暂存,**若已 commit 但未推送** `git reset --soft HEAD~1` 重来;**若已推送**转 `gw-recover`(改写共享历史 + 轮换密钥)。
- 改动太大、无法拆出独立可测的原子提交 → 根因常是工作单元划太粗,回 `gw-route` 重新切分。
- 写不出清晰 subject(说不清这个提交在干嘛)→ 信号:这个提交职责不单一,回第 2 步重拆。

## 示例

```text
工作区：OrderService 加了导出功能，顺手修了个空指针，还改了若干格式

gw-commit：
1 看 diff → 归三类：导出功能 / 空指针修复 / 纯格式
2 分批暂存：
    git add -p src/order/service.ts     # 只选导出相关 hunk
    git commit -m "feat(order): 支持订单导出为 CSV" \
               -m "导出走流式写出，避免大单一次性载入内存。" \
               -m "Closes #128"
    git add -p src/order/service.ts     # 选空指针 hunk
    git commit -m "fix(order): 修复无收货地址时导出空指针"
    git add src/order/*.ts              # 余下纯格式
    git commit -m "style(order): 统一缩进与 import 顺序"
3 扫描：无密钥、无 console.log、无冲突标记 ✅
4 git log --oneline -3 复核 → 三条原子提交，各自可独立 revert
→ 下一站：gw-sync 对齐 origin/main 后 gw-ship
```
