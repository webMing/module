# module

A new Flutter project.

## Getting Started


##### 依赖的安装包

flutter pub add go_router
flutter pub add signals
flutter pub add get_it
flutter pub add dio
flutter pub add freezed_annotation
flutter pub add json_annotation



flutter pub add --dev melos
flutter pub add --dev freezed
flutter pub add --dev json_serializable
flutter pub add --dev very_good_analysis


## 登录模块（packages/login）

iOS（Cupertino）风格登录模块，所有图标均使用 Flutter 内置的 `CupertinoIcons`。

### 目录结构

```
packages/ui_kit/lib/                  # 共享设计系统
├── ui_kit.dart
└── src/
    ├── tokens/                     # app_colors / app_spacing / app_typography
    └── widgets/                    # AppCard / AppTextField / AppPrimaryButton /
                                    # AppSegmentedControl / AppIconBadge /
                                    # AppStatCard / AppFormMessage / AppPageBackground

packages/login/lib/
├── login.dart                      # 对外 barrel
└── src/
    ├── domain/                     # 校验规则与领域模型
    │   ├── models/auth_session.dart
    │   └── validators/             # account / password / sms_code
    ├── data/                       # AuthService(抽象) + FakeAuthService + AuthRepository
    └── ui/
        ├── core/widgets/           # 验证码倒计时 / 演示提示条
        └── features/
            ├── login/              # LoginPage：默认密码登录，可切换验证码登录
            └── reset_password/     # ResetPasswordPage：验证码 + 新密码 + 再次确认
```

首页在 `packages/home`，根应用 `lib/main.dart` 用 `CupertinoApp.router` +
`go_router` 串联：`/login`（默认）→ `/reset-password` / `/home`，依赖用 `get_it` 注册。

### 界面预览

| 页面 | 截图 |
| --- | --- |
| 登录页（重构前） | `docs/ui/login_before.png` |
| 登录页 | `docs/ui/login_after.png` |
| 重置密码页 | `docs/ui/reset_password_after.png` |
| 首页 | `docs/ui/home_after.png` |

### 设计系统（packages/ui_kit）

统一视觉的地方，页面里不再出现魔法数字与硬编码颜色：

| 令牌 | 内容 |
| --- | --- |
| `AppColors` | 品牌色（systemBlue）、品牌渐变、页面渐变、文字三级色、语义色（危险/成功/警告/信息），全部 `resolveFrom(context)` 自动适配深色模式 |
| `AppSpacing` | 4pt 基准间距：`xs 4 / sm 8 / md 12 / lg 16 / xl 20 / xxl 24 / xxxl 32 / huge 40` |
| `AppRadius` / `AppSizes` | 连续圆角 6/10/14/18/22；输入框高 44、主按钮高 52、分段控件高 40、表单最大宽 420 |
| `AppTypography` | `largeTitle 28/w700`、`title 22/w700`、`headline 17/w600`、`body 16`、`callout 15`、`subheadline 15/w500`、`footnote 13/w500`、`caption 12`、`button 17/w600`、`metric 22/w700` |
| `AppShadows` | 卡片双层轻阴影、品牌发光、分段滑块阴影，深色模式自动加浓 |

组件层面：输入框有聚焦描边 + 柔光、错误描边 + 行内提示；主按钮为品牌渐变 + 发光 +
按下反馈；分段控件为带阴影的滑动白块；卡片与徽章使用 iOS 连续圆角（squircle）。

### 校验规则

| 项 | 规则 |
| --- | --- |
| 账号 | 含 `@` 视为邮箱并校验；纯数字视为手机号并校验 `1[3-9]\d{9}`；其余视为昵称，长度 ≤ 30 个字符 |
| 登录密码 | 非空，仅字母 + 数字，长度 ≤ 30（历史密码的最小长度/组合交给服务端判定） |
| 新密码 | 6–30 位，仅字母 + 数字，且必须同时包含字母和数字 |
| 再次确认 | 非空且与新密码一致 |
| 短信验证码 | 6 位数字 |

### 状态管理（signals）

