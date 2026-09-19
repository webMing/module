# Skill 与 MCP 资产总览

> **本文定位**：回答"当前装了什么、放在哪、怎么用、谁负责什么"。
> 原理与排障细节见 [`docs/ai-tooling/AI_SKILLS_AND_MCP_GUIDE.md`](../ai-tooling/AI_SKILLS_AND_MCP_GUIDE.md)。
>
> 环境基线：Flutter **3.47.4** / Dart **3.13.3**｜DSH `@deepseek-ai/dsh` **0.1.5-rc.2**（profile `web`）
> 状态：**已安装并实测通过**（核对日期 2026-09-19）
>
> 注：§2.1 的官方 skill 清单经逐字节比对官方仓库；§3 的工具名取自当前会话工具列表。

---

## 1. 总览

本项目为 AI agent 配备了两类资产，**职责不重叠**：

| 资产 | 数量 | 本质 | 回答的问题 | 存放位置 |
| --- | --- | --- | --- | --- |
| **Skill** | **27** | Markdown 指令包，按需加载 | "该怎么做" | `.agents/skills/`（25）<br>`.dsh/skills/`（2） |
| **MCP 工具** | **14** | 可调用的外部能力 | "能做什么" | 由 `dart mcp-server` 提供，经 DSH 桥接 |

一句话：**MCP 给锤子和钉子，Skill 给图纸和工法。**

```
┌─────────────────────────────────────────────────────────┐
│ 用户任务                                                 │
└───────────────┬─────────────────────────────────────────┘
                │
      ┌─────────┴─────────┐
      ▼                   ▼
┌──────────────┐   ┌──────────────────────┐
│ Skill (27)   │   │ MCP 工具 (14)         │
│ 指令/工作流   │──▶│ mcp__dart__*          │
│ 告诉 agent   │   │ 实际执行分析/热重载等  │
│ 如何完成任务  │   │                      │
└──────────────┘   └──────────────────────┘
```

---

## 2. Skill 清单（27 个）

### 2.1 官方 prepackaged（25 个）— `.agents/skills/`

来自 Flutter/Dart 官方仓库，**逐字节原样拷贝**，面向任务（task-oriented）设计。

#### 10 个 Flutter 任务 skill

| Skill | 用途 | 对应本项目的相关性 |
| --- | --- | --- |
| `flutter-add-integration-test` | 配置 Flutter Driver、把 MCP 操作转为集成测试 | 需 MCP `dtd` |
| `flutter-add-widget-preview` | 用 previews.dart 加交互式 widget 预览 | 已有 `.widget_preview/` |
| `flutter-add-widget-test` | 用 `WidgetTester` 写组件级测试 | 已有 `test/widget_test.dart` |
| `flutter-apply-architecture-best-practices` | 按 UI / Logic / Data 分层架构 | 项目结构治理时 |
| `flutter-build-responsive-layout` | `LayoutBuilder`/`MediaQuery` 做自适应布局 | 通用 |
| `flutter-fix-layout-issues` | 修 overflow、unbounded constraints | 需 MCP `lsp`/`get_runtime_errors` |
| `flutter-implement-json-serialization` | `fromJson`/`toJson` 手工序列化 | **已装 json_annotation** |
| `flutter-setup-declarative-routing` | `MaterialApp.router` + `go_router` | **已装 go_router 18** |
| `flutter-setup-localization` | `flutter_localizations` + `intl` + `l10n.yaml` | 通用 |
| `flutter-use-http-package` | `http` 包做 REST 请求 | 项目用的是 `dio` |

#### 15 个 Dart skill

