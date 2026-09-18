# Melos 使用指南：基础与高级实践

本文以 **Melos 8** 为准。Melos 8 基于 Dart 的 **Pub Workspace** 管理多包
仓库；它不再使用旧版的 `melos.yaml` 文件。

## 1. Melos 解决什么问题

当一个仓库同时包含多个 Flutter/Dart 包、应用或共享组件时，Melos 用于：

- 统一解析依赖并让本地包互相引用。
- 一次执行所有包的分析、测试、格式化或代码生成。
- 按包名、改动范围、依赖关系筛选目标包。
- 为团队提供一致的快捷脚本，以及用于版本发布和变更日志的工作流。

当前项目包含根 Flutter 应用 `module` 和两个本地包：`home`、`login`。

## 2. 前置条件

1. 使用 Dart 3.6 或更高版本；Pub Workspace 依赖该版本能力。
2. Flutter SDK 的 `bin` 目录必须位于 `PATH`，以便找到 `flutter` 和 `dart`。
3. 根 `pubspec.yaml` 的 `dev_dependencies` 中包含 Melos：

   ```yaml
   dev_dependencies:
     melos: ^8.7.0
   ```

建议通过项目本地依赖运行，而不是要求每个开发者全局安装 Melos：

```bash
dart run melos --help
```

## 3. Melos 8 的工作区结构

一个最小工作区如下：

```text
my_workspace/
├── pubspec.yaml
├── packages/
│   ├── feature_a/pubspec.yaml
│   └── feature_b/pubspec.yaml
└── apps/                       # 可选：多个应用时可使用
    └── demo/pubspec.yaml
```

### 3.1 根 `pubspec.yaml`

根包列出所有成员包。`workspace` 当前需要写明路径，不能依赖通配符：

```yaml
name: my_workspace
publish_to: none

environment:
  sdk: ^3.6.0

workspace:
  - packages/feature_a
  - packages/feature_b
  - apps/demo

dev_dependencies:
  melos: ^8.7.0

melos:
  # 根目录本身也是 Flutter/Dart 包时设为 true。
  useRootAsPackage: true
```

`useRootAsPackage` 适合根目录就是应用的仓库。若根目录只用于聚合配置，
而所有应用都放在子目录中，则通常不需要该项。

### 3.2 子包 `pubspec.yaml`

每个工作区成员都必须写入 `resolution: workspace`：

```yaml
name: feature_a
publish_to: none

environment:
  sdk: ^3.6.0

resolution: workspace

dependencies:
  flutter:
    sdk: flutter
```

本地包之间按普通依赖方式声明即可；Pub Workspace 会在解析时使用仓库中的本地包：

```yaml
dependencies:
  feature_a: ^1.0.0
```

不要为此手工添加 `dependency_overrides`，也不要在子包中保留独立
`pubspec.lock`。工作区使用根目录的 lockfile。

## 4. 初始化与日常基础命令

以下命令均在工作区根目录执行。

| 目标 | 命令 | 说明 |
| --- | --- | --- |
| 查看包 | `dart run melos list --long` | 显示包名、版本、路径和私有状态。 |
| 初始化 | `dart run melos bootstrap` | 解析依赖、初始化工作区，并生成支持的 IDE 配置。 |
| 分析 | `dart run melos analyze` | 对工作区所有包执行静态分析。 |
| 测试 | `dart run melos test` | 对含 `test/` 目录的包执行测试。 |
| 格式检查 | `dart run melos format --set-exit-if-changed` | 检查格式；有未格式化文件时退出失败。 |
| 自动格式化 | `dart run melos format --output write` | 写入格式化结果。 |
| 清理 | `dart run melos clean` | 清理 Melos 生成的临时 Pub 与 IDE 文件。 |

通常，新成员克隆仓库后的第一条命令是：

```bash
dart run melos bootstrap
```

当修改根或任何子包的 `pubspec.yaml` 后，再执行一次 bootstrap。仅需更新
工作区依赖时，也可以执行根目录的 `dart pub get`。

## 5. 当前项目已提供的快捷脚本

本项目将脚本写在根 `pubspec.yaml` 的 `melos.scripts` 中：

```bash
# 解析 Pub Workspace 依赖
dart run melos run get

# 静态分析加测试
dart run melos run check

# 检查格式，不修改文件
dart run melos run format:check

# 写入格式化结果
dart run melos run format:fix
```

列出所有可用脚本：

```bash
dart run melos run --list
```

注意：不要将脚本命名为 `bootstrap`、`analyze`、`test`、`format` 等 Melos
内置命令名。相同名称会遮蔽内置命令，并可能形成递归调用。

## 6. `melos exec`：在多个包中执行命令

`exec` 会在每个匹配包的目录中运行命令。`--` 后面的内容是实际执行的命令：

```bash
# 在所有 Flutter 包运行代码生成
dart run melos exec --flutter -- dart run build_runner build --delete-conflicting-outputs

# 在所有包运行依赖获取
dart run melos exec -- dart pub get

# 并行检查格式，失败时立即停止后续包
dart run melos exec --concurrency 4 --fail-fast -- dart format . --set-exit-if-changed
```

常用执行控制项：

