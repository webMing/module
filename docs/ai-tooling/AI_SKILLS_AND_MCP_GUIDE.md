# Flutter / Dart skill 与 Dart MCP 配置指南（DSH + VS Code）

> 环境基线：Flutter **3.47.4** / Dart **3.13.3**｜DSH `@deepseek-ai/dsh` **0.1.5-rc.2**（profile `web`）
> 本文三个问题分别对应：**DSH skill 怎么配**、**Dart MCP 怎么配**、**Flutter/Dart skill 从哪来**。

---

## 0. 先分清三件容易混为一谈的事

| 名称 | 是什么 | 归属 | 本项目现状 |
| --- | --- | --- | --- |
| **DSH skill** | 磁盘上的 Markdown 指令包，agent 按需加载 | DSH 机制（`dsh-skill-filesystem` + `dsh-tool-skill`） | ✅ 已启用（base bundle 默认挂载） |
| **Dart MCP** | `dart mcp-server` 子命令，以 stdio 暴露 Dart/Flutter 工具 | Dart SDK | ✅ 服务端**实测可用**；DSH 侧已写入配置，待重启加载 |
| **Flutter/Dart skill** | 任务型指令包（官方 prepackaged + 包分发 + 自建） | 官方仓库 + pub 生态（`package:skills`） | ✅ 已装官方 25 个 + 自建 2 个 |

---

## 1. DSH skill：原理与配置

### 1.1 扫描根目录与优先级

`dsh-skill-filesystem` 按 rank 顺序扫描下列目录，**同名时 rank 小者优先**：

| Rank | 来源 | 路径 |
| --- | --- | --- |
| 100 | `project-dsh` | `<项目根>/.dsh/skills` |
| 200 | `project-agents` | `<项目根>/.agents/skills` |
| 300 | `custom` | `Config.customSkillDirs` |
| 400 | `user-dsh` | `$DSH_HOME/skills`（默认 `~/.dsh/skills`，跳过其 `.system` 子目录） |
| 500 | `user-agents` | `~/.agents/skills` |
| 600 | `bundled` | `$DSH_BUNDLED_SKILL_DIR`（需显式配置 `bundledSkillDir`） |

项目根 = 最近的含 `.git` 的祖先目录；不存在时用当前工作目录。

### 1.2 skill 的两种文件形态

```text
<扫描根>/
├── my-skill/
│   └── SKILL.md          # 形态一：目录 bundle（推荐，可带 scripts/ references/ assets/）
└── another.md            # 形态二：平铺文件
```

**不支持**嵌套发现（`**/SKILL.md` 不会被扫到），skill 必须直接位于扫描根之下。

### 1.3 frontmatter 字段

```yaml
---
name: my-skill                  # 必填
description: Use when ...       # 必填，决定 agent 何时加载
whenToUse: ...                  # 可选
metadata: {...}                 # 可选
disable-model-invocation: true  # 可选：模型不可见、不可加载
user-invocable: false           # 可选：用户不能用 /name 调用
---
```

两个开关都接受 YAML 布尔值及 `true/false`、`yes/no`、`on/off`、`1/0`（不区分大小写）。
拼写错误或非布尔值会让**整个 skill 被丢弃并告警**，而不是静默放行。

### 1.4 加载与热更新行为

- 会话开始时，agent 收到一份**目录**（名称 + 有长度上限的描述）。
- 模型用 `skill` 工具按精确名称加载完整正文；用户也可用 `/name` 直接注入。
- 目录会被**监视**：新增、改名、删除无需重启即可生效；目录变更会追加一份完整替换。
- 正文每次加载都重新读盘，因此**改正文无需重启**；只有 frontmatter（目录条目）变化才影响目录。
- 描述长度上限由 `dsh-tool-skill` 的 `catalogDescriptionMaxLength` 控制，默认 500（最小 3）。

### 1.5 本项目已创建的两个 skill

| skill | 路径 | 用途 |
| --- | --- | --- |
| `flutter-workspace-dev` | `.dsh/skills/flutter-workspace-dev/SKILL.md` | 本仓库的 Pub Workspace / Melos 8 命令，含「dart 不在 PATH」的绝对路径写法与工作区纪律 |
| `flutter-dart-mcp` | `.dsh/skills/flutter-dart-mcp/SKILL.md` | Dart MCP server 的配置要点、客户端接入、DTD 连接与常见失败 |

