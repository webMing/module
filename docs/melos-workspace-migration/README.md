# Melos 8 工作区迁移记录

## 背景

项目根目录已安装 `melos: ^8.7.0`，同时保留了旧版 Melos 使用的
`melos.yaml` 配置文件。执行 `melos list` 时返回：

```text
No packages were found with the current filters.
```

## 根因

Melos 7 及更高版本基于 Dart Pub Workspace 工作：

- 不再从 `melos.yaml` 读取包目录和脚本配置。
- 工作区包必须在根 `pubspec.yaml` 的 `workspace` 中显式列出。
- 每个子包必须声明 `resolution: workspace`。
- 旧配置中的 `packages/**` 因而没有被 Melos 8 使用。

此外，若自定义脚本与 Melos 内置命令同名（例如 `bootstrap`、`analyze`、
`test` 或 `format`），会覆盖内置命令，导致递归调用风险。

## 本次修改

1. 删除旧版 `melos.yaml`。
2. 在根 `pubspec.yaml` 添加工作区成员：

   ```yaml
   workspace:
     - packages/home
     - packages/login
   ```

3. 在 `packages/home/pubspec.yaml` 和 `packages/login/pubspec.yaml` 添加：

   ```yaml
   resolution: workspace
   ```

4. 在根 `pubspec.yaml` 中添加 `melos` 配置，启用
   `useRootAsPackage: true`，将根 Flutter 应用也纳入管理范围。
5. 添加不与内置命令冲突的辅助脚本：

   - `get`：解析 Pub Workspace 依赖。
   - `check`：执行静态分析和测试。
   - `format:check`：检查格式，不改动文件。
   - `format:fix`：格式化全部 Dart 文件。

6. 运行根目录的 `flutter pub get`。Pub Workspace 会统一使用根
   `pubspec.lock`，因此移除了子包中旧的 lockfile 和 package config。

## 验证结果

以下操作均已完成并成功：

- `melos list --long` 识别出 `module`、`home`、`login` 共 3 个包。
- `melos bootstrap` 成功完成依赖初始化和 IntelliJ 工作区文件生成。
- `melos run format:check`：所有 Dart 文件已符合格式规范。
- `melos analyze`：3 个包均无静态分析问题。
- `melos test`：3 个包的测试均通过。

## 日常使用

先确保 Flutter SDK 的 `bin` 目录已加入 `PATH`，然后在项目根目录执行：

```bash
# 初始化或更新整个工作区
dart run melos bootstrap

# 更新 Pub Workspace 依赖
dart run melos run get

# 分析并运行所有测试
dart run melos run check

# 仅检查格式
dart run melos run format:check

# 自动格式化
dart run melos run format:fix
```

也可直接使用 Melos 内置命令：

```bash
dart run melos analyze
dart run melos test
dart run melos format --set-exit-if-changed
```
