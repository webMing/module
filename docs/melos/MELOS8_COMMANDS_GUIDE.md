# Melos 8 使用手册（结合本项目）

> **环境基线**
> - Melos：**8.7.0**（`pubspec.lock` 中为 `direct dev`，源码核对自 `~/.pub-cache/hosted/pub.dev/melos-8.7.0`）
> - Flutter：**3.47.4**｜Dart：**3.13.3**
> - 工作区：根包 `module`（Flutter 应用）+ `packages/home` + `packages/login`
> - 配置文件：**根 `pubspec.yaml` 的 `melos:` 段**（Melos 8 不使用独立的 `melos.yaml`）
>
> 本文所有命令与参数均对照 Melos 8.7.0 源码中的 `ArgParser` 定义核实；「本项目」小节均为实测配置。

---

## 1. Melos 是什么，解决什么问题

Melos 是一个 **Dart/Flutter 多包仓库（monorepo）的任务编排与版本发布工具**。

| 对比项 | 原生 `dart pub` | Melos |
| --- | --- | --- |
| 依赖解析 | ✅ 一次解析整个 workspace | 调用 pub 完成（不自建解析） |
| 对 N 个包批量执行命令 | ❌ 需自己写循环 | ✅ `analyze` / `test` / `format` / `exec` |
| 按条件筛选包 | ❌ | ✅ `--scope` `--diff` `--depends-on` `--dir-exists` … |
| 并发与失败策略 | ❌ | ✅ `--concurrency` `--fail-fast` `--group-logs` |
| 固化团队脚本 | ❌ | ✅ `melos.scripts` |
| 版本号 / CHANGELOG / Git tag / 发布 | ❌ | ✅ `version` / `publish` |
| IDE 运行配置生成 | ❌ | ✅ `bootstrap`（IntelliJ 等） |

**核心结论：Melos 不取代 pub，而是叠加在 Pub Workspace 之上。**
解析层由 pub 负责（唯一 `pubspec.lock` + 唯一 `package_config.json`），
Melos 负责「编排、筛选、发布」。这也是 Melos 8 不再自己管理包路径的根本原因。

---

## 2. Melos 8 与 Melos 7 的关键差异

1. **不再读取 `melos.yaml` 中的包目录配置**。工作区成员完全来自根 `pubspec.yaml` 的 `workspace:`
   （Melos 8.7.0 源码中若根目录没有 `pubspec.yaml` 会直接报错）。
   → 这就是旧项目执行 `melos list` 得到 `No packages were found with the current filters.` 的原因。
2. **每个成员包必须有 `resolution: workspace`**。
3. **脚本配置写在根 `pubspec.yaml` 的 `melos.scripts`** 下。
4. **自定义脚本优先注册**：Melos 先注册脚本、再注册内置命令，
   **同名脚本会遮蔽内置命令**（例如自定义 `analyze` 会让 `melos analyze` 指向你的脚本）。
   因此脚本名应避开 `bootstrap` / `analyze` / `test` / `format` / `clean` / `run` / `list` /
   `exec` / `version` / `publish` / `init` / `changed`。
5. **`run` 与 `exec` 互斥**：同一个脚本不能同时定义 `run:` 和 `exec:`
   （源码会给出迁移提示信息并拒绝）。
6. **命令级配置**可写在 `melos.commands.<内置命令名>`（`bootstrap`、`clean`、`format`、`version`、`publish`），
   以及用 `melos.commands.<name>.hooks.pre/post` 定义生命周期钩子。

---

## 3. 初始化

### 3.1 前置条件

| 条件 | 本项目状态 |
| --- | --- |
| Flutter/Dart SDK 的 `bin` 在 `PATH` | ⚠️ 当前 shell 中 `flutter`/`dart` 不在 `PATH`，需先配置 |
| Melos 作为根包 dev 依赖（推荐，无需全局安装） | ✅ `melos: ^8.7.0` |
| 根 `pubspec.yaml` 有 `workspace:` | ✅ `packages/home`、`packages/login` |
| 成员包有 `resolution: workspace` | ✅ 两个成员均有 |

### 3.2 全新仓库的初始化

```bash
# 方式一：用 melos 自带的交互式初始化（生成 melos 配置骨架）
dart run melos init

# 方式二：手工在根 pubspec.yaml 添加 melos 段（本项目采用）
```

### 3.3 已有仓库的初始化（含迁移，本项目场景）