**实测验证**：写入 `.dsh/skills/` 后无需重启，当前会话的 skill 目录立即出现了这两项——
证明 §1.4 的热加载描述属实。

> `project-dsh`（rank 100）优先于 `project-agents`（rank 200）：想让本仓库 skill 覆盖
> 从 pub 包安装来的同名 skill，就放在 `.dsh/skills/`。

---

## 2. Dart MCP：配置

### 2.1 服务端是什么

`dart mcp-server` 是 **Dart SDK 自带子命令**，stdio 传输，首次运行会从 pub 拉取
`dart_mcp_server`（`tools.dart.dev` 发布，当前 1.1.2）。要求 Dart **3.9.0-163.0.dev 或更高**
（本项目 3.13.3 满足，因此**不需要** `--experimental-mcp-server`）。

**实测确认**：在本机执行 `dart mcp-server --help` 会进入参数解析并触发
`dart_mcp_server` 的 pub 下载阶段（而不是报「找不到命令」）——证明该子命令真实存在。

### 2.2 通用客户端配置（stdio）

```json
{
  "mcpServers": {
    "dart": {
      "command": "dart",
      "args": ["mcp-server"]
    }
  }
}
```

本机注意：`dart` **不在 PATH**，所以 `command` 要写绝对路径——

```json
{
  "mcpServers": {
    "dart": {
      "command": "/Users/stephanie/Downloads/flutter_3.47.4/bin/cache/dart-sdk/bin/dart",
      "args": ["mcp-server"]
    }
  }
}
```

> 为什么不用 `<flutter>/bin/dart`：那是包装脚本，运行时可能尝试写 `bin/cache/`，
> 在受限环境下会失败。直接用 SDK 内置的 `bin/cache/dart-sdk/bin/dart` 更稳。

### 2.3 各客户端落点

| 客户端 | 配置位置 | 备注 |
| --- | --- | --- |
| **VS Code + Dart 扩展** | 用户设置加 `"dart.mcpServer": true` | 扩展版本需 ≥ 3.114（本机 3.142.0 ✅），扩展自动注册，**无需手写命令**，也不会受 dart 不在 PATH 的影响 |
| **Gemini CLI** | 项目 `.gemini/settings.json` 或 `~/.gemini/settings.json` | 用 §2.2 的 JSON |
| **Cursor** | 项目 `.cursor/mcp.json` 或 `~/.cursor/mcp.json` | 同上 |
| **DSH** | profile 补丁（见 §2.4） | 插件默认不挂载 |

### 2.4 接入 DSH

DSH 通过 `@deepseek-ai/dsh-mcp-client` 桥接外部 MCP：**一台服务器一条配置行**，
工具以 `mcp__<serverName>__<tool>` 暴露，例如 `mcp__dart__analyze_files`。

本项目已提供可直接使用的覆盖层：`.dsh/cordis.patch.yml`。两种生效方式：

```bash
# 方式一：启动时叠加（不动全局配置，立即生效）
dsh web --patch .dsh/cordis.patch.yml

# 方式二：长期生效——把该条目合并进 ~/.dsh/profiles/web/cordis.patch.yml
```

关键字段：

| 字段 | 说明 |
| --- | --- |
| `serverName` | 命名空间，`[A-Za-z0-9_-]{1,32}`，需唯一 |
| `transport` | `stdio` 或 `streamable-http` |
| `command` / `args` / `env` / `cwd` | stdio 模式的可执行文件与参数 |
| `toolCallTimeoutMs` | 单次 `tools/call` 超时，默认 60000 |
| `failOnStartupError` | 默认 `false`：初次连接失败 harness 仍启动，仅该服务器工具缺失 |
| `reconnect.*` | 断线重连退避（默认启用） |

> DSH 的 MCP 桥接**只支持 tools**，不支持 MCP resources 与 prompts。
> 而 Dart MCP server 的部分能力（如 resources）在 DSH 下不可用，工具集不受影响。

### 2.5 Dart MCP 提供哪些工具

**默认启用**：`analyze_files`、`pub`、`pub_dev_search`、`read_package_uris`、
`rip_grep_packages`（需装 ripgrep）、`lsp`、`dtd`、`hot_reload`、`hot_restart`、
`get_runtime_errors`、`widget_inspector`、`vm_service`、`roots`。

