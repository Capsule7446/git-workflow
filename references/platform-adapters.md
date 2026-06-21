# Reference：托管平台适配（PR / MR 怎么开)

> `git-workflow:gw-ship` 与 `gw-integrate` 的平台适配。核心 git 操作平台无关;只有"开 PR / 合并 PR"这步依赖托管平台。本表把同一意图映射到各平台的命令。检测顺序:有对应 CLI 且已登录就用它,否则退化到打印 compare 链接让用户手动开。

## 0. 平台检测

```bash
gh auth status     2>/dev/null   # GitHub CLI 是否可用且已登录
glab auth status   2>/dev/null   # GitLab CLI
# 都没有 → 用 git remote get-url origin 拼 compare 链接(见 §4)
```

## 1. GitHub（gh）

```bash
# 推送
git push -u origin <branch>

# 开 PR(base = 路由单指定的目标分支)
gh pr create --base <target> --head <branch> \
  --title "feat(checkout): 优惠券抵扣" \
  --body  "<What/Why + 要点 + 测试计划 + Closes #128>" \
  [--draft] [--reviewer alice,bob] [--label area:checkout] [--milestone v1.4]

# 查看 / 状态
gh pr view <num> --web
gh pr checks <num>            # CI 状态
gh pr status

# 合并(gw-integrate)
gh pr merge <num> --squash  --delete-branch
gh pr merge <num> --merge   --delete-branch
gh pr merge <num> --rebase  --delete-branch
```

## 2. GitLab（glab）

```bash
git push -u origin <branch>

# 开 MR
glab mr create --source-branch <branch> --target-branch <target> \
  --title "..." --description "..." [--draft] \
  [--assignee me] [--label area::checkout]

glab mr view <iid>
glab ci status

# 合并
glab mr merge <iid> --squash          # squash
glab mr merge <iid>                    # merge
glab mr merge <iid> --remove-source-branch
```

> 注:GitLab 标签用 `::` 作用域分隔(`area::checkout`);target-branch 用 `--target-branch`。

## 3. Bitbucket

- CLI 生态较弱;优先用网页或 REST API。
- Cloud REST(示意):
  ```bash
  curl -X POST -u "$USER:$APP_PW" \
    "https://api.bitbucket.org/2.0/repositories/<ws>/<repo>/pullrequests" \
    -H "Content-Type: application/json" \
    -d '{"title":"...","source":{"branch":{"name":"<branch>"}},
         "destination":{"branch":{"name":"<target>"}},"close_source_branch":true}'
  ```
- 多数情况:`git push` 后,Bitbucket 会在推送响应里打印一个"Create pull request"链接,直接打开即可。

## 4. 裸远端 / 无平台 CLI（退化路径)

没有任何托管 CLI 时,gw-ship 不假装能开 PR,而是:

```bash
git push -u origin <branch>
# 1) 多数平台在 push 输出里直接给出 "Create PR" 链接 → 打印给用户
# 2) 或据 remote 拼 compare 链接：
REMOTE=$(git remote get-url origin)
# github:  https://github.com/<owner>/<repo>/compare/<target>...<branch>
# gitlab:  https://gitlab.com/<owner>/<repo>/-/merge_requests/new?merge_request[source_branch]=<branch>&merge_request[target_branch]=<target>
```

- 纯团队内裸仓(无 web):则"交付"= 推送到约定分支 + 通知 reviewer;合并由维护者本地 `git merge --no-ff` 完成。

## 5. 跨平台不变量（gw-ship 始终遵守,与平台无关)

无论用哪种平台,这些不变:

- **PR 目标分支由路由单决定**:Trunk-Based→`main`;Epic 子需求→`epic/<name>`;Git Flow→`develop`。
- **正文承接提交历史**:What/Why + 改动要点 + 测试计划 + 关联工单 + 破坏性标注。
- **G3 门禁先过**:已同步基线、无冲突、本地检查绿或交代 CI、无密钥残留。
- **合并策略**(squash/merge/rebase)由本仓库统一约定,不随平台变(见 `branching-models.md` §7)。
- **合并后清理**:删源分支 + 回收 worktree(`gw-integrate` 负责)。