```bash
# 1) 确认根 pubspec.yaml 已声明 workspace 成员，成员包已写 resolution: workspace
# 2) 添加 melos 到 dev_dependencies（已存在）
# 3) 解析依赖（Pub Workspace 只此一次）
dart pub get

# 4) 初始化 Melos 工作区：生成 IDE 配置等
dart run melos bootstrap

# 5) 验证 Melos 能识别全部包
dart run melos list --long
```

期望识别出 **3 个包**：`module`、`home`、`login`
（`module` 能被识别依赖 `useRootAsPackage: true`）。

> 💡 **推荐统一用 `dart run melos ...`**，而不是依赖全局安装的 `melos`。
> 好处：版本随项目锁定，团队成员与 CI 行为一致。

### 3.4 SDK 路径解析优先级

当 `flutter`/`dart` 不在 `PATH` 时（正是本机现状），Melos 提供了三种指定 SDK 的方式，
**优先级从高到低**：

```
--sdk-path（命令行）  >  melos.sdkPath（pubspec.yaml）  >  MELOS_SDK_PATH（环境变量）
```

特例：传入 `--sdk-path auto` 表示强制使用系统 PATH 中的 SDK。例如：

```bash
dart run melos --sdk-path /path/to/flutter/bin/dart analyze
MELOS_SDK_PATH=/path/to/flutter dart run melos analyze
```

注意两层区别（本机当前正是这种情况）：

- `dart run melos ...` 本身要求**能调用 `dart`**。若 `dart` 完全不在 `PATH`，
  连 Melos 都启动不了，此时须用绝对路径启动，例如
  `/path/to/flutter/bin/dart run melos list --long`。
- 只要能启动 Melos，它再去调用 `flutter`/`dart` 子进程时若找不到，
  才用 `--sdk-path` / `melos.sdkPath` / `MELOS_SDK_PATH` 指路。

---

## 4. Melos 8 包含哪些功能

```
┌─ 工作区识别 ──── 从根 pubspec.yaml 的 workspace: 读取全部成员（受 useRootAsPackage 影响）
├─ 依赖引导 ────── bootstrap：解析依赖、生成 IDE 配置、可统一约束/注入公共依赖
├─ 批量执行 ────── analyze / test / format / exec（并发 + 失败策略 + 日志分组）
├─ 包筛选 ──────── scope / ignore / category / dir-exists / file-exists /
│                  depends-on / diff / private / published / include-*
├─ 脚本系统 ────── melos.scripts：run（根目录单次）/ exec（每包一次）/ steps / env /
│                  packageFilters / stdio / 参数透传
├─ 生命周期钩子 ── commands.<cmd>.hooks.pre|post；version/publish 亦支持
├─ 可视化 ──────── list --json / --graph / --gviz / --mermaid / --cycles
├─ 变更检测 ────── changed [ref]：列出相对 Git 引用发生变化的包
├─ 版本与发布 ──── version（版本号、CHANGELOG、Git tag）/ publish
└─ 清理 ────────── clean：清理 Melos 生成的临时 Pub 与 IDE 文件
```

---

## 5. 常用命令速查

### 5.1 内置命令总览

| 命令 | 作用 | 典型用法 |
| --- | --- | --- |
| `init` | 生成 Melos 配置骨架 | `dart run melos init` |
| `bootstrap` | 依赖引导 + IDE 配置生成 | `dart run melos bootstrap` |
| `list` | 列出工作区包 | `dart run melos list --long` |
| `analyze` | 对所有包静态分析 | `dart run melos analyze` |
| `test` | 对所有包跑测试 | `dart run melos test` |
| `format` | 对所有包格式化 | `dart run melos format --set-exit-if-changed` |
| `exec` | 在每个匹配包中执行任意命令 | `dart run melos exec -- flutter test` |
| `run` | 执行 `melos.scripts` 里定义的脚本 | `dart run melos run check` |
| `changed` | 列出相对某次提交/标签变化的包 | `dart run melos changed` |
| `version` | 版本号提升 + CHANGELOG + Git tag | `dart run melos version --yes` |
| `publish` | 发布包到 pub.dev | `dart run melos publish --dry-run` |
| `clean` | 清理临时文件 | `dart run melos clean` |

### 5.2 全局选项（所有命令通用）

| 选项 | 作用 |
| --- | --- |
| `--verbose` / `-v` | 输出详细日志 |
| `--sdk-path <path>` | 指定 Dart/Flutter SDK，`auto` 表示使用系统 SDK |
| `--version` | 打印 Melos 版本（CI 环境下会跳过更新检查） |
| `--help` / `-h` | 任意命令后追加可查看该命令参数 |