**默认关闭、需显式启用**：`create_project`、`dart_fix`、`dart_format`、`run_tests`、
`launch_app`、`list_devices`、`list_running_apps`、`get_app_logs`、`stop_app`、`get_active_location`。

### 2.6 连接运行中的应用（DTD）

- 启动应用时加 `--print-dtd` 可直接拿到 DTD URI，避免枚举。
- 纯 Dart 应用还需 `--observe`；Flutter debug/profile 默认注册到 DTD（`--no-dds` 会禁用）。
- 参数必须在脚本名之前：`dart --observe --print-dtd bin/main.dart`。
- 建议写入规则文件（如 `AGENTS.md`）让 agent 每次照做。

---

## 3. Flutter / Dart skill：从哪来

### 3.0 官方 prepackaged skills（主力来源）

Flutter/Dart 团队**直接维护了两个 skill 仓库**，共 25 个任务型 skill：

| 仓库 | 数量 | 内容 |
| --- | --- | --- |
| [flutter/skills](https://github.com/flutter/skills) | **25** | 10 个 `flutter-*` + 15 个 `dart-*` |
| [dart-lang/skills](https://github.com/dart-lang/skills) | **15** | 15 个 `dart-*`（与 flutter/skills 中的逐个字节一致） |

合起来去重 = **25 个**（`flutter/skills` 是超集）。官方安装命令：

```bash
npx skills add flutter/skills --skill '*' --agent universal --yes
npx skills add dart-lang/skills --skill '*' --agent universal --yes
npx skills update          # 后续更新
```

> 注意 `--agent universal` 的落点是 **`.agents/skills/`**，正是 DSH 的 `project-agents` 扫描根。
> 也可直接从仓库把 `skills/` 下的目录拷进 `.agents/skills/`（本项目采用后者：无网络依赖、可进版本控制）。
> 完整清单见 [Introducing Skills for Dart and Flutter](https://flutter.dev/blog/introducing-skills-for-dart-and-flutter)（2026-05-06）。

**官方设计取向（重要）**：官方明确放弃了"只提供文档"的 skill，因为 Flutter 文档开源、现代模型已能自行检索，
因此转向 **task-oriented**——每个 skill 聚焦一个具体开发任务，并与 Dart MCP 互补
（MCP 给工具，skill 教怎么用；例如 `dart-fix-runtime-errors` 串起 `get_runtime_errors` → `lsp` → 修复 → `hot_reload`）。

### 3.1 官方机制：包携带 skill

Dart 官方支持把 skill 随包分发（[Ship skills with packages](https://dart.dev/tools/pub/package-skills)）：

```text
my_package/
├── lib/
├── skills/                     # 面向包使用者，随包发布
│   └── my_package-routing/
│       └── SKILL.md
├── .agents/skills/             # 面向包维护者，不发布
└── pubspec.yaml
```

- 消费者一条命令安装：`dart run skills@ get`
- 目录名必须带包名前缀（`my_package` → `my_package-routing` 或 `my-package-routing`），
  否则 `package:skills` 会**跳过**该 skill。
- 维护者内部用 `.agents/skills/`，不随包发布。

### 3.2 关键衔接：官方安装目标正好是 DSH 的扫描根

`dart run skills@ get` 把 skill 装进**项目的 `.agents/skills/`**——
这正是 DSH 的 `project-agents` 扫描根（rank 200）。

**结论：用 Dart 官方方式安装的 Flutter/Dart 包 skill，DSH 能直接发现，无需额外配置。**
唯一差别是 DSH 要求 `name` + `description` 必填（与 Agent Skills 规范一致）。

优先级提醒：`.dsh/skills/`（100）> `.agents/skills/`（200）。
本仓库自建的 skill 放在 `.dsh/skills/`，因此可以覆盖同名安装来的 skill。

### 3.3 三种获取 Flutter/Dart skill 的途径

| 途径 | 做法 | 适用 | 本项目 |
| --- | --- | --- | --- |
| **官方 prepackaged** | `npx skills add <repo> --agent universal` 或直接拷贝 | Flutter/Dart 通用任务工作流 | ✅ 25 个已装 |
| **自建** | 在 `.dsh/skills/<name>/SKILL.md` 手写 | 项目特有约定、环境坑点 | ✅ 2 个已建 |
| **从依赖包安装** | `dart run skills@ get` → 落到 `.agents/skills/` | 依赖包自带的库用法 | 🔸 本项目仅 `get_it` 带 skill（`skills/` 下 2 个），尚未安装 |

> 注意区分：**Dart 扩展提供的是 MCP 工具**（§2.3），**skill 是指令包**（本节）。
> 两者互补：MCP 给 agent「能做什么」，skill 给 agent「该怎么做」。

### 3.4 若要让本仓库也对外分发 skill

在根（或某个子包）新建 `skills/` 目录，按 §3.1 的命名前缀规则编写，即可随
`dart pub publish` 发布。

---

## 4. 本项目的落地清单

| 文件 | 作用 | 状态 |
| --- | --- | --- |
| `.agents/skills/`（25 个目录） | 官方 prepackaged Flutter/Dart 任务型 skill | ✅ 25 个已装 |
| `.dsh/skills/flutter-workspace-dev/SKILL.md` | 工作区/Melos 操作规范 | ✅ |
| `.dsh/skills/flutter-dart-mcp/SKILL.md` | Dart MCP 与 DTD 使用规范 | ✅ |
| `.dsh/cordis.patch.yml` | Dart MCP 的项目覆盖层（可移植/可分享） | ✅ |
| `~/.dsh/profiles/web/cordis.patch.yml` | 用户级 profile patch，长期生效 | ✅ 已写入 |
| `docs/ai-tooling/AI_SKILLS_AND_MCP_GUIDE.md` | 本文档 | ✅ |

安装官方 25 个 skill（本项目已执行，采用直接拷贝方式）：

```bash
# 方式一：官方 npx 工具（会联网，可 npx skills update 更新）
npx skills add flutter/skills --skill '*' --agent universal --yes

# 方式二（本项目采用）：从官方仓库拷贝，无网络依赖、可进版本控制
git clone --depth 1 https://github.com/flutter/skills.git /tmp/fl_skills
mkdir -p .agents/skills && cp -R /tmp/fl_skills/skills/* .agents/skills/
```

启用 Dart MCP 的完整步骤：

```bash
# 1) 预热：首次编译并安装 bundle（必须能写 ~/.pub-cache 与
#    ~/Library/Application Support/Dart/），联网执行一次即可
/Users/stephanie/Downloads/flutter_3.47.4/bin/cache/dart-sdk/bin/dart mcp-server --help

# 2) 接线：条目已写入 ~/.dsh/profiles/web/cordis.patch.yml
#    （或改为启动时叠加：dsh web --patch .dsh/cordis.patch.yml）

# 3) 重启 DSH 使其生效——这是必须的一步
dsh web

# 4) 重启后在会话里确认工具出现（名称形如 mcp__dart__analyze_files）
```

> 第 2 步若想**只对个别项目生效**，保留 `.dsh/cordis.patch.yml` 并用 `--patch` 启动即可，
> 不必改动用户级 profile patch。

---

## 5. 实测记录、限制与未验证项

### 5.1 MCP 服务端：已实测可用 ✅

在正常 shell 执行过一次 `dart mcp-server --help`（完成首次编译与安装）后，
用真实 JSON-RPC 探测得到：

```
initialize → serverInfo: {'name': 'dart and flutter tooling', 'version': '1.1.2'}
tools/list → 14 个工具
   analyze_files, dtd, flutter_driver_command, get_runtime_errors, hot_reload,
   hot_restart, lsp, pub, pub_dev_search, read_package_uris, rip_grep_packages,
   roots, vm_service, widget_inspector
```

安装产物位置：`~/Library/Application Support/Dart/install/app-bundles/dart_mcp_server/hosted/1.1.2/bundle/bin/dart_mcp_server`

两个实测要点：

- **必须用 `dart mcp-server` 入口，不要直接执行 bundle 里的二进制**——裸二进制会把自己的
  所在目录当作 Dart SDK，报 `Invalid Dart SDK path: .../bundle`。包装器才能正确传入 SDK 路径。
- **实际暴露 14 个工具，而非文档列出的 24 个**。其余（`dart_fix`、`dart_format`、`run_tests`、
  `launch_app`、`list_devices` 等）默认关闭，且客户端能力不足时服务端会发出
  `notifications/message` 警告（`Client does not support th...`）。

### 5.2 DSH 接线：配置已写入，需重启生效

- 项目覆盖层 `.dsh/cordis.patch.yml` 已修正为可用配置。
- 已并入 **`~/.dsh/profiles/web/cordis.patch.yml`**（用户级、长期生效）。
- 加载顺序：bundle patches → profile patch → `$DSH_HOME/cordis.patch.yml` → `--patch` 覆盖层。

**重启是唯一生效条件**：`--patch` 与 profile patch 都只在启动时应用。
重启 `dsh web` 会终止当前会话，因此该步骤需由使用者主动执行。

不支持"不启动验证"：`dsh --profile web --dump-config` 会在 `prepareProfile` 阶段
**无条件重写** `cordis.yml`（源码注释：防止 Loader 把合成结果回写、导致下次启动重复插入），
因此该命令要求对 profile 目录有写权限，在只读/受限环境下无法用于校验。

### 5.3 沙箱环境特有约束（不代表你本机有问题）

分析用的沙箱禁止写工作区外路径，因此遇到过以下**环境性**失败（非配置问题）：

| 现象 | 原因 |
| --- | --- |
| `PathAccessException: ~/.pub-cache/_temp` | sandbox 禁止写 pub 缓存 |
| `Creation failed: ~/Library/Application Support/Dart/install` | `dart install` 的固定安装路径在工作区外 |
| `Creation failed: ~/.pub-cache/active_roots/...` | MCP server 每次启动都要写此目录 |

若运行环境确实禁止写 `~/.pub-cache`，可给 MCP 条目加 `env.PUB_CACHE` 指向可写目录。
**本项目未添加该覆盖**——默认 `~/.pub-cache` 在正常环境可写，不应把绕行方案固化进配置。

### 5.4 其余限制

- **`dart_mcp_server` 标注为 WIP**（pub.dev 原文：experimental and likely to evolve quickly），
  工具集与开关可能随版本变化。
- **DSH 只桥接 MCP tools**，不支持 resources / prompts。
- **`.dsh/` 与 `.agents/` 未被 `.gitignore` 忽略**：本仓库的 skill 会进入版本控制
  （对团队共享是好事）；若不希望提交，请自行加入 `.gitignore`。
- **1 个官方 skill 的描述会被截断**：`dart-setup-ffi-assets` 的 `description` 长 651 字符，
  超过 DSH `catalogDescriptionMaxLength` 默认上限 500，在目录中仅作截断显示（正文加载不受影响）。
  次长为 `dart-build-cli-app`（488）与 `dart-use-path-package`（484），均在上限内。
- **官方 skill 的 `metadata` 字段**：22/25 个带 `metadata`（含 `model`、`last_modified`），
  DSH 允许该可选字段，校验 27/27 全部通过。
- **直接拷贝方式不会自动更新**：官方推荐 `npx skills update`；若采用拷贝，需按官方仓库变更手动同步。
- **自建 skill 硬编码机器路径**：`.dsh/skills/` 下 2 个 skill 写死了
  `/Users/stephanie/Downloads/flutter_3.47.4`（含版本号），升级 SDK 后会失效。

---

## 6. 参考资料

- DSH skill：[`@deepseek-ai/dsh-tool-skill`](file:///Users/stephanie/.npm/_npx/1e7f6d9597241db0/node_modules/@deepseek-ai/dsh-tool-skill/README.zh.md)、[`@deepseek-ai/dsh-skill-filesystem`](file:///Users/stephanie/.npm/_npx/1e7f6d9597241db0/node_modules/@deepseek-ai/dsh-skill-filesystem/README.zh.md)
- DSH MCP：[`@deepseek-ai/dsh-mcp-client`](file:///Users/stephanie/.npm/_npx/1e7f6d9597241db0/node_modules/@deepseek-ai/dsh-mcp-client/README.zh.md)
- Dart MCP server：<https://pub.dev/packages/dart_mcp_server>
- Flutter MCP 文档：<https://docs.flutter.dev/ai/mcp-server>
- 官方 Flutter skill 仓库：<https://github.com/flutter/skills>（25 个 skill）
- 官方 Dart skill 仓库：<https://github.com/dart-lang/skills>（15 个 skill）
- 官方发布公告：[Introducing Skills for Dart and Flutter](https://flutter.dev/blog/introducing-skills-for-dart-and-flutter)
- 包携带 skill：<https://dart.dev/tools/pub/package-skills>
- Agent Skills 规范：<https://agentskills.io>
