---
name: flutter-dart-mcp
description: >-
  Use when connecting the Dart/Flutter MCP server to an AI client, debugging a
  running Flutter app through DTD (hot reload, widget inspector, runtime
  errors), or wiring MCP tools into a harness. Covers dart mcp-server setup,
  client config snippets, and DTD connection hints.
whenToUse: >-
  A task involves MCP server configuration, AI agent tooling, hot reload via
  tooling, the Dart Tooling Daemon, or connecting an agent to a running app.
---

# Dart / Flutter MCP server

## 本质

`dart mcp-server` 是 **Dart SDK 自带的子命令**（本机 3.13.3 已具备；需 Dart 3.9.0-163.0.dev 以上）。
首次运行会自动从 pub 获取 `dart_mcp_server` 包（`tools.dart.dev` 发布，当前 1.1.2）。

它通过 **stdio** 暴露 Dart/Flutter 开发工具，主要工具：

| 工具 | 作用 |
| --- | --- |
| `analyze_files` | 分析项目错误（默认启用） |
| `pub` | 执行 `dart pub get` / `flutter pub add` 等 |
| `pub_dev_search` | 搜索 pub.dev 包 |
| `read_package_uris` | 读取 `package:` / `package-root:` URI |
| `rip_grep_packages` | 在依赖里搜索（需已装 ripgrep） |
| `lsp` | hover、签名帮助、符号解析 |
| `dtd` | 发现并连接 Dart Tooling Daemon |
| `hot_reload` / `hot_restart` | 对已连接应用热重载/重启 |
| `get_runtime_errors` | 读取运行期错误 |
| `widget_inspector` | 操作 Widget Inspector |
| `vm_service` | 连接 VM Service 并直接调用方法 |

默认关闭、需显式启用的包括：`create_project`、`dart_fix`、`dart_format`、`run_tests`、
`launch_app`、`list_devices`、`get_app_logs`、`stop_app`、`list_running_apps`、`get_active_location`。

## 配置要点

- `command` 必须是**能直接执行**的 dart 路径。本机 `dart` 不在 PATH，
  但**不要硬编码带版本号的绝对路径**（升级 SDK 会失效）——先按下节探测。
- Dart 3.9.0 之前还需追加 `--experimental-mcp-server`；Dart 3.9+ **不需要**。
- 传输方式固定为 stdio；Harness 侧的 `transport` 要写 `stdio`。
- 服务端每次启动都会维护 `~/.pub-cache/active_roots`，因此运行环境必须能写 pub 缓存；
  若不能，给条目加 `env.PUB_CACHE` 指向可写目录。

### 探测 dart 路径（与 flutter-workspace-dev 同一套办法）

```bash
SDK_ROOT="${FLUTTER_ROOT:-${MELOS_SDK_PATH:-}}"
if [ -z "$SDK_ROOT" ]; then
  V=$(cat .dart_tool/version 2>/dev/null)     # 例如 3.47.4
  CAND="$HOME/Downloads/flutter_$V"
  [ -x "$CAND/bin/cache/dart-sdk/bin/dart" ] && SDK_ROOT="$CAND"
fi
DART="${SDK_ROOT:+$SDK_ROOT/bin/cache/dart-sdk/bin/dart}"
[ -n "$DART" ] || DART=$(command -v dart)
```

把 `$DART` 的值填进客户端配置的 `command`：

```json
{"command": "<上一步探测到的 dart 绝对路径>", "args": ["mcp-server"]}
```

> 注意：**不要直接执行 bundle 里的 `bin/dart_mcp_server`**——裸二进制会把自己的
> 所在目录当作 Dart SDK，报 `Invalid Dart SDK path: .../bundle`。必须经
> `dart mcp-server` 包装器，由它传入 SDK 路径。

## 客户端接入

- **VS Code（Dart 扩展 ≥ 3.114）**：用户设置加 `"dart.mcpServer": true`，扩展会自动注册，无需手写命令。
  本机扩展为 3.142.0，支持该设置。
- **Gemini CLI**：项目 `.gemini/settings.json` 或 `~/.gemini/settings.json` 的 `mcpServers.dart`。
- **Cursor**：`~/.cursor/mcp.json` 或项目 `.cursor/mcp.json` 的 `mcpServers.dart`。
- **DSH**：`@deepseek-ai/dsh-mcp-client` 插件，工具以 `mcp__<serverName>__<tool>` 暴露。
  DSH 默认**不挂载**它，需在 profile 补丁里 insert 一行。

## 连接运行中的应用（DTD）

- 启动应用时加 `--print-dtd`，可直接拿到 DTD URI，免去枚举。
- 纯 Dart 应用还需 `--observe`；Flutter debug/profile 模式默认注册到 DTD
  （除非传 `--no-dds`）。
- 参数顺序：`dart --observe --print-dtd bin/main.dart`（必须在脚本名之前）。
- 建议把这两条写进规则文件，让 agent 每次都照做。

## 常见失败

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `command not found: dart` | MCP 客户端按 PATH 查找 | `command` 写 dart 绝对路径 |
| pub 下载报 `Operation not permitted`（写 `~/.pub-cache/_temp`） | 沙箱/权限限制，非配置问题 | 在正常 shell 中先跑一次 `dart mcp-server` 预热缓存 |
| 工具列表里没有 flutter/hot reload 系列 | 这些工具默认关闭 | 在客户端显式启用对应工具 |
| 连不上应用 | 应用未注册 DTD | 启动时加 `--print-dtd`（Dart 应用再加 `--observe`） |