### 5.3 命令专属参数（源码核实）

| 命令 | 参数 |
| --- | --- |
| `bootstrap` | `--no-example`（跳过 example 目录）、`--enforce-lockfile`、`--offline` |
| `list` | `-l/--long`、`-p/--parsable`、`-r/--relative`、`--json`、`--graph`、`--gviz`、`--mermaid`、`--cycles` |
| `analyze` | `-c/--concurrency`（默认 **1**）、`--fatal-infos`（**默认开启**）、`--fatal-warnings` |
| `test` | `-c/--concurrency`（默认 1） |
| `format` | `-c/--concurrency`（默认 1）、`--set-exit-if-changed`、`-o/--output <json\|none\|show\|write>`、`--line-length` |
| `exec` | `-c/--concurrency`（默认 **CPU 核数**）、`-f/--fail-fast`、`--group-logs`、`-o/--order-dependents` |
| `run` | `--list`（列出全部脚本）、`--json`、`--no-select`、`--include-private`、`-g/--group` |
| `changed` | `melos changed [ref]`（位置参数，省略则用各包最新 release tag） |
| `version` | `-p/--prerelease`、`-g/--graduate`、`-c/--changelog`、`-d/--dependent-constraints`、`-D/--dependent-versions`、`--smart-dependents`、`-t/--git-tag-version`、`-C/--git-commit-version`、`-r/--release-url`、`--group-commits`、`-m/--message`、`--yes`、`--all` |
| `publish` | `-n/--dry-run`、`-t/--git-tag-version`、`-y/--yes`、`--server`、`--skip-validation` |

### 5.4 包筛选选项（可组合，适用于 `analyze`/`test`/`format`/`exec`/`list` 等）

| 选项 | 含义 |
| --- | --- |
| `--scope <glob>` | 按包名匹配（可多次、支持通配符） |
| `--ignore <glob>` | 排除包 |
| `--category <name>` | 按 `melos.categories` 定义的分类筛选 |
| `--dir-exists <dir>` | 仅包含存在该目录的包（如 `test`） |
| `--file-exists <file>` | 仅包含存在该文件的包 |
| `--depends-on <pkg>` | 仅包含依赖指定包的包 |
| `--no-depends-on <pkg>` | 排除依赖指定包的包 |
| `--diff <ref>` | 仅包含相对 `<ref>` 有改动的包（`changed` 命令中改为位置参数） |
| `--include-dependencies` | 结果中补齐被选包的本地依赖 |
| `--include-dependents` | 结果中补齐依赖被选包的下游包 |
| `--[no-]private` | 是否包含私有包 |
| `--[no-]published` | 按是否已发布筛选 |
| `--flutter` / `--no-flutter` | 仅包含 / 排除 Flutter 包 |

> ⚠️ 与 Pub Workspace 的分工：`--diff` 这类筛选是 **Melos 的能力**，pub 原生没有。

---

## 6. 脚本系统（`melos.scripts`）

### 6.1 单次执行 vs 每包执行

```yaml
melos:
  scripts:
    # 形态 A：在根目录执行一次
    check:
      description: Analyze and test the whole workspace.
      run: dart run melos analyze && dart run melos test

    # 形态 B：在每个匹配包目录中执行（run 与 exec 互斥）
    test:packages:
      description: Run tests only where a test/ dir exists.
      exec:
        command: flutter test
        concurrency: 4
        failFast: true
        groupLogs: true
      packageFilters:
        dirExists: test
        flutter: true
```

- `run:` 与 `exec:` **不能同时出现**。
- `exec` 的 `packageFilters` 支持与命令行筛选相同的字段（YAML 中为 camelCase，如 `dirExists`、`dependsOn`）。

### 6.2 脚本支持的字段

| 字段 | 作用 |
| --- | --- |
| `description` | 脚本说明，`melos run --list` 中显示 |
| `run` | 单次执行的命令（根目录） |
| `exec.command` | 每个包执行的命令 |
| `exec.concurrency` / `failFast` / `orderDependents` / `groupLogs` | 并发与失败策略 |
| `steps` | 顺序执行的多个步骤（与 `run` 二选一） |
| `env` | 注入环境变量 |
| `packageFilters` | 限定脚本作用的包 |
| `stdio` | 进程 stdio 模式；`inherit` 用于需要交互终端的命令（如 `flutter run`），CI 保持默认 `pipe` |
| `private` | 私有脚本，默认不出现在列表、不可执行（需 `--include-private`） |
| `group` | 脚本分组，可用 `melos run -g <group>` 过滤 |

