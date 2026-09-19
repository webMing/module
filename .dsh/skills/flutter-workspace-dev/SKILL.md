---
name: flutter-workspace-dev
description: >-
  Use when running Dart/Flutter tooling in this repository: Pub Workspace
  commands, Melos 8 scripts, analysis, tests, formatting, and anything that
  needs the Flutter SDK. Covers the absolute-path SDK invocation required when
  flutter/dart are absent from PATH.
whenToUse: >-
  A task requires dart, flutter, melos, pub get/get, tests, analysis, or
  formatting inside this monorepo.
---

# Flutter/Dart 工作区开发（本仓库）

本仓库是 **Pub Workspace 多包项目**：根包 `module`（Flutter 应用）+ `packages/home` + `packages/login`。

## 关键事实

- 本仓库是 Flutter/Dart 项目，但 **`flutter` 与 `dart` 都不在 PATH 中**
  （`.zshrc`、`.zprofile`、`/etc/zshrc` 均无配置）。直接写 `dart run melos ...`
  会得到 `command not found`。
- 因此需要**先探测 SDK 位置**，不要硬编码带版本号的路径（升级 SDK 后会失效）。
- 根 `pubspec.yaml` 声明了 `workspace:`，成员包各自有 `resolution: workspace`，
  全仓库只有 **一份** `pubspec.lock` 和 **一份** `.dart_tool/package_config.json`。

## 第一步：确定 SDK 路径（按顺序回退）

```bash
# 1) 环境变量优先
SDK_ROOT="${FLUTTER_ROOT:-${MELOS_SDK_PATH:-}}"

# 2) 回退：用 .dart_tool/version 里的 Flutter 版本定位 SDK
if [ -z "$SDK_ROOT" ]; then
  V=$(cat .dart_tool/version 2>/dev/null)          # 例如 3.47.4
  CAND="$HOME/Downloads/flutter_$V"                # 本机 SDK 存放位置
  [ -x "$CAND/bin/cache/dart-sdk/bin/dart" ] && SDK_ROOT="$CAND"
fi

# 3) 再回退：PATH 里若有 dart 就直接用
if [ -n "$SDK_ROOT" ]; then
  DART="$SDK_ROOT/bin/cache/dart-sdk/bin/dart"
else
  DART=$(command -v dart)
fi
echo "DART=$DART  SDK_ROOT=$SDK_ROOT"
```

> `.dart_tool/version` 由 Flutter 工具写入，内容是 Flutter 版本号（本项目为 `3.47.4`），
> 根目录与各子包下都有一份且一致。若该文件不存在，交给 `command -v dart` 兜底。

## 必须遵守的命令形态

用探测得到的 `$DART`（SDK 内置二进制，跳过 Flutter 包装脚本）：

```bash
$DART run melos list --long          # 查看包
$DART run melos analyze              # 静态分析
$DART run melos test                 # 测试
$DART run melos format --set-exit-if-changed
$DART run melos run check            # = analyze && test
```

`analyze`/`test` 会派生 flutter 子进程，需要显式告诉 Melos 用哪个 SDK：

```bash
$DART run melos --sdk-path "$SDK_ROOT" analyze
```

**不要**用 `$SDK_ROOT/bin/dart`——那是 Flutter 包装脚本，运行时会尝试写
`$SDK_ROOT/bin/cache/`，在受限环境下报 `Operation not permitted`。
用 `bin/cache/dart-sdk/bin/dart` 这个内层二进制更稳。

## 工作区纪律

- **只在仓库根执行 `pub get`**。在子包目录内单独 `pub get` 会生成遮蔽根配置的
  `packages/<pkg>/.dart_tool/package_config.json`，使该包退化为独立解析。
- 子包目录下**不应**出现 `pubspec.lock` 或 `.dart_tool/package_config.json`；
  出现即说明有人单独解析过，删除后回根目录重跑一次。
- 子包 `.dart_tool/` 里的 `version`、`package_graph.json`、`pub/workspace_ref.json`
  是**正常辅助文件**，不是污染。
- 本地包互相依赖按普通版本约束声明，不用 `path:`，也不用 `dependency_overrides`。
- 改动任何 `pubspec.yaml` 后，回根目录执行一次 `dart pub get` 或 `melos bootstrap`。

## 新增子包

1. 在根 `pubspec.yaml` 的 `workspace:` 加入路径（SDK ≥ 3.11，也可直接用 `packages/*`）。
2. 在新包 `pubspec.yaml` 写 `resolution: workspace`，且 `environment.sdk` ≥ `^3.6.0`。
3. 回根目录执行一次 `dart pub get`。

## 验证工作区是否健康

```bash
find . -name package_config.json -not -path './build/*'   # 期望只有根目录一份
find . -name pubspec.lock        -not -path './build/*'   # 期望只有根目录一份
cat packages/home/.dart_tool/pub/workspace_ref.json       # 应指向 workspaceRoot
```
