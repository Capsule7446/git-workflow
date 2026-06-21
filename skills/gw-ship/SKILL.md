---
name: gw-ship
description: "把已提交、已对齐基线的分支交付出去:推送到远端、向正确的目标分支开 Pull/Merge Request、写承接提交历史的 PR 标题与正文、自查 diff、关联工单、确认 CI 前置。平台无关(GitHub gh / GitLab glab / Bitbucket / 裸远端各有适配)。承载 G3 交付门禁。当分支就绪要开 PR、或 /ship 推进到交付阶段时触发。"
risk: caution
stage: ship
scope: remote
source: self
tags: "[git, ship, pull-request, review]"
---

# GW Ship(推送 + 开 PR / 交付)

把工作从「我本地完成」变成「可被 review、可被合并」。本工序触及远端、面向他人(`risk: caution`,外向操作),承载 **G3 交付门禁**:不满足"已同步基线 + 无冲突 + 自查通过 + CI 前置就绪 + PR 正文完整"不放行。**PR 目标分支由路由单决定**——Trunk-Based 是 `main`,Epic 子需求是 `epic/<name>`,别开错目标。

> 各托管平台的命令适配(GitHub `gh`、GitLab `glab`、Bitbucket、无平台的裸远端 compare-link)见 `${CLAUDE_PLUGIN_ROOT}/references/platform-adapters.md`。

## 使用时机

- 分支已有原子提交、已 `gw-sync` 对齐基线,准备让人 review/合并。
- `/git-workflow:ship` 推进到交付阶段(`workflow-deliver` 的 ship 站)。
- **被回溯触发**:G3 不通过(落后基线/有冲突/CI 红/正文残缺)时,退回对应站修好再回来。

## 输入要求

- **必需**:已提交且已对齐基线的分支;**PR 目标分支**(来自路由单);可访问的远端。
- **现场采集**:`git log origin/<base>..HEAD`(本 PR 含哪些提交)、`git diff origin/<base>...HEAD --stat`(改动面)、检测可用平台 CLI(`gh auth status` / `glab auth status`)。
- **可选**:PR 模板、reviewer/标签约定、关联 issue、是否走 draft。

## 流程

1. **G3 前置自查(门禁)**,任一不过则退回:
   - 已 `git fetch` 且分支**已同步基线、无冲突**(否则回 `gw-sync`)。
   - 提交是**原子的、信息规范**(否则回 `gw-commit`)。
   - **无密钥/调试残留**进入这批提交(复用 `gw-commit` 扫描)。
   - 本地能跑的检查(lint/test/build)**已绿**,或明确说明将由 CI 把关。
2. **推送分支**:`git push -u origin <branch>`(新分支带 `-u` 建立追踪)。rebase 过的私有分支按 `gw-sync` 规则用 `--force-with-lease`。
3. **生成 PR 标题与正文(承接提交历史)**:
   - **标题**:遵循 Conventional Commits 风格的概括(单提交可直接用该提交 subject;多提交用能涵盖全 PR 的一句)。
   - **正文**结构:
     - **What/Why**:这个 PR 做了什么、为什么(承接提交 body)。
     - **改动要点**:按模块列关键变更(从 `git log` 提炼)。
     - **测试计划**:怎么验证(已加的测试、手测步骤、TODO)。
     - **关联**:`Closes #128` / `Refs #231`。
     - 破坏性变更显式标注。
4. **开 PR(平台适配)**,**目标分支用路由单指定的**:
   - GitHub:`gh pr create --base <target> --head <branch> --title "..." --body "..."`(草稿加 `--draft`)。
   - GitLab:`glab mr create --target-branch <target> ...`。
   - 无平台 CLI:`git push` 后输出远端返回的 compare URL,或拼 `<remote-url>/compare/<target>...<branch>`,让用户手动开。
5. **挂元信息**:reviewer、labels、里程碑、关联 issue(按平台与团队约定)。范围大或想先收反馈 → 开 **draft**。
6. **报告**:PR 链接、目标分支、含哪些提交、CI 是否已触发、待办(指派 reviewer / 等 CI)。

## 输出

| 工件 | 内容 |
| :--- | :--- |
| PR | 链接、标题、目标分支、源分支、含的提交清单 |
| PR 正文 | What/Why + 改动要点 + 测试计划 + 关联工单(+ 破坏性标注) |
| 交付状态 | 是否 draft、CI 是否触发、reviewer/labels、后续待办 |

## 校验清单

- [ ] **G3:已同步基线、无冲突、提交规范、本地检查绿或交代由 CI 把关**
- [ ] **PR 目标分支正确**(Trunk-Based→main;Epic 子需求→epic 分支;Git Flow→develop)
- [ ] 无密钥/调试残留随提交流出
- [ ] PR 正文含 What/Why + 改动要点 + 测试计划 + 关联工单,承接提交历史
- [ ] 破坏性变更已在标题/正文显式标注
- [ ] 推送用了正确方式(新分支 `-u`;rebase 过的私有分支 `--force-with-lease`)
- [ ] 范围过大的 PR 已考虑拆分或转 draft

## 回溯触发

- 自查发现落后基线/有冲突 → 回 `gw-sync` 对齐再回来。
- 自查发现提交混杂/信息不达标/夹带密钥 → 回 `gw-commit`(密钥若已推送转 `gw-recover`)。
- PR diff 一看**范围过大、职责混杂**(reviewer 无从下手)→ 回 `gw-route` 重新切分工作单元,拆成多个小 PR 或用 Stacked PR。
- CI 红 → 修复后重新提交、`gw-sync`、再回本站(不靠反复重开 PR)。

## 示例

```text
分支 feature/checkout-coupon 已对齐 epic/checkout，3 个原子提交，准备交付

gw-ship：
1 G3 自查：已 rebase 到 epic/checkout、无冲突、本地 test 绿、无密钥 ✅
2 git push -u origin feature/checkout-coupon
3 PR 正文（承接提交）：
    标题: feat(checkout): 结算页支持优惠券抵扣
    What/Why: 在结算流程加入优惠券输入与抵扣计算，承接「结算改版」epic。
    要点: 新增 CouponField 组件 / 抵扣金额计算 / 无效券错误提示
    测试: 加了 coupon.spec 覆盖有效/过期/超额三种；手测见步骤
    关联: Refs #231（epic 结算改版）
4 gh pr create --base epic/checkout --head feature/checkout-coupon \
       --title "feat(checkout): 结算页支持优惠券抵扣" --body "<上文>"
   ← base 是 epic/checkout，不是 main
5 指派 reviewer + 打 label area:checkout
→ PR #244 已开，CI 已触发；待 review。epic 收口见 workflow-epic
```