| Skill | 用途 |
| --- | --- |
| `dart-add-unit-test` | 用 `package:test` 写单元测试 |
| `dart-build-cli-app` | CLI 架构、退出码、子进程（带 2 个 examples + 2 个 references） |
| `dart-collect-coverage` | `coverage` 包生成 LCOV 报告 |
| `dart-fix-runtime-errors` | `get_runtime_errors` → `lsp` → 修复 → `hot_reload` 闭环（强依赖 MCP） |
| `dart-generate-test-mocks` | `mockito` + `build_runner` 生成 mock |
| `dart-migrate-to-checks-package` | `expect` → `package:checks` 迁移 |
| `dart-resolve-package-conflicts` | `pub get` 版本冲突排查 |
| `dart-run-static-analysis` | `dart analyze` + `dart fix --apply` |
| `dart-setup-ffi-assets` | Native Assets hook（`hook/build.dart`、`hook/link.dart`） |
| `dart-use-doc-examples` | Dartdoc `{@example}` 指令与 `#region` 标签 |
| `dart-use-ffigen` | `ffigen` 自动生成 FFI 绑定 |
| `dart-use-path-package` | `package:path` / `package:file` 路径处理（带 2 个 examples） |
| `dart-use-pattern-matching` | Dart 3 模式匹配与 switch 表达式（带 1 个 example） |
| `dart-use-primary-constructors` | Dart 3.13 主构造函数语法与迁移 |
| `dart-write-documentation` | `///` API 文档规范（Effective Dart） |

> 附属资源共 **7 个文件**，分布在 3 个 skill 下（其余 22 个只有 `SKILL.md`）：
>
> | Skill | 附属资源 |
> | --- | --- |
> | `dart-build-cli-app` | `examples/` 2 个 + `references/` 2 个 |
> | `dart-use-path-package` | `examples/` 2 个 |
> | `dart-use-pattern-matching` | `examples/` 1 个 |
>
> 上表的 3 个 skill 正文均以相对路径引用了自己的资源，属有效文件而非冗余。

### 2.2 项目自建（2 个）— `.dsh/skills/`

自建 skill 位于 **rank 100**，优先级高于官方所在的 `project-agents`（rank 200），
因此**同名时可覆盖官方 skill**。

| Skill | 用途 | 为什么官方无法替代 |
| --- | --- | --- |
| `flutter-workspace-dev` | 本仓库 Pub Workspace / Melos 8 操作规范：SDK 路径探测、`melos` 各命令、只在根 `pub get`、子包 `.dart_tool` 判定 | 官方 skill 不可能知道本机的 SDK 位置与 workspace 结构 |
| `flutter-dart-mcp` | Dart MCP server 配置要点、客户端落点、DTD 连接（`--print-dtd`/`--observe`）、常见失败 | 同上，属环境特定知识 |

**两个 skill 都不含硬编码路径**：SDK 位置用三段回退探测（环境变量 → `.dart_tool/version` → `PATH`）。

### 2.3 与官方仓库的对应关系

