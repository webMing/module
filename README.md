# module — Flutter 生产级模块化架构工作区

一个用 **Dart Pub Workspace + Melos 8** 管理的 Flutter monorepo：业务模块**自注册**进模块系统，模块之间只通过**协议**与**事件**通信，状态、导航、DI、网络各只有一个负责人。

完整设计（含实际 API、差异清单与已知缺口）：[`docs/architecture/MODULAR_ARCHITECTURE.md`](docs/architecture/MODULAR_ARCHITECTURE.md)

---

## 目录结构

```text
module/                              # 工作区根：module_workspace（纯配置宿主，不是应用包）
├── apps/
│   └── main_app/                    # 唯一的应用装配层（含各平台目录，flutter run 在这里）
│       └── lib/
│           ├── main.dart            # 读 DEEP_LINK → Bootstrap → runApp
│           ├── bootstrap.dart       # 唯一的装配点（Composition Root）
│           └── src/app.dart         # ModuleApp：只把路由器交给 CupertinoApp.router
├── packages/
│   ├── core/                        # 11 个核心包，业务无关
│   │   ├── core_model/  core_error/  core_config/  core_logger/
│   │   ├── core_di/     core_storage/  core_session/  core_observability/
│   │   ├── core_network/  core_router/  core_module/
│   ├── features/
│   │   ├── feature_auth/            # 登录 / 验证码登录 / 重置密码
│   │   └── feature_home/            # 登录后落地页
│   └── shared/
│       └── design_system/           # 设计令牌 + 通用 iOS 风格组件
├── docs/
└── pubspec.yaml                     # 声明 workspace 成员 + Melos 脚本
```

## 依赖规则（硬约束）

```text
app ──▶ feature ──▶ core / shared          ✅ 允许
feature ──▶ feature                        ❌ 禁止（只能走协议与事件）
core ──▶ feature                           ❌ 禁止
shared ──▶ feature                         ❌ 禁止
```

每个 feature 的依赖面被限制在 `core` + `shared`，因此**可以整包搬到独立 Git 仓库**。

## 模块系统（自研，不依赖任何模块化框架）

| 角色 | 包 | 职责 |
| --- | --- | --- |
| `AppModule` / `ModuleDescriptor` | `core_module` | 模块契约与身份 |
| `ModuleRegistrar` | `core_module` | 能力注册面板：路由 / 协议 / 依赖 / boot 动作 |
| `ModuleRegistry` | `core_module` | 两阶段 `register` → `boot`，去重、依赖校验、协议冲突检测 |
| `ModuleBus` + `ModuleProtocol` | `core_module` | 模块间**命令**：`moduleBus.open('home://detail?id=7')` |
| `EventBus` | `core_module` | 跨模块**通知**：我发生了事情，不关心谁在听 |
| `RouteDefinition` / `AppRouter` | `core_router` | go_router 装配 + `AppNavigator` 端口 |

`core_module` 是**纯 Dart** 包：路由能力通过 `ModuleContribution` 标记接口由 `core_router` 扩展接入，因此注册表、总线、事件总线都能脱离 Flutter 单测。

一个模块长这样（`feature_home`）：

```dart
class HomeModule implements AppModule {
  const HomeModule();

  @override
  ModuleDescriptor get descriptor => homeModuleDescriptor;

  @override
  void register(ModuleRegistrar registrar) {
    registerHomeRoutes(registrar);          // 路由（core_router 的扩展方法）
    registrar.registerProtocol(const HomeProtocol());  // 协议
  }
}
```

应用侧只做装配与「事件 → 跳转」的反应：

```dart
final registry = ModuleRegistry()
  ..register(const AuthModule())
  ..register(const HomeModule());
registry.boot(locator);                     // 收集能力 → 校验 → 应用依赖

eventBus.subscribe<LoginSucceededEvent>((event) async {
  await observability.setUserId(event.session.account);
  await appRouter.go('/home');              // 模块只宣布，去哪儿由应用决定
});
```

---

## 运行与测试

> ⚠️ 本仓库 `flutter` / `dart` **不在 PATH**。用 SDK 内置的 dart 二进制，
> 不要用 `$SDK_ROOT/bin/dart`（那是会写 `bin/cache/` 的包装脚本）：

```bash
DART=/Users/stephanie/Downloads/flutter_3.47.4/bin/cache/dart-sdk/bin/dart
SDK=/Users/stephanie/Downloads/flutter_3.47.4
```

**只在仓库根执行一次 `pub get`**；子包内单独 `pub get` 会生成遮蔽根配置的
`package_config.json`，使该包退化为独立解析。

```bash
# 依赖解析（唯一入口）
"$DART" pub get

# 全仓库静态分析（Melos 以 --fatal-infos 运行，info 级 lint 也必须为零）
"$DART" run melos --sdk-path "$SDK" analyze

# 全仓库测试
"$DART" run melos --sdk-path "$SDK" test
```

