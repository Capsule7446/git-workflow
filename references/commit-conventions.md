# Reference：提交信息规范（Conventional Commits）

> `git-workflow:gw-commit` 的信息标准。采用 [Conventional Commits 1.0.0](https://www.conventionalcommits.org/)——一套机器可解析、能自动生成 changelog 与推导 SemVer 的提交信息约定。

## 1. 结构

```
<type>(<scope>)<!>: <subject>
<空行>
<body>
<空行>
<footer>
```

- 第一行 = **header**(唯一必需);`scope`、`!`、`body`、`footer` 均可选。
- header ≤ 50 字符为宜;body/footer 每行 ≤ 72。

## 2. type（类型)

| type | 含义 | SemVer 影响 |
| :--- | :--- | :--- |
| `feat` | 新增功能 | minor |
| `fix` | 修复缺陷 | patch |
| `docs` | 仅文档 | — |
| `style` | 不影响语义的格式(空白、分号、缩进) | — |
| `refactor` | 重构(不改外部行为、非修复非功能) | — |
| `perf` | 性能优化 | patch |
| `test` | 增删测试 | — |
| `build` | 构建系统或依赖(npm、cargo、Docker) | — |
| `ci` | CI 配置与脚本 | — |
| `chore` | 杂务(不属以上,如改 .gitignore) | — |
| `revert` | 回退某次提交 | 视被回退项 |

> 任意 type 带 `BREAKING CHANGE` 即触发 **major**。

## 3. scope（范围,可选)

- 受影响的模块/子系统,放在 type 后括号内:`feat(checkout):`、`fix(auth):`。
- 用本仓库一致的词汇(看 `git log` 既有 scope);单仓多包(monorepo)常用包名。
- 影响面广或说不清就省略:`feat: ...`。

## 4. subject（主题)

- **祈使句、现在时**:"add" 而非 "added"/"adds";中文用"新增/修复"等动词开头。
- 不超过 50 字符;**结尾不加句号**;首字母不大写(英文)。
- 说清"做了什么",别写实现细节("修复登录 500" 而非 "改了 if 判断")。

## 5. body（正文,可选)

- 与 header 间空一行。解释**为什么**这么改、背景、权衡——而非复述 diff(diff 自己会说改了什么)。
- 可用要点列表;每行 ≤ 72 字符。

## 6. footer（脚注,可选)

- **破坏性变更**:`BREAKING CHANGE: <说明迁移方式>`(必须大写、顶格)。
- **关联工单**:
  - `Closes #128` / `Fixes #128`:合并即关闭该 issue。
  - `Refs #231`:仅关联,不关闭。
- **co-author**(可选):`Co-authored-by: Name <email>`。
  - 注:许多个人/团队全局关闭 AI 归属脚注;本规范不强制——按你的仓库约定决定加不加。

## 7. 破坏性变更（两种等价写法,推荐都用)

```
feat(api)!: 用 cursor 分页取代 offset 分页

BREAKING CHANGE: list 接口移除 page/size 参数,改用 cursor/limit。
旧客户端需改用新参数;迁移见 docs/pagination.md。
```

- header 的 `!`(在 scope 后、冒号前)给人快速信号;`BREAKING CHANGE:` footer 给机器(触发 major)。

## 8. 示例集

```
feat(order): 支持订单导出为 CSV

导出走流式写出,避免大单一次性载入内存。

Closes #128
```

```
fix(auth): 修复 session 为空时登录返回 500
```

```
refactor(checkout): 抽出 PriceCalculator,消除重复折扣逻辑
```

```
perf(search): 给 orders.created_at 加索引,列表查询 1.2s → 80ms
```

```
revert: feat(order): 支持订单导出为 CSV

This reverts commit a1b2c3d.
原因:导出大单仍 OOM,待流式方案完善后重做。
```

## 9. 原子提交（与信息同等重要)

规范的信息建立在**原子提交**上:一个提交 = 一个完整、独立、可单独回滚、可单独过测试的逻辑变更。

- 写不出单一清晰的 subject → 信号:这个提交职责不单一,该用 `git add -p` 拆开。
- "顺手"的格式整理、重构、依赖升级,各自独立成 `style`/`refactor`/`build` 提交,不夹进 `feat`/`fix`。
- 小步、频繁、原子地提交,胜过攒一大坨再拆。

## 10. 可选:用 commitlint 强制

把规范写成 CI/钩子,自动挡不合规的信息:

```js
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always',
      ['feat','fix','docs','style','refactor','perf','test','build','ci','chore','revert']],
    'subject-max-length': [2, 'always', 50],
  },
}
```

- 本地用 husky 的 `commit-msg` 钩子跑 `commitlint --edit "$1"`;CI 用 `commitlint --from <base> --to HEAD`。
- 配合 `semantic-release` / `changesets` 可由提交历史自动推导版本号与生成 changelog。