### 6.3 查看与传参

```bash
# 查看所有脚本及其说明
dart run melos run --list

# 以 JSON 输出（便于工具消费）
dart run melos run --json

# 向脚本透传参数：`--` 之后的参数会追加到命令末尾
dart run melos run build -- --release

# 按分组筛选脚本
dart run melos run -g codegen
```

### 6.4 脚本命令示例合集

```yaml
melos:
  scripts:
    # 依赖解析
    get:
      description: Resolve all Pub Workspace dependencies.
      run: dart pub get

    # 质量门禁
    check:
      description: Analyze and test the app and every local package.
      run: dart run melos analyze && dart run melos test

    # 格式检查 / 自动格式化
    format:check:
      description: Check Dart formatting without changing files.
      run: dart run melos format --set-exit-if-changed
    format:fix:
      description: Format all Dart source files.
      run: dart run melos format --output write

    # 代码生成（仅含 build_runner 的包，按依赖顺序串行）
    generate:
      description: Generate Dart sources where build_runner is used.
      exec:
        command: dart run build_runner build --delete-conflicting-outputs
        concurrency: 1
        failFast: true
        orderDependents: true
      packageFilters:
        dependsOn: build_runner

    # 只在有 test/ 的包跑测试
    test:packages:
      description: Run tests only in packages with a test directory.
      exec:
        command: flutter test
        concurrency: 4
        failFast: true
        groupLogs: true
      packageFilters:
        dirExists: test

    # 只检查改动过的包（PR 快速门禁）
    check:changed:
      description: Analyze and test packages changed vs origin/main.
      run: >-
        dart run melos format --set-exit-if-changed --diff origin/main &&
        dart run melos analyze --diff origin/main --include-dependents &&
        dart run melos test --diff origin/main --include-dependents
```

---

## 7. 生命周期钩子

内置命令支持 `pre` / `post` 钩子，用于在命令前后自动执行动作：

```yaml
melos:
  command:
    bootstrap:
      hooks:
        pre: echo "before bootstrap"
        post: echo "after bootstrap"
    version:
      hooks:
        pre: dart format .
```

> 配置位置为 `melos.commands.<命令名>.hooks`；`version` 与 `publish` 也有各自的生命周期钩子。

---

## 8. 版本管理与发布

### 8.1 典型发布流程

```bash
# 1) 干跑：看看会如何提升版本、生成什么 CHANGELOG（不写文件）
dart run melos version --dry-run

# 2) 实际提升版本：自动改版本号、生成/更新 CHANGELOG、打 Git tag、提交
dart run melos version --yes

# 3) 发布前干跑
dart run melos publish --dry-run

# 4) 正式发布（受保护分支 + 明确策略下执行）
dart run melos publish
```

### 8.2 常用参数语义

| 参数 | 用途 |
| --- | --- |
| `--prerelease` | 提升为预发布版本（如 `1.0.0-dev.1`） |
| `--graduate` | 把预发布转为正式版本 |
| `--changelog` | 更新 CHANGELOG |
| `--dependent-constraints` | 同步更新依赖方的版本约束 |
| `--smart-dependents` | 仅更新确实需要联动的依赖方 |
| `--git-tag-version` | 为版本打 Git tag |
| `--git-commit-version` | 提交版本变更 |
| `--yes` | 跳过交互确认（CI 用） |
| `--group-commits` | 按类型分组提交信息 |

> ⚠️ 发布动作涉及 Git 标签、CHANGELOG、发布凭据，**不要在没有明确发布策略时执行**；
> 本项目两个子包为 `version: 0.0.1` 的私有包（`publish_to: none`），暂不适用发布流程。
> 执行前建议先 `dart run melos version --help` 查看当前版本支持的全部参数。

---

## 9. 结合本项目

### 9.1 项目现状

根 `pubspec.yaml` 中的 Melos 配置（**当前实际内容**）：

```yaml
melos:
  useRootAsPackage: true          # 根目录 module 也是包，纳入 Melos 管理
  scripts:
    get:
      description: Resolve all Pub Workspace dependencies.
      run: dart pub get
    check:
      description: Analyze and test the app and every local package.
      run: dart run melos analyze && dart run melos test
    format:check:
      description: Check Dart formatting without changing files.
      run: dart run melos format --set-exit-if-changed
    format:fix:
      description: Format all Dart source files.
      run: dart run melos format --output write
```