> ⚠️ 在**受限 / 沙箱**环境里，上面两条 melos 命令会失败：Melos 会调用
> `$SDK/bin/dart`（Flutter 包装脚本），而该脚本要写 `$SDK/bin/cache/engine.stamp`
> 与 `engine.realm`，一旦被拒绝就整批报 `Operation not permitted`。
> 这不是代码问题，改用下面的等价直连命令即可：

```bash
# 等价于 melos analyze
"$DART" analyze apps packages

# 等价于 melos test：逐包执行，绕过 flutter 包装脚本
for d in packages/core/* packages/shared/* packages/features/* apps/main_app; do
  (cd "$d" && FLUTTER_ALREADY_LOCKED=true \
    "$DART" "$SDK/bin/cache/flutter_tools.snapshot" test) || echo "FAILED: $d"
done
```

单包测试（受限环境下 flutter 包装脚本会因写 `bin/cache/engine.stamp` 被拒，
用下面这条绕过）：

```bash
(cd packages/features/feature_auth &&
  FLUTTER_ALREADY_LOCKED=true "$DART" "$SDK/bin/cache/flutter_tools.snapshot" test)
```

运行应用：

```bash
cd apps/main_app
"$SDK/bin/flutter" run --dart-define=APP_ENV=development

# 深链与内部协议同源：外部入口直接复用模块协议
"$SDK/bin/flutter" run --dart-define=DEEP_LINK=home://root
```

---

## 认证模块（`packages/features/feature_auth`）

iOS（Cupertino）风格登录模块，所有图标使用 Flutter 内置的 `CupertinoIcons`。

### 模块内部结构

```text
packages/features/feature_auth/
├── lib/
│   ├── feature_auth.dart            # 公开契约：module + protocol + 需被实现的端口
│   ├── testing.dart                 # 测试/演示入口：只导出 FakeAuthService
│   └── src/
│       ├── module/                  # auth_descriptor / auth_events / auth_module
│       ├── protocol/                # auth_protocol（scheme = 'auth'）
│       ├── router/                  # auth_routes
│       ├── presentation/
│       │   ├── pages/               # login_page / reset_password_page
│       │   ├── widgets/             # countdown_code_button / demo_hint
│       │   └── controllers/         # login_controller / reset_password_controller
│       ├── domain/
│       │   ├── entities/            # sms_code_receipt
│       │   ├── repositories/        # auth_repository（抽象端口）
│       │   └── services/            # account/password/sms_code 校验器 + auth_failure
│       └── data/
│           ├── datasources/         # auth_service（端口）/ fake_auth_service
│           └── repositories/        # auth_repository_impl
└── test/                            # 与 src/ 同构镜像
```

**公开面只有两处**：`feature_auth.dart`（模块契约 + 数据源端口）与
`testing.dart`（假实现）。`LoginPage` / Controller / 校验器都是模块私有实现，
外部只能通过 `auth://` 协议或 `/login` 路由到达。

### 校验规则

| 项 | 规则 |
| --- | --- |
| 账号 | 含 `@` 视为邮箱并校验；纯数字视为手机号并校验 `1[3-9]\d{9}`；其余视为昵称，长度 ≤ 30 个字符 |
| 登录密码 | 非空，仅字母 + 数字，长度 ≤ 30（历史密码的最小长度/组合交给服务端判定） |
| 新密码 | 6–30 位，仅字母 + 数字，且必须同时包含字母和数字 |
| 再次确认 | 非空且与新密码一致 |
| 短信验证码 | 6 位数字 |

### 错误提示

数据源通过 `AuthException.code`（`AuthErrorCode`）标明失败原因，Controller
会把提示落到对应输入框，避免只给一句笼统的「账号或密码错误」：

| 场景 | 提示文案 | 展示位置 |
| --- | --- | --- |
| 账号不存在 | 账号不存在，请检查账号是否正确 | 账号输入框下方（描边变红） |
| 密码错误 | 密码错误，请重新输入 | 密码输入框下方（描边变红） |
| 验证码错误 / 失效 | 验证码错误或已失效，请重新获取 | 验证码输入框下方（描边变红） |
| 网络等其他异常 | 登录失败，请稍后重试 | 表单红色横幅 |

> 真实后端若出于防账号枚举考虑不区分「账号不存在 / 密码错误」，返回
> `AuthErrorCode.invalidCredentials` 即可，UI 会退化为表单横幅提示。

### 演示环境（`FakeAuthService`）

- 只有演示账号 `demo` 视为已注册，默认密码 `abc123`；其他账号会提示「账号不存在」；
- 短信验证码固定 `123456`，必须先点「获取验证码」才生效；
- 重置密码会真正改写该账号的密码，可用新密码重新登录；
- 需要更多演示账号时构造 `FakeAuthService(registeredAccounts: {...})` 即可。

### 接入真实后端

实现 `AuthService` 端口，并在 `apps/main_app/lib/bootstrap.dart` 的
`registerDemoInfrastructure` 里替换即可——UI、Controller 与模块装配都不需要改动：

