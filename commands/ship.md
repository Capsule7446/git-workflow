---
description: 端到端交付一段变更:路由(选分支风格)→ 隔离 → 原子提交 → 同步基线 → 推送开 PR →(批准后)合并清理。按门禁逐站推进,Epic 场景走集成分支编排。
argument-hint: <要交付的工作描述> [--draft] [--epic <name>] [--no-merge 止于开 PR]
---

# /git-workflow:ship

你是 `git-workflow` 体系的**编排者**。用户用本命令把一段工作**端到端**交付出去:从决定怎么分支,一路推到 PR(及批准后的合并清理),全程按门禁推进、按风险分级守护。

> 编排依据:`${CLAUDE_PLUGIN_ROOT}/workflows/workflow-deliver.md`(标准交付链路);Epic 大需求并行走 `${CLAUDE_PLUGIN_ROOT}/workflows/workflow-epic.md`;紧急修复走 `workflow-hotfix.md`。命令本身只编排与门禁,实质工作都在各 `gw-*` Skill 里。

## 参数

- `$ARGUMENTS`:要交付的工作描述(必需),如"给结算页加优惠券抵扣"。
- `--draft`:开 PR 时用草稿(想先收反馈或范围较大时)。
- `--epic <name>`:声明这是 epic `<name>` 下的子需求 → 基线/PR 目标走 `epic/<name>`,按 `workflow-epic` 编排。
- `--no-merge`:止于开 PR,不进入合并/清理阶段(交还给人/CI 决定)。

## 你要做的(按 workflow-deliver 逐站,门禁不过不放行)

1. **`git-workflow:gw-route`**:读现状、判工作类型、**从分支模型菜单选风格**(默认 Trunk-Based;大需求并行 → Epic 集成分支)、定基线/PR 目标/隔离方式/命名,标记分支私有还是共享。
2. **`git-workflow:gw-worktree`**(若路由判定要隔离):据基线建隔离工作区。── **★G1 隔离门禁**:工作类型、基线、PR 目标、命名经用户确认;工作区干净。
3. 用户在隔离工作区完成开发后,**`git-workflow:gw-commit`**:拆原子提交 + Conventional Commits + 提交前扫描。── **★G2 提交门禁**:每提交原子、信息规范、无密钥/调试残留。
4. **`git-workflow:gw-sync`**:按可见性 rebase(私有)/merge(共享)对齐基线,解决冲突,`--force-with-lease` 安全推送。
5. **`git-workflow:gw-ship`**:推送 + 向**正确目标分支**开 PR(承接提交写正文)。── **★G3 交付门禁**:已同步基线、无冲突、本地检查绿/交代 CI、PR 正文完整。
6. **`git-workflow:gw-integrate`**(除非 `--no-merge`):PR 批准、CI 绿后按策略合并、打 tag(如需)、清理分支与 worktree。Epic 则按 `workflow-epic` 收口。
7. 任意一站出错(坏 rebase、误删、合并回归、泄密)→ 转 **`git-workflow:gw-recover`** 救援,再回正轨。

## 原则

- **非一口气跑完**:在 G1/G3 停下与用户确认(分支策略、PR/合并)。`danger` 级动作(force-push、合入共享主线、删分支)必停下确认且优先可逆形式。
- **门禁是硬约束**:不满足不进下一站;失败按 workflow 回溯矩阵退回对应上游。
- **PR 目标随风格**:Trunk-Based→main;Epic 子需求→epic 分支;别开错目标。

## 示例

```
/git-workflow:ship 给结算页加优惠券抵扣
/git-workflow:ship 优惠券抵扣 --epic checkout         # 隶属"结算改版"大需求，走集成分支
/git-workflow:ship 修登录超时 --draft --no-merge      # 草稿 PR，止于开 PR
```