对应的包结构：

| 包名 | 路径 | 类型 | 是否有 test |
| --- | --- | --- | --- |
| `module` | `./` | Flutter 应用（根包） | ✅ `test/widget_test.dart` |
| `home` | `packages/home` | Flutter 包 | ✅ `test/home_test.dart` |
| `login` | `packages/login` | Flutter 包 | ✅ `test/login_test.dart` |

### 9.2 本项目的日常命令

```bash
# 首次克隆后的第一条命令
dart run melos bootstrap

# 依赖解析（修改任一 pubspec.yaml 后执行）
dart run melos run get

# 静态分析 + 测试（等价于 melos analyze && melos test）
dart run melos run check

# 仅检查格式 / 自动格式化
dart run melos run format:check
dart run melos run format:fix

# 查看识别到的包
dart run melos list --long

# 列出可用脚本
dart run melos run --list
```

若本机 `flutter`/`dart` 不在 `PATH`（本项目当前 shell 即如此）：

```bash
dart run melos --sdk-path <你的 Flutter 路径> run check
# 或
export MELOS_SDK_PATH=<你的 Flutter 路径>
```

### 9.3 本机实测记录

| 命令 | 结果 |
| --- | --- |
| `dart run melos list --long` | 识别出 `module`、`home`、`login` 共 3 个包 |
| `dart run melos bootstrap` | 成功，生成 IntelliJ 工作区文件 |
| `dart run melos run format:check` | 通过 |
| `dart run melos analyze` | 3 个包无静态分析问题 |
| `dart run melos test` | 3 个包的测试通过 |

> 上述记录来自 `docs/melos-workspace-migration/README.md` 的迁移验证环节；
> 本文其余命令与参数对照 Melos 8.7.0 源码核实。本次分析环境中 `flutter`/`dart`
> 不在 `PATH`，因此未重新执行上述命令。

### 9.4 针对本项目的可补强项

当前 4 个脚本已覆盖「解析 + 分析 + 测试 + 格式化」。以下脚本本项目**尚未添加**，
按需取用（注意脚本名不要与内置命令重名）：

| 建议脚本 | 用途 | 适用时机 |
| --- | --- | --- |
| `test:packages` | 只在含 `test/` 的包跑测试（`dirExists: test`） | 包数量增多后 |
| `analyze:changed` | 仅分析相对 `origin/main` 改动的包及其下游 | PR 快速门禁 |
| `generate` | 对含 `build_runner` 的包生成代码 | 引入 `build_runner` 后（当前项目已装 freezed/json_serializable 但**未装 build_runner**） |
| `verify` | `format:check` + `analyze` + `test` 一条命令 | CI 入口 |
| `publish:dry` | 发布前干跑校验 | 需要发布时 |

示例（追加到现有 `melos.scripts` 即可）：

```yaml
    verify:
      description: Format check, analyze and test everything.
      run: >-
        dart run melos format --set-exit-if-changed &&
        dart run melos analyze &&
        dart run melos test
    analyze:changed:
      description: Analyze only packages changed vs origin/main and their dependents.
      run: dart run melos analyze --diff origin/main --include-dependents
    test:packages:
      description: Run tests only in packages that contain a test directory.
      exec:
        command: flutter test
        concurrency: 4
        failFast: true
        groupLogs: true
      packageFilters:
        dirExists: test
```

---

## 10. 与 Pub Workspace 的分工（本项目同时使用两者）

| 层 | 负责方 | 具体职责 | 本项目体现 |
| --- | --- | --- | --- |
| 依赖解析 | **Pub Workspace**（pub 原生） | 唯一 `pubspec.lock`、唯一 `.dart_tool/package_config.json`、本地包互相解析、IDE 单分析上下文 | ✅ 已生效 |
| 任务编排 | **Melos 8** | 批量 analyze/test/format、包筛选、脚本、版本发布 | ✅ 已配置 4 个脚本 |

三条实践边界：

1. **不要**用 Melos 脚本重复实现 pub 的职责（如逐包 `pub get`）；解析只在根做一次。
2. **不要**在子包内单独 `pub get`，那会生成遮蔽根配置的 `package_config.json`。
3. Melos 的 `bootstrap` 会调用 pub 完成解析，所以「改了 `pubspec.yaml` → 再跑一次 bootstrap 或 `melos run get`」是标准动作。

更完整的 Pub Workspace 原理见同仓库 `docs/pub-workspace/PUB_WORKSPACE_GUIDE.md`。