```dart
static void registerDemoInfrastructure(ServiceLocator locator) {
  // 换成实现 AuthService 的 HTTP 数据源
  locator.registerLazySingleton<AuthService>(
    () => HttpAuthService(locator.get<ApiClient>()),
  );
}
```

模块自身只在 `onBoot` 里安装兜底实现，因此**应用注册的实现优先**，测试也能
注入零延迟假实现。

### 状态管理（signals）

全项目使用 [`signals`](https://dartsignals.dev) 做响应式状态，没有 `ChangeNotifier`、
`setState` 或 `provider/riverpod/bloc`：

| 角色 | 用什么 | 说明 |
| --- | --- | --- |
| 可写状态 | `signal(...)` | Controller 直接把 signal 作为公开字段，字段本身就是订阅入口 |
| 派生状态 | `computed(...)` | `isPasswordMode`、`canSendCode`，不重复存一份、不会不同步 |
| UI 订阅 | `SignalBuilder` | **按区域订阅**：账号输入只重建账号框、倒计时每秒只重建验证码按钮 |
| 跨模块会话 | `core_session` 的 `SessionStore` | 登录态是**核心能力**而非某个 feature 的私有状态，否则首页就得依赖登录模块 |
| 依赖注入 | `get_it`（经 `core_di`） | 模块通过 `ModuleRegistrar` 登记自身依赖 |
| 导航 | `go_router`（经 `core_router`） | 路由是状态；Controller 不碰路由，登录成功只广播事件 |

约定（也是刻意的取舍）：

* **分层导入**：只有 View 才 `import 'package:signals/signals_flutter.dart'`（拿到 `SignalBuilder`）；
* **不用 `effect` 做导航 / IO**：跳转、弹窗这类一次性动作留在事件回调里；
* **`Watch` 已废弃**：signals 7.x 统一用 `SignalBuilder`；
* **信号不手动 `dispose()`**：页面级 Controller 的信号不持有外部资源，随页面回收；只有 `Timer` 在 `dispose()` 里取消；
* **订阅会先回调一次当前值**：signals 7 的 `subscribe()` 语义，写断言时要注意。

---

## 设计系统（`packages/shared/design_system`）

统一视觉的地方，页面里不再出现魔法数字与硬编码颜色：

| 令牌 | 内容 |
| --- | --- |
| `AppColors` | 品牌色、品牌渐变、页面渐变、文字三级色、语义色，全部 `resolveFrom(context)` 自动适配深色模式 |
| `AppSpacing` | 4pt 基准间距：`xs 4 / sm 8 / md 12 / lg 16 / xl 20 / xxl 24 / xxxl 32 / huge 40` |
| `AppRadius` / `AppSizes` | 连续圆角 6/10/14/18/22；输入框高 44、主按钮高 52、分段控件高 40 |
| `AppTypography` | `largeTitle 28/w700`、`title 22/w700`、`headline 17/w600`、`body 16`、`callout 15`、`footnote 13/w500`、`caption 12`、`button 17/w600` |
| `AppShadows` | 卡片双层轻阴影、品牌发光、分段滑块阴影，深色模式自动加浓 |

组件：`AppCard` / `AppTextField` / `AppPrimaryButton` / `AppSegmentedControl` /
`AppIconBadge` / `AppStatCard` / `AppFormMessage` / `AppPageBackground`。

## 界面预览

| 页面 | 截图 |
| --- | --- |
| 登录页（重构前） | `docs/ui/login_before.png` |
| 登录页 | `docs/ui/login_after.png` |
| 重置密码页 | `docs/ui/reset_password_after.png` |
| 首页 | `docs/ui/home_after.png` |

## 测试规模

`dart analyze apps packages` → **No issues found!**（含 `--fatal-infos`）

| 包 | 用例 | 包 | 用例 |
| --- | --- | --- | --- |
| `core_module` | 51 | `core_network` | 22 |
| `core_session` | 19 | `core_router` | 18 |
| `core_error` | 12 | `core_logger` | 12 |
| `core_model` | 11 | `core_config` | 11 |
| `core_storage` | 11 | `core_observability` | 11 |
| `core_di` | 7 | `design_system` | 4 |
| `feature_auth` | 93 | `feature_home` | 3 |
| `main_app`（端到端 + 深链） | 5 | **合计** | **290** |

## 已知缺口

| 项 | 现状 |
| --- | --- |
| `core_network` 生产消费方 | 无：演示用 `FakeAuthService`，不发真实请求 |
| `core_storage` 持久化 | 只有内存实现，会话重启即失；接真实持久化需引入存储插件 |
| `shared/common_widgets`、`common_utils` | 未创建，等出现跨模块共享的非设计系统代码再建 |
| `very_good_analysis` | 已声明未启用，当前生效的是 `flutter_lints` |
| feature 独立 Git 仓库 | 未拆分；依赖面已收敛，具备整包搬运条件 |

详见 [`docs/architecture/MODULAR_ARCHITECTURE.md` 附录 A](docs/architecture/MODULAR_ARCHITECTURE.md#附录-a实现现状as-built)。