| 参数 | 作用 |
| --- | --- |
| `--concurrency N` | 最多同时运行 N 个包；`exec` 默认是 8。 |
| `--fail-fast` | 某包失败后不再启动其余包。 |
| `--group-logs` | 并行时按包汇总输出，避免日志交错。 |
| `--order-dependents` | 按依赖图从叶子包开始执行，适合多包代码生成。 |

对于 Pub Workspace，依赖解析优先使用根目录的 `dart pub get` 或
`melos bootstrap`；不要把“每个包各自 `pub get`”当作常规初始化方案。

## 7. 包筛选

大仓库无需每次操作所有包。以下筛选项可用于 `list`、`exec`、`analyze`、
`test`、`format` 等命令。

```bash
# 只操作名称匹配 feature_* 的包
dart run melos test --scope 'feature_*'

# 只操作 Flutter 包
dart run melos analyze --flutter

# 排除一个包
dart run melos test --ignore example_app

# 仅测试含 test 目录的包
dart run melos exec --dir-exists test -- flutter test

# 仅操作依赖 shared_ui 的包
dart run melos analyze --depends-on shared_ui

# 操作某个包及所有依赖它的包
dart run melos test --scope shared_ui --include-dependents

# 只检查相对 main 分支发生改动的包
dart run melos analyze --diff main
```

筛选项可以组合。`--include-dependencies` 用于补齐被选包依赖的本地包，
`--include-dependents` 用于补齐依赖该包的下游包；后者特别适合共享库改动后的
回归测试。

## 8. 将重复命令固化为脚本

Melos 8 的脚本放在根 `pubspec.yaml` 的 `melos.scripts` 下。

### 8.1 在根目录只运行一次的脚本

使用 `run`：

```yaml
melos:
  scripts:
    verify:
      description: Analyze and test the whole workspace.
      run: dart run melos analyze && dart run melos test
```

### 8.2 在每个匹配包运行的脚本

使用 `exec`。Melos 8 中 `run` 与 `exec` 不能同时出现：

```yaml
melos:
  scripts:
    test:packages:
      description: Run tests only in packages that contain tests.
      exec:
        command: flutter test
        concurrency: 4
        failFast: true
        groupLogs: true
      packageFilters:
        dirExists: test
        flutter: true
```

运行方式：

```bash
dart run melos run test:packages
```

脚本可添加 `env` 来提供环境变量，或用 `steps` 定义依次执行的多个步骤。
需要交互式终端（如 `flutter run`）时，可设置 `stdio: inherit`；普通 CI
任务保持默认的 `pipe` 即可。

## 9. 代码生成实践

Flutter 项目经常同时使用 `build_runner`、`freezed` 或
`json_serializable`。可定义一个依赖顺序明确的脚本：

```yaml
melos:
  scripts:
    generate:
      description: Generate Dart sources in packages that use build_runner.
      exec:
        command: dart run build_runner build --delete-conflicting-outputs
        concurrency: 1
        failFast: true
        orderDependents: true
      packageFilters:
        dependsOn: build_runner
```

先用 `--scope` 或 `--diff` 在小范围验证，再在 CI 执行全部生成。生成代码是否
提交到仓库，应由团队约定保持一致。

## 10. CI 建议

一个典型 CI 流程：

```bash
dart pub get
dart run melos bootstrap
dart run melos format --set-exit-if-changed
dart run melos analyze
dart run melos test
```

PR 的快速检查可根据变更范围缩小：

```bash
dart run melos format --set-exit-if-changed --diff origin/main
dart run melos analyze --diff origin/main --include-dependents
dart run melos test --diff origin/main --include-dependents
```

发布型仓库还可以研究 `melos version` 与 `melos publish`。它们会涉及 Git 标签、
变更日志、版本号和发布凭据，应在受保护分支与明确的发布策略下执行；先运行
`dart run melos <command> --help` 查看当前版本的选项。

## 11. 常见问题排查

### `No packages were found`

检查根 `pubspec.yaml` 是否有正确的 `workspace` 路径，以及每个子包是否有
`resolution: workspace`。Melos 8 不读取旧版 `melos.yaml` 的包路径配置。

### `melos: command not found`

不要在脚本中假定全局安装。改用 `dart run melos ...`，并确认 Flutter/Dart SDK
已加入 `PATH`。

### 子包中仍有 `pubspec.lock` 或 `.dart_tool/package_config.json`

在根目录运行 `dart pub get`。Pub Workspace 会识别并清理不应存在的子包解析
文件，根目录的 `pubspec.lock` 才是工作区唯一的锁定文件。

### 脚本反复输出自身名称

检查 `melos.scripts` 是否用了内置命令名。将脚本改名为 `check`、
`format:check`、`generate` 等非内置名称。

### 本地包版本或依赖不一致

先执行 `dart run melos bootstrap`；随后使用 `dart pub outdated` 检查版本约束。
只有在明确需要临时覆盖时才使用 `dependency_overrides`，并避免把它当作本地包
联调的常规手段。

## 12. 推荐团队约定

- 根目录只维护工作区成员、统一开发工具与 CI 入口。
- 新增包时，同时更新根 `workspace` 和新包的 `resolution: workspace`。
- 将可重复的质量检查和生成流程写成有描述的 Melos 脚本。
- 本地开发运行 `format:check`、`check`；CI 运行同一组命令以保持一致。
- 共享包变更时，在测试筛选中加入 `--include-dependents`。
- 变更 Melos 主版本前，先阅读该版本迁移说明并在独立分支验证。