---

## 11. CI 建议

```bash
# 推荐流程：一次解析 + 一次质量门禁
dart pub get
dart run melos bootstrap
dart run melos format --set-exit-if-changed
dart run melos analyze
dart run melos test
```

PR 增量检查（利用 Melos 的 `--diff` / `--include-dependents`）：

```bash
dart run melos format  --set-exit-if-changed --diff origin/main
dart run melos analyze --diff origin/main --include-dependents
dart run melos test    --diff origin/main --include-dependents
```

CI 注意事项：

- 使用 `dart run melos`（版本由项目锁定），不要依赖全局安装的 Melos。
- `analyze` 默认并发为 1 且 `--fatal-infos` 默认开启；如需更快可显式 `-c 4`，
  如需放宽 info 级别可加 `--no-fatal-infos`（但不建议在门禁中放宽）。
- 缓存以根 `pubspec.lock` 为 key；确保子包目录下无锁文件。

---

## 12. 故障排查

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `melos: command not found` | 未全局安装 Melos | 改用 `dart run melos ...`（推荐），或配置 SDK 的 `bin` 到 `PATH` |
| `No packages were found with the current filters.` | 仍在用 Melos 7 的 `melos.yaml` 包路径配置，或成员缺 `resolution: workspace` | 改为根 `pubspec.yaml` 的 `workspace:`；补齐成员的 `resolution: workspace`；重新 `dart pub get` |
| 识别不到根包 `module` | 未开启 `useRootAsPackage` | 在 `melos:` 下设置 `useRootAsPackage: true` |
| 脚本执行后不断输出自身名称 / 递归 | 脚本名与内置命令同名，遮蔽了内置命令并递归调用 | 改名（如 `check`、`format:check`、`verify`） |
| `Found no pubspec.yaml file in "<root>"` | Melos 8 要求根目录有 `pubspec.yaml` | 确认在仓库根执行，且根 `pubspec.yaml` 存在 |
| 根目录没有 `pubspec.yaml` 但想用 Melos | 不支持 | Melos 8 以 Pub Workspace 为前提，先建立根 pubspec |
| 脚本里同时写了 `run` 和 `exec` | 二者互斥 | 只保留一种；需要多步用 `steps` |
| 找不到 `flutter` / `dart` | SDK 不在 `PATH` | `--sdk-path <path>`、`melos.sdkPath` 或 `MELOS_SDK_PATH` |
| `--diff` 报错找不到 ref | 本地无该远程引用 | 先 `git fetch origin`，CI 中确保完整历史（`fetch-depth: 0`） |
| 命令需要交互但无输出 | stdio 为默认 `pipe` | 脚本中设置 `stdio: inherit` |
| 版本/发布命令改了不该改的文件 | 未干跑 | 先 `melos version --dry-run`、`melos publish --dry-run` |

---

## 13. 最佳实践清单

1. **统一入口**：团队与 CI 都用 `dart run melos ...`，不依赖全局安装。
2. **脚本覆盖日常动作**：解析、格式化、分析、测试、生成、发布干跑各有一条命令。
3. **避开内置命令名**，防止遮蔽与递归。
4. **根目录只做工作区声明 + 统一工具配置**，业务代码进子包。
5. **解析交给 pub**：只在根 `pub get`；Melos 只做编排。
6. **共享包改动时用 `--include-dependents`**，确保下游回归。
7. **PR 用 `--diff origin/main` 缩小范围**，主分支保持全量门禁。
8. **发布类命令先 `--dry-run`**，正式执行需在受保护分支与明确策略下进行。
9. **`bootstrap` 与 `pub get` 的时机**：任何 `pubspec.yaml` 变更后重跑一次。
10. **脚本保持幂等**：CI 中重复执行不应产生副作用（`format:check` 而非 `format:fix`）。

---

## 14. 参考资料

- Melos 官方仓库：<https://github.com/invertase/melos>
- Melos 官方文档：<https://melos.invertase.dev>
- 本仓库 `docs/melos-workspace-migration/README.md`：Melos 8 迁移记录与验证
- 本仓库 `docs/melos-workspace-migration/MELOS_USAGE_GUIDE.md`：Melos 基础与高级实践
- 本仓库 `docs/pub-workspace/PUB_WORKSPACE_GUIDE.md`：Pub Workspace 原理（解析层）
- Melos 8.7.0 源码（本地依据）：`~/.pub-cache/hosted/pub.dev/melos-8.7.0/lib/src/command_runner/*.dart`