全项目使用 [`signals`](https://dartsignals.dev) 做响应式状态，没有 `ChangeNotifier`、
`setState` 或 `provider/riverpod/bloc`：

| 角色 | 用什么 | 说明 |
| --- | --- | --- |
| 可写状态 | `signal(...)` | ViewModel 直接把 signal 作为公开字段（`account`、`mode`、`isSubmitting`…），字段本身就是订阅入口 |
| 派生状态 | `computed(...)` | `isPasswordMode`、`canSendCode`，不重复存一份、不会不同步 |
| UI 订阅 | `SignalBuilder` | **按区域订阅**：账号输入只重建账号框、倒计时每秒只重建验证码按钮、提交中只重建按钮 |
| app 级会话 | `signal<AuthSession?>` | 在 `_ModuleAppState` 中承载登录态，路由 builder 用 `SignalBuilder` 订阅，不再 `setState` |
| 依赖注入 | `get_it` | 只注入 `AuthService` / `AuthRepository`，ViewModel 由页面持有 |
| 导航 | `go_router` + 页面回调 | 路由是状态；ViewModel 不碰路由，登录成功由页面回调触发跳转 |

约定（也是刻意的取舍）：

* **分层导入**：ViewModel 只 `import 'package:signals/signals.dart'`（纯 Dart 核心），
  只有 View 才 `import 'package:signals/signals_flutter.dart'`（拿到 `SignalBuilder`）；
* **不用 `effect` 做导航 / IO**：`effect` 只在需要「状态变化的副作用」时才合适，
  跳转、弹窗这类一次性动作留在事件回调里，避免响应式图里出现难以追踪的重复触发；
* **`Watch` 已废弃**：signals 7.x 推荐 `SignalBuilder`（本项目统一用它）；
* **信号不手动 `dispose()`**：页面级 ViewModel 的信号不持有外部资源，随页面一起回收，
  `SignalBuilder` 卸载时会自动退订；只有 `Timer` 在 `dispose()` 里显式取消；
* signals 内置相等性判断：写入相同值不会通知订阅者（已有测试守护）。

### 错误提示

数据源通过 `AuthException.code`（`AuthErrorCode`）标明失败原因，ViewModel 会把提示
落到对应的输入框，避免只给一句笼统的「账号或密码错误」：

| 场景 | 提示文案 | 展示位置 |
| --- | --- | --- |
| 账号不存在 | 账号不存在，请检查账号是否正确 | 账号输入框下方（描边变红） |
| 密码错误 | 密码错误，请重新输入 | 密码输入框下方（描边变红） |
| 验证码错误 / 失效 | 验证码错误或已失效，请重新获取 | 验证码输入框下方（描边变红） |
| 网络等其他异常 | 登录失败，请稍后重试 | 表单红色横幅 |

> 真实后端若出于防账号枚举考虑不区分「账号不存在 / 密码错误」，返回
> `AuthErrorCode.invalidCredentials` 即可，UI 会退化为表单横幅提示。

### 演示环境（本地假实现 FakeAuthService）

- 只有演示账号 `demo` 视为已注册，默认密码 `abc123`；其他账号会提示「账号不存在」；
- 短信验证码固定 `123456`，必须先点「获取验证码」才生效；
- 重置密码会真正改写该账号的密码，可用新密码重新登录；
- 需要更多演示账号时构造 `FakeAuthService(registeredAccounts: {...})` 即可。

接入真实后端时，实现 `AuthService` 并在 `lib/main.dart` 的
`configureDependencies()` 中替换注册即可，UI 与 ViewModel 无需改动。

### 测试

```bash
# 仓库根执行一次依赖解析
dart pub get

# 静态分析（本仓库 flutter/dart 不在 PATH，用 SDK 内置 dart）
$DART analyze lib test packages/login packages/home packages/ui_kit

# 单包测试
(cd packages/login && $DART run melos --sdk-path "$SDK_ROOT" test)
```

> 受限环境下 `bin/flutter` 包装脚本会写 SDK 的 `bin/cache/engine.stamp` 而被拒，
> 可改用：`FLUTTER_ALREADY_LOCKED=true $DART "$SDK_ROOT/bin/cache/flutter_tools.snapshot" test`。

测试规模：`ui_kit` 4 · `login` 93 · `home` 3 · 根应用端到端 3，共 **103 个用例**。


