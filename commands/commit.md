---
description: 把当前工作区改动整理成一串原子提交,每条配符合 Conventional Commits 的信息。按职责拆分暂存、扫描密钥/调试残留、写规范信息并提交。
argument-hint: [关注范围/说明] [--all 暂存全部] [--scope <模块>]
---

# /git-workflow:commit

你按 `git-workflow:gw-commit` Skill 帮用户把改动落成**原子提交 + Conventional Commits** 信息。一个提交 = 一个可独立描述、回滚、过测试的逻辑变更;信息规范让历史可读、可 bisect、可生成 changelog。

> 配套 skill:`git-workflow:gw-commit`;提交信息完整规范见 `${CLAUDE_PLUGIN_ROOT}/references/commit-conventions.md`。

## 参数

- `$ARGUMENTS`:可选,本次提交关注的范围或说明(如"只提交导出相关改动")。缺省则审视全部改动并按逻辑拆分。
- `--all`:把所有改动一次纳入考量(仍按逻辑拆成多个原子提交,不等于一个大提交)。
- `--scope`:指定 Conventional Commits 的 scope(如 `--scope checkout`),缺省按改动路径与本仓库习惯推断。

## 你要做的(按 gw-commit 流程)

1. **看清全部改动**:`git status` + `git diff`(未暂存)+ `git diff --cached`(已暂存)+ `git log --oneline -5` 对齐本仓库信息风格。
2. **按职责分批暂存**:整文件用 `git add`;一个文件混多件事用 `git add -p` 到 hunk 级。每批 = 一个原子单元。
3. **提交前扫描(门禁)**:密钥/凭据、调试残留(console.log/print/断点)、注释死代码、意外构建产物、合并冲突标记——命中先处理再提交。**密钥绝不入库**。
4. **为每个单元写信息**:`type(scope): subject`(祈使句 ≤50 字)+ 可选 body(解释为什么)+ footer(`BREAKING CHANGE:` / `Closes #128`)。破坏性变更用 `!` + footer 双标。
5. **提交并复核**:`git show --stat HEAD` 核对;未推送可 `--amend` 修正。
6. **报告**提交序列(hash + 信息首行),指明下一站(`gw-sync` 对齐基线 / `gw-ship` 交付)。

## 原则

- 宁可多个小而清晰的原子提交,不要一个夹带多事的大提交;写不出清晰 subject = 职责不单一,该拆。
- 信息解释**为什么**,而非复述 diff;沿用本仓库既有 scope/语言习惯。
- 绝不对**已推送的共享分支**做 amend/rebase(那属 `gw-sync`/`gw-recover`)。

## 示例

```
/git-workflow:commit                       # 审视全部改动，自动按逻辑拆原子提交
/git-workflow:commit 只提交导出相关         # 限定范围
/git-workflow:commit --scope order          # 指定 scope
```