| 仓库 | Skill 数 | 说明 |
| --- | --- | --- |
| [flutter/skills](https://github.com/flutter/skills) | 25 | 10 `flutter-*` + 15 `dart-*`，**本项目安装源（超集）** |
| [dart-lang/skills](https://github.com/dart-lang/skills) | 15 | 纯 `dart-*`，与上者逐个字节一致，未重复安装 |

---

## 3. MCP 工具清单（14 个）

由 `dart mcp-server`（`dart_mcp_server` **1.1.2**）提供，经 `@deepseek-ai/dsh-mcp-client`
以 `mcp__dart__<tool>` 命名桥接。

### 3.1 实际可调用的 14 个

| 工具 | 作用 | 本项目可用性 |
| --- | --- | --- |
| `analyze_files` | 分析指定路径或整个项目的错误 | ✅ 已实测（`No errors`） |
| `pub` | 执行 `dart pub get` / `flutter pub add` 等 | ✅ |
| `pub_dev_search` | 搜索 pub.dev 包（含评分、发布者、许可证） | ✅ 已实测 |
| `read_package_uris` | 读取 `package:` / `package-root:` URI 指向的文件/目录 | ✅ 已实测 |
| `rip_grep_packages` | 在依赖中搜索（**需运行环境已装 `ripgrep`（`rg`）**） | ⚠️ 取决于运行环境 |
| `lsp` | hover、签名帮助、工作区符号解析 | ✅ |
| `dtd` | 发现并连接 Dart Tooling Daemon | ⚠️ 需有应用在跑 |
| `hot_reload` / `hot_restart` | 对已连接应用热重载/重启 | ⚠️ 需 DTD 连接 |
| `get_runtime_errors` | 读取运行期错误 | ⚠️ 需 DTD 连接 |
| `widget_inspector` | 操作 Widget Inspector | ⚠️ 需 DTD 连接 |
| `vm_service` | 连接 VM Service 并直接调用方法 | ⚠️ 需 VM Service URI |
| `flutter_driver_command` | 执行 flutter driver 命令 | ⚠️ 需驱动连接 |
| `roots` | 注册/管理项目根 | ✅ 已实测（`Success`） |

### 3.2 未暴露的工具（服务端支持但当前会话不可调用）

`create_project`、`dart_fix`、`dart_format`、`run_tests`、`launch_app`、
`list_devices`、`list_running_apps`、`get_app_logs`、`stop_app`、`get_active_location`

> ⚠️ **实测修正**：本文档早期版本声称"DSH 加载 24 个工具"，**该说法已证伪**。
> 实际尝试调用 `mcp__dart__run_tests` 返回 `Error: unknown tool`，
> 会议话中可调用的 `mcp__dart__*` 恰为上述 14 个——与服务端 `tools/list` 的返回一致。
>
> 原因是 `dart_mcp_server` 按客户端能力**只注册默认启用的工具**；上列 10 个默认关闭项
> 既未出现在服务端 `tools/list`，也未成为本会话工具。若需要它们（如 `run_tests`、`dart_format`），
> 需在 MCP 客户端/服务端侧显式启用。
>
> 判断可用性的唯一可靠依据：**实际调用一次并观察返回**，而不是依赖文档或工具数量推算。

### 3.3 日志中已知的警告

服务端启动时会发出 `notifications/message` 警告：
`Client does not support th...`（客户端未声明某项能力）。不影响已实测的工具。

---

## 4. 配置与文件位置

| 文件 | 作用 | 生效范围 | 是否入库 |
| --- | --- | --- | --- |
| `.agents/skills/` | 官方 25 个 skill | 本项目 | ✅ 已提交 |
| `.dsh/skills/` | 自建 2 个 skill | 本项目 | ✅ 已提交 |
| `.dsh/cordis.patch.yml` | Dart MCP 项目覆盖层 | 本项目（需 `--patch`） | ✅ 已提交 |
| `~/.dsh/profiles/web/cordis.patch.yml` | 用户级 profile patch | **所有项目** | ❌ 机器本地配置 |

### 4.1 skill 扫描根与优先级

`dsh-skill-filesystem` 按 rank 扫描，**rank 小者优先**：

| Rank | 路径 | 本项目 |
| --- | --- | --- |
| 100 | `<项目根>/.dsh/skills` | 自建 2 个 |
| 200 | `<项目根>/.agents/skills` | 官方 25 个 |
| 300 | `Config.customSkillDirs` | — |
| 400 | `~/.dsh/skills` | — |
| 500 | `~/.agents/skills` | — |

skill 格式：`<name>/SKILL.md`（目录 bundle），YAML frontmatter 必填 `name` + `description`。
**不支持嵌套发现**（不会扫 `**/SKILL.md`）。

### 4.2 MCP 配置内容

两份 patch 文件中的 `- insert:` 条目结构完全一致：

```yaml
- insert:
    - id: mcp-dart
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: dart                        # → mcp__dart__*
        transport: stdio
        command: <dart 绝对路径>                 # 本机 dart 不在 PATH
        args: [mcp-server]
        toolCallTimeoutMs: 60000
        reconnect:
          enabled: true
```

加载顺序：bundle patches → profile patch → `$DSH_HOME/cordis.patch.yml` → `--patch` 覆盖层。

---

## 5. 使用方式

### 5.1 skill：两种触发

```text
① 模型自动加载：任务匹配 description 时，agent 调 skill 工具加载完整正文
② 用户显式调用：输入 /<skill-name>（如 /flutter-setup-declarative-routing）
```

skill 目录**被实时监视**：新增/改名/删除无需重启；正文改动每次加载都重新读盘。

### 5.2 MCP：直接调用

工具已注册为原生工具，agent 按需调用 `mcp__dart__*`。手工验证方式：

```bash
# 最轻的连通性检查（只读）
# 调用 mcp__dart__roots 注册项目根
# 调用 mcp__dart__analyze_files 分析 lib/
```

### 5.3 需要"应用在跑"的工具

`hot_reload`、`hot_restart`、`widget_inspector`、`get_runtime_errors`、`dtd`、`vm_service`
需要先把应用注册到 Dart Tooling Daemon：

```bash
# Flutter 应用：debug/profile 默认注册 DTD（除非传 --no-dds）
flutter run --print-dtd        # 直接拿到 DTD URI

# 纯 Dart 应用：需 --observe
dart --observe --print-dtd bin/main.dart
# 参数必须在脚本路径之前
```

### 5.4 更新官方 skill

```bash
# 方式一：官方工具（会联网）
npx skills add flutter/skills --skill '*' --agent universal --yes
npx skills update

# 方式二（本项目采用）：重新拷贝
git clone --depth 1 https://github.com/flutter/skills.git /tmp/fl_skills
cp -R /tmp/fl_skills/skills/* .agents/skills/
```

---

## 6. 典型组合用法

| 任务 | 组合 |
| --- | --- |
| 配 go_router 路由 | skill `flutter-setup-declarative-routing` + MCP `pub`（加依赖） |
| 修 RenderFlex overflow | skill `flutter-fix-layout-issues` + MCP `get_runtime_errors`、`lsp` |
| 加集成测试 | skill `flutter-add-integration-test` + MCP `dtd`、`flutter_driver_command` |
| 排查依赖冲突 | skill `dart-resolve-package-conflicts` + MCP `pub`、`pub_dev_search` |
| 跑本仓库质量门禁 | skill `flutter-workspace-dev`（含 `melos run check` 与 SDK 探测） |
| 生成序列化代码 | skill `flutter-implement-json-serialization` + MCP `pub` |

---

## 7. 已知限制

| 限制 | 说明 |
| --- | --- |
| 1 个官方 skill 描述被截断 | `dart-setup-ffi-assets` 的 `description` 长 651 字符，超 DSH `catalogDescriptionMaxLength`（默认 500），仅目录显示截断，正文不受影响 |
| 拷贝方式不自动更新 | 需按官方仓库变更手动同步（官方路径是 `npx skills update`） |
| DSH 只桥接 tools | 不支持 MCP resources 与 prompts |
| `dart_mcp_server` 为 WIP | pub.dev 标注 experimental，工具集与开关可能随版本变化 |
| profile patch 内的路径硬编码 | `~/.dsh/profiles/web/cordis.patch.yml` 中的 `command` 是含版本号的绝对路径（用户级配置、绑定本机 SDK），**升级 Flutter SDK 后需手动更新** |
| 部分工具需运行中的应用 | 见 §5.3 |

---

## 8. 快速核对清单

```bash
# skill 数量（应为 25 + 2）
ls -d .agents/skills/*/ | wc -l
ls -d .dsh/skills/*/    | wc -l

# MCP 配置是否在位（两处都应有 mcp-dart）
grep -c mcp-dart .dsh/cordis.patch.yml
grep -c mcp-dart ~/.dsh/profiles/web/cordis.patch.yml

# DSH 是否加载了 MCP 工具：在当前会话查看工具列表是否有 mcp__dart__*
# skill 是否被识别：查看会话的 skill 目录是否含上述 27 个名称
```

---

## 9. 相关文档

| 文档 | 内容 |
| --- | --- |
| [AI_SKILLS_AND_MCP_GUIDE.md](../ai-tooling/AI_SKILLS_AND_MCP_GUIDE.md) | skill 机制原理、Dart MCP 配置细节、实测记录、排障 |
| [PUB_WORKSPACE_GUIDE.md](../pub-workspace/PUB_WORKSPACE_GUIDE.md) | Pub Workspace 机制（`.dart_tool` 混淆点、glob、嵌套） |
| [MELOS8_COMMANDS_GUIDE.md](../melos/MELOS8_COMMANDS_GUIDE.md) | Melos 8.7.0 命令与 SDK 路径解析 |
| [MELOS_USAGE_GUIDE.md](../melos-workspace-migration/MELOS_USAGE_GUIDE.md) | Melos 基础与高级实践 |

**外部来源**

- [Introducing Skills for Dart and Flutter](https://flutter.dev/blog/introducing-skills-for-dart-and-flutter)（官方发布公告）
- [flutter/skills](https://github.com/flutter/skills) ｜ [dart-lang/skills](https://github.com/dart-lang/skills)
- [dart_mcp_server](https://pub.dev/packages/dart_mcp_server) ｜ [Flutter MCP 文档](https://docs.flutter.dev/ai/mcp-server)
- [Agent Skills 规范](https://agentskills.io)
