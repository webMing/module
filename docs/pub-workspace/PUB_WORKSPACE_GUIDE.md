# Pub Workspace 知识整理（基于 Flutter 3.47.x / Dart 3.13）

> 环境基线：本项目实际使用 **Flutter stable 3.47.4**（`.dart_tool/version`）、**Dart 3.13.3**，
> 根 `pubspec.lock` 的 SDK 约束为 `dart: ">=3.13.3 <4.0.0"`、`flutter: ">=3.44.0"`。
> 本文所有版本能力说明均以 Dart 3.13 为准；若你的 SDK 更低，请对照文中「版本要求」标注。
>
> 官方依据：[Pub workspaces (monorepo support)](https://dart.dev/tools/pub/workspaces)、
> [Announcing Dart 3.13](https://dart.dev/blog/announcing-dart-3-13)、
> [Announcing Dart 3.6](https://dart.dev/blog/announcing-dart-3-6)。

---

## 1. Pub Workspace 是什么

Pub Workspace 是 Dart 官方在 **Dart 3.6.0** 引入的多包（monorepo）支持能力，
由 `dart pub` / `flutter pub` 原生实现，**不属于 Melos，也不需要任何第三方工具**。

它要解决的问题：传统 monorepo 中每个包各自拥有 `pubspec.lock` 与
`.dart_tool/package_config.json`，导致：

- 每个包都要单独执行一次 `pub get`；
- 各包锁定的依赖版本可能不一致，切换目录时行为漂移；
- 在 IDE 中打开仓库根目录时，分析器为每个包建立独立的 analysis context，内存占用高。

Pub Workspace 的做法是：**整仓库共享唯一一次依赖解析**。

| 维度 | 传统多包（无 workspace） | Pub Workspace |
| --- | --- | --- |
| `pub get` | 每个包各执行一次 | 仓库内任意目录执行一次 |
| `pubspec.lock` | 每包一个 | 仅根目录一个 |
| `package_config.json` | 每包一个 | 仅根目录 `.dart_tool/` 一个 |
| 依赖版本 | 各包可不同 | 全局唯一，冲突必须当场解决 |
| 分析器上下文 | 每包一个，内存高 | 共享一个 |
| 本地包互相引用 | 需 `path` 依赖或 `dependency_overrides` | 自动解析为工作区内本地包 |

> ⚠️ 关键取舍：**单版本解析会提高依赖冲突的概率**。Dart 不允许同一包出现多个版本，
> 所以一旦 `A` 要 `dio ^5` 而 `B` 要 `dio ^4`，整个工作区就无法解析。
> 官方认为这是「有用的特性」：它迫使你在工作区内提前解决不兼容，而不是等到
> 组合使用时才暴露。反过来说，**不适合把互不相关、依赖约束长期互斥的项目塞进同一个 workspace**。

---

## 2. 版本要求与能力时间线

| 能力 | 最低版本 | 本项目（Dart 3.13.3） |
| --- | --- | --- |
| Pub Workspace 基础支持（`workspace:` / `resolution: workspace`） | Dart **3.6.0** | ✅ |
| `workspace:` 支持 **glob 通配符**（如 `packages/*`） | Dart **3.11** | ✅ |
| `dart pub workspace list` 子命令 | Dart **3.13** | ✅ |
| 嵌套 workspace（成员包自身再声明 `workspace:`） | Dart 3.6+（随基础能力提供，官方文档当前收录） | ✅ |

硬性约束：

- **根包与所有工作区成员的 SDK 约束都必须 ≥ `^3.6.0`**；
  版本不达标时 `pub get` 直接报错。
- 该约束只作用于**工作区成员自身**，不影响你的第三方依赖（依赖可以要求更低的 SDK）。
- Flutter 侧无需额外开关，`flutter pub get` 与 `dart pub get` 走同一套解析逻辑。

---

## 3. 目录结构对比

**迁移前**（每包一套锁文件）：

```text
/
├── packages/
│   ├── shared/
│   │   ├── pubspec.yaml
│   │   ├── pubspec.lock                        # 冗余
│   │   └── .dart_tool/package_config.json      # 冗余
│   └── client_package/
│       ├── pubspec.yaml
│       ├── pubspec.lock
│       └── .dart_tool/package_config.json
└── (无根 pubspec.yaml)
```

**迁移后**（单次共享解析）：

```text
/
├── pubspec.yaml                # 根：声明 workspace 成员
├── pubspec.lock                # 唯一锁文件
├── .dart_tool/
│   └── package_config.json     # 唯一共享 package config
└── packages/
    ├── shared/
    │   └── pubspec.yaml        # 含 resolution: workspace
    └── client_package/
        └── pubspec.yaml        # 含 resolution: workspace
```

---

## 4. 完整配置清单

### 4.1 根 `pubspec.yaml`

```yaml
name: my_workspace          # 根目录不是包时可写 name: _ 并 publish_to: none
publish_to: none

environment:
  sdk: ^3.13.0              # 必须 >= ^3.6.0

workspace:
  - packages/shared
  - packages/client_package
  # Dart 3.11+ 可用通配符，自动纳入 packages/ 下所有含 pubspec.yaml 的目录：
  # - packages/*
```

要点：

- `workspace` 列出的路径**相对于根 pubspec.yaml**，只写目录，不写 `pubspec.yaml`。
- 根目录本身也是 Flutter/Dart 包时，**不需要**在 `workspace:` 里列自己；
  根包天然参与解析。若使用 Melos，`useRootAsPackage: true` 是让 Melos 把根包也纳入其管理范围（见 §15）。
- 根目录**可以**同时是 Flutter 应用（本项目即是：根 `module` 是应用，`packages/home`、`packages/login` 是成员）。

### 4.2 每个子包 `pubspec.yaml`

```yaml
name: shared
publish_to: none

environment:
  sdk: ^3.13.0        # 同样必须 >= ^3.6.0

resolution: workspace  # ← 关键标记，缺这一行 pub get 会报错

dependencies:
  flutter:
    sdk: flutter
```

要点：

- `resolution: workspace` 是**必需**的；漏写会被 pub 明确拒绝并提示。
- 子包**不要**保留 `pubspec.lock`，也不要把 `.dart_tool/package_config.json` 提交进仓库。
- 子包之间互相依赖时，**按正常的版本约束声明**即可，无需 `path:`，更不要用 `dependency_overrides` 做联调：

  ```yaml
  # packages/client_package/pubspec.yaml
  dependencies:
    shared: ^2.3.0
  ```

  - 在工作区内解析时：**始终优先使用本地 `shared`**（即使 `shared` 是 hosted 包），
    但本地版本号**仍须满足约束** `^2.3.0`，否则解析失败。
  - 该包被发布到 pub.dev 后、被外部以普通依赖方式消费时：**回退到原始来源（hosted）**，
    外部用户拿到的是 pub.dev 上的 `shared`，而不是本地路径。这是 workspace 的重要语义——
    它不改变发布产物的依赖来源。

---

## 5. 初始化与迁移步骤

从旧的多包仓库迁移：

1. 在仓库根创建 `pubspec.yaml`，写入 `environment.sdk`（≥ `^3.6.0`）与 `workspace:` 成员列表。
2. 逐个修改成员包 `pubspec.yaml`：SDK 约束提升到 `^3.6.0` 以上，并加上 `resolution: workspace`。
3. 在仓库内**任意目录**执行一次 `dart pub get`（Flutter 项目用 `flutter pub get`）。

第 3 步 pub 会自动完成：

- 在根 `pubspec.yaml` 旁生成**唯一**的 `pubspec.lock`，
  内容包含所有成员的 `dependencies` 与 `dev_dependencies` 的合并解析结果；
- 生成根 `.dart_tool/package_config.json`，把包名映射到文件位置（本地成员指向仓库内路径）；
- **删除**其他位置残留的 `pubspec.lock` 与 `.dart_tool/package_config.json`。

---

## 6. 「Stray files」陷阱：迁移时最容易踩的坑

官方把迁移残留物称为 stray files，有两类行为必须知道：

### 6.1 残留的锁文件会被自动删除

`pub get` 会删除「根目录到任意工作区成员之间（含成员目录）」所有目录里的
`pubspec.lock` 和 `.dart_tool/package_config.json`。
它们是「影子文件」，会覆盖根目录的解析结果，所以 pub 主动清理——这是正常行为，不是 bug。

### 6.2 中间目录的「野生 pubspec.yaml」会直接导致解析失败

如果根目录与成员包之间的某个目录存在一个**不属于工作区**的 `pubspec.yaml`，`pub get` 会**报错并停止**：

```text
/
├── packages/
│   ├── foo/
│   │   └── pubspec.yaml    # 工作区成员
│   └── pubspec.yaml        # ← 不属于工作区 => 解析失败
└── pubspec.yaml            # 根：workspace: ['packages/foo']
```

原因：解析这个中间 `pubspec.yaml` 会生成一个遮蔽根配置的
`.dart_tool/package_config.json`。解决办法只有两个：把它加进 `workspace:` 成员列表，或把它移出该目录。

> 排查口诀：**根到成员之间的每一层目录，要么只有成员包，要么没有 pubspec.yaml。**

---

## 7. 子包下的 `.dart_tool/` 为什么存在（常见混淆点）

> ⚠️ **先纠正一个广泛存在的误解**
>
> 「子包目录下出现了 `.dart_tool/`」**不代表** workspace 没有生效。
> 真正要检查的不是「有没有 `.dart_tool` 目录」，而是「里面有没有
> `package_config.json`（以及旁边有没有 `pubspec.lock`）」。

### 7.1 清理的边界：官方只保证删除两个文件

官方文档对 stray files 的原话是：`pub get` 会删除根目录到成员之间（含成员目录）的
**`pubspec.lock`** 和 **`.dart_tool/package_config.json`**。
它**从未**承诺「子包不会出现 `.dart_tool` 目录」——因为 Flutter 工具、pub 自身和
Melos 在包目录内执行时，必然要向该目录写入辅助文件。

| 子包中的路径 | 是否应该存在 | 原因 |
| --- | --- | --- |
| `pubspec.lock` | ❌ **不应存在** | 会遮蔽根锁文件，导致版本漂移 |
| `.dart_tool/package_config.json` | ❌ **不应存在** | 会遮蔽根共享解析，退化为独立解析 |
| `.dart_tool/pub/workspace_ref.json` | ✅ 正常，**属 workspace 机制本身** | pub 写入的重定向标记，显式指向工作区根 |
| `.dart_tool/package_graph.json` | ✅ 正常 | 该包视角的依赖图，供 Melos / build_runner 等工具使用 |
| `.dart_tool/version` | ✅ 正常 | Flutter 工具写入的 SDK 版本号，用于判断是否需要重建 |

### 7.2 实际形态

以典型 workspace 为例，子包内会出现如下辅助文件（**没有 `package_config.json`**）：

```text
packages/home/.dart_tool/
├── version                    # Flutter SDK 版本，如 "3.47.4"
├── package_graph.json         # { "roots": ["home"], "packages": [...] }
└── pub/
    └── workspace_ref.json     # { "workspaceRoot": "../../../.." }
```

其中 `workspace_ref.json` 是最有价值的信号：它由 pub 生成，
**明确把「该包属于哪个工作区根」记录下来**。看到它就说明 pub 已按 workspace 模式处理过这个包。

### 7.3 判定 workspace 是否生效的正确方法

不要靠「目录里有什么」来猜，按下面顺序验证：

```bash
# 1) 唯一解析文件在根，且只此一份
find . -name package_config.json -not -path './build/*'
find . -name pubspec.lock        -not -path './build/*'
# 期望：各只有根目录的一份

# 2) 根配置把成员包指向仓库内本地路径
grep -o '"name": "home"[^}]*' .dart_tool/package_config.json

# 3) 子包内有重定向标记
cat packages/home/.dart_tool/pub/workspace_ref.json

# 4) 官方命令列出成员（Dart 3.13+）
dart pub workspace list
```

四条同时满足即为健康；其中**第 1 条是硬判据**。

### 7.4 真正会导致问题的操作

| 操作 | 后果 |
| --- | --- |
| 在子包目录内直接执行 `pub get` | 生成 `packages/<pkg>/.dart_tool/package_config.json`，**遮蔽**根配置，该包退化为独立解析，从此版本可能与工作区不一致 |
| 用 §13 的 `pubspec_overrides.yaml` 做单包校验后忘记删除 | 下一次在子包内运行命令时重新生成遮蔽文件，问题复现 |
| 把 `.dart_tool/` 从 `.gitignore` 移除并提交 | 把本地解析状态带入仓库，团队成员之间互相覆盖 |

正确习惯：**只在仓库根执行 `pub get`**；需要单包校验时按 §13 操作，并在校验后删除
`pubspec_overrides.yaml`，再回根目录执行一次 `pub get` 让工作区解析复位。

---

## 9. Glob 通配符（Dart 3.11+）

```yaml
workspace:
  - packages/*
```

- 自动纳入 `packages/` 下**所有含 `pubspec.yaml` 的子目录**，新增包无需再改根 pubspec。
- 适合包数量多或增长快的仓库；包数量少且固定的项目，显式列举可读性更好。
- Dart 3.11 之前的 SDK 不支持，必须写显式路径。

---

## 10. 嵌套 Workspace

large repo 可以分层组织：**成员包自己也可以声明 `workspace:`**。

```yaml
# packages/server/pubspec.yaml
name: server

resolution: workspace     # 它本身是根工作区的成员
environment:
  sdk: ^3.13.0

workspace:                # 同时它是子工作区的宿主
  - auth
  - api
```

```yaml
# packages/server/auth/pubspec.yaml
name: auth

resolution: workspace
environment:
  sdk: ^3.13.0
```

规则：

- 根 `pubspec.yaml` **只需列出 `packages/server`**；
  pub 会顺着 `server` 的 `workspace` 字段递归发现 `auth`、`api`。
- 无论嵌套多少层，最终**仍然只有一次共享解析**（唯一 lock 文件 + 唯一 package config）。
- 嵌套只是**组织手段**，不产生独立解析域。

---

## 11. 依赖覆盖（dependency_overrides）在工作区中的规则

- 所有成员的 `dependency_overrides` **都会被尊重**；
- 除了写在 `pubspec.yaml`，也可以在任意成员的 `pubspec.yaml` 旁放置 `pubspec_overrides.yaml`；
- **同一个包在整个工作区只能被覆盖一次**——重复覆盖会报错；
- 因此官方建议：**把 `dependency_overrides` 统一收敛到根 `pubspec.yaml`**，避免分散导致冲突，也便于一眼看清全局临时覆盖。

---

## 12. 在指定包中执行命令

`dart pub add`、`dart pub publish` 等命令作用于「当前包」。两种方式指定目标：

```bash
# 方式一：切换目录
cd packages/client_package && dart pub publish

# 方式二：-C 指定目录（推荐，脚本友好，不用来回 cd）
dart pub -C packages/client_package publish
```

对 Flutter 项目同理：

```bash
flutter pub -C packages/home add dio
```

---

## 13. 临时让某个成员脱离工作区解析

有时需要**单独校验某个成员的依赖约束是否自洽**（例如准备发布前）。
在该成员目录放一个 `pubspec_overrides.yaml`，把 `resolution` 置空即可：

```yaml
# packages/client_package/pubspec_overrides.yaml
resolution:
```

此后在该目录内执行 `dart pub get`，会生成**独立的**解析
（自己的 `pubspec.lock` + `.dart_tool/package_config.json`）。
校验完成后删除该文件，回到工作区解析。

> ⚠️ `pubspec_overrides.yaml` 是本地覆盖文件，通常应加入 `.gitignore`，避免误提交后破坏团队的工作区解析。

---

## 14. 列出工作区成员（Dart 3.13+）

```bash
dart pub workspace list
```

输出形如：

```text
Package         Path
_               ./
client_package  packages/client_package/
server_package  packages/server_package/
shared          packages/shared/
```

用途：确认 `pub get` 真正识别了哪些成员。**「成员没被识别」是多包仓库最高频的问题**，
应优先用它而不是猜测。Flutter 项目同样可用 `flutter pub workspace list`。

---

## 15. 与 Melos 8 的关系（本项目正在使用）

两者**不是替代关系中的对立面**，而是分层：

| 层 | 负责方 | 职责 |
| --- | --- | --- |
| 依赖解析层 | **Pub Workspace**（pub 原生） | 唯一 lock、唯一 package config、本地包互相引用、IDE 单分析上下文 |
| 任务编排层 | **Melos**（可选） | 批量 analyze/test/format、包筛选（`--scope`/`--diff`/`--depends-on`）、`exec` 并发、版本发布与 CHANGELOG |

必要性说明：Pub Workspace 只解决「解析」，**不提供**「一次对 N 个包执行命令」的编排能力。
Melos 8 正是建立在 Pub Workspace 之上：

- Melos 8 **不再读取 `melos.yaml`** 的包路径配置，成员完全来自根 `pubspec.yaml` 的 `workspace:`
  （Melos 7 及更高版本即如此）；
- 因此脚本配置写在根 `pubspec.yaml` 的 `melos.scripts` 下（本项目即采用此写法）；
- `useRootAsPackage: true` 表示根目录本身也是包，要一并纳入 Melos 的管理与筛选范围；
- 自定义脚本**不要**与内置命令同名（`bootstrap`、`analyze`、`test`、`format`），
  同名会遮蔽内置命令并可能递归调用自身。

本项目根 `pubspec.yaml` 的现状（供对照）：

```yaml
workspace:
  - packages/home
  - packages/login

melos:
  useRootAsPackage: true
  scripts:
    get:          { run: dart pub get }
    check:        { run: dart run melos analyze && dart run melos test }
    format:check: { run: dart run melos format --set-exit-if-changed }
    format:fix:   { run: dart run melos format --output write }
```

> 补充：本项目根 `workspace:` 用的是显式路径。因为 SDK 已是 Dart 3.13.3（≥ 3.11），
> 也可以改成 `packages/*`，新增包时无需再改根 pubspec。

更完整的 Melos 用法见同仓库 `docs/melos-workspace-migration/MELOS_USAGE_GUIDE.md`。

---

## 16. IDE 与工具行为

- **分析上下文合并**：这是 workspace 的主要收益之一。IDE 打开仓库根目录时只有一个 analysis context，
  大仓库内存占用显著下降。若发现 IDE 仍按包分裂上下文，通常是成员没被识别（见 §14）。
- **IDE 需重新解析**：修改 `workspace:` 或 `resolution:` 后，先跑一次 `pub get`，再让 IDE 重新加载 Dart 项目，
  否则会出现「本地包找不到」的假错误。
- **`.idea/` / `.iml`**：Melos 的 `bootstrap` 会生成 JetBrains 工作区文件；
  这类文件属本地产物，通常不应提交（本仓库 `.gitignore` 已忽略 `.idea/` 与 `*.iml`）。
- **Widget Preview / 工具脚手架**：`flutter` 生成的预览脚手架（如 `.widget_preview/`）是**独立 pubspec**，
  它用 `path:` 依赖指向你的工作区包，因此**不属于**工作区成员。
  它绝不能位于根与成员之间的目录链上（否则触发 §6.2），且其 `pubspec.yaml` 里的绝对路径换机后需重新生成。

---

## 17. 常用命令速查

| 目标 | 命令 | 备注 |
| --- | --- | --- |
| 解析整个工作区 | `dart pub get` / `flutter pub get` | 仓库内任意目录执行一次即可 |
| 列出工作区成员 | `dart pub workspace list` | Dart 3.13+ |
| 在指定包执行 pub 命令 | `dart pub -C <dir> <cmd>` | 免 cd |
| 给指定包加依赖 | `flutter pub -C packages/home add dio` | 自动写入该包 pubspec 并重新解析 |
| 单包独立校验 | 放 `pubspec_overrides.yaml`（`resolution:` 空）后 `pub get` | 用完删除 |
| 检查依赖新版本 | `dart pub outdated` | 报的是工作区合并后的视图 |
| 工作区级分析/测试/格式化 | `melos analyze` / `test` / `format` | 需 Melos，见 §15 |

---

## 18. CI 建议

工作区让 CI 步骤显著简化——**只需一次 pub get**：

```bash
# 1) 一次解析（根目录执行）
flutter pub get            # 纯 Dart 包项目用 dart pub get

# 2) 质量门禁（二选一）
#    方案 A：仅用 pub + 原生工具
dart format --set-exit-if-changed .
dart analyze
dart test                  # 注意：默认只跑当前包的测试，跨包需遍历或改用 Melos
flutter test

#    方案 B：使用 Melos（推荐，多包场景）
dart run melos bootstrap
dart run melos format --set-exit-if-changed
dart run melos analyze
dart run melos test
```

PR 增量检查（Melos 提供的能力，Pub Workspace 原生没有）：

```bash
dart run melos format --set-exit-if-changed --diff origin/main
dart run melos analyze --diff origin/main --include-dependents
dart run melos test    --diff origin/main --include-dependents
```

CI 注意事项：

- **不要**在 CI 中对每个包分别 `pub get`，那是旧模式；工作区一次解析即可。
- 依赖缓存以**根 `pubspec.lock`** 为 key；同时确保子包目录下**不存在**锁文件，否则缓存失效逻辑会错乱。
- `--include-dependents` 在共享包变更时尤其重要：能自动把下游包纳入回归测试。

---

## 19. 故障排查对照表

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `pub get` 报 SDK 约束不满足 | 某成员 `environment.sdk` 低于 `^3.6.0` | 提升该包 SDK 约束 |
| 报错提示缺少 `resolution` | 成员缺 `resolution: workspace` | 补上该行 |
| `pub get` 报错涉及某个中间 `pubspec.yaml` | 该 pubspec 不属于工作区（§6.2） | 加入 `workspace:` 或移出目录链 |
| 子包目录里又冒出 `pubspec.lock` / `package_config.json` | 有人在子包内单独执行过 `pub get`（常见于单包独立校验后忘删 overrides） | 删除该文件，回到根执行一次 `pub get`；检查 `pubspec_overrides.yaml` 是否残留 |
| 看到子包下有 `.dart_tool/`，以为 workspace 没生效 | **误判**：该目录及其 `pub/workspace_ref.json`、`package_graph.json`、`version` 都是正常辅助文件（§7） | 改用硬判据：只检查子包内是否存在 `package_config.json` 或 `pubspec.lock`；两者都没有即为健康 |
| 改了 `workspace:` 但成员没生效 | pub 未重新解析 / IDE 未重载 | 重新 `pub get`，用 `dart pub workspace list` 确认，再重载 IDE |
| 报「同一包被覆盖多次」 | 多个成员各自写了同一 `dependency_overrides` | 收敛到根 pubspec，只保留一处 |
| `melos list` 说找不到包 | 参数仍是 Melos 7 的旧 `melos.yaml` 写法，或成员未声明 `resolution: workspace` | 改为根 `pubspec.yaml` 的 `workspace:`；确认每个成员有 `resolution: workspace` |
| 本地包版本号对不上导致解析失败 | 依赖约束与本地包 `version` 不匹配 | 工作区虽用本地代码，**约束仍需满足**；对齐版本号 |
| IDE 仍为每个包建立独立上下文 | 工作区未真正生效 | 同「成员没生效」处理 |

---

## 20. 本项目现状核对

实测结果（Flutter 3.47.4 / Dart 3.13.3）：

| 检查项 | 结果 |
| --- | --- |
| 根 `pubspec.yaml` 声明 `workspace:` | ✅ `packages/home`、`packages/login` |
| 成员 `resolution: workspace` | ✅ 两个成员均有 |
| 成员 SDK 约束 ≥ 3.6.0 | ✅ `^3.13.3` |
| 唯一 lock 文件 | ✅ 仅根 `pubspec.lock`（全仓库 `find` 仅 1 个） |
| 子包无 stray 锁文件 | ✅ `packages/home/pubspec.lock`、`packages/login/pubspec.lock` 均不存在 |
| 子包 `.dart_tool/` 辅助文件 | ✅ 存在且正常：`version`(3.47.4)、`package_graph.json`、`pub/workspace_ref.json`（`workspaceRoot: ../../../..`）；**无** `package_config.json`（见 §7） |
| 共享 package config 指向本地包 | ✅ 仅根 `.dart_tool/package_config.json`（pub 3.13.3 生成，93 个包）：`module → ../`、`home → ../packages/home`、`login → ../packages/login` |
| 根到成员之间无野生 pubspec | ✅ 仅有 `packages/` 一层目录 |
| 可用 glob 简化成员列表 | 🔸 可改为 `packages/*`（SDK 已满足 ≥ 3.11） |
| `.widget_preview/` 是否为成员 | ❌ 不是（独立 pubspec + `path:` 依赖），未污染成员链，符合预期 |

结论：本项目的 Pub Workspace 配置**完全正确且已生效**，当前结构可以直接用于日常开发。

---

## 21. 最佳实践清单

1. **根 pubspec 只做两件事**：声明工作区成员、放置跨包统一工具（Melos、lint、CI 入口）。
2. **新增包的标准动作**（两步都别省）：在根 `workspace:` 加路径 + 在新包写 `resolution: workspace`；然后 `pub get`。
3. **只在根执行 `pub get`**；永远不要在子包目录内单独 `pub get`（除非是 §13 的临时校验，且用完清理）。
4. **不要提交**任何子包的 `pubspec.lock` / `.dart_tool/`；把 `pubspec_overrides.yaml` 加入 `.gitignore`。
5. **`dependency_overrides` 只写在根**，保持全局唯一。
6. **共享包的消费方按正常版本约束声明**，不要用 `path:` 或 overrides 来「假装联调」。
7. **依赖冲突当场解决**：workspace 的价值就在于让不兼容提前暴露，不要靠临时 override 长期压制。
8. **成员包 SDK 约束保持与根一致**，避免「根能解析、某个包单独校验失败」的分裂状态。
9. **区分「解析」与「编排」**：解析交给 pub，批量任务交给 Melos；不要用自定义脚本重复实现 pub 的职责。
10. **迁移后立刻验证**：`dart pub workspace list` 确认成员齐全，再 `melos analyze && melos test` 确认全绿。

---

## 22. 参考资料

- [Pub workspaces (monorepo support) — dart.dev](https://dart.dev/tools/pub/workspaces)（本文主要依据）
- [Announcing Dart 3.6](https://dart.dev/blog/announcing-dart-3-6)：Pub Workspace 首次引入
- [Announcing Dart 3.13](https://dart.dev/blog/announcing-dart-3-13)：`dart pub` 新增 workspace 命令
- [Pubspec file 参考](https://dart.dev/tools/pub/pubspec)：`resolution`、`workspace` 字段定义
- [Dependencies 参考](https://dart.dev/tools/pub/dependencies)：版本约束与 override 语义
- [What not to commit — dart.dev](https://dart.dev/tools/pub/private-files)：锁文件与本地文件提交约定
- [Melos 官方仓库](https://github.com/invertase/melos)：任务编排层
- 本仓库 `docs/melos-workspace-migration/`：Melos 8 迁移记录与使用指南
