/// 登录模块：账号密码登录、短信验证码登录、重置密码。
///
/// * 领域层：[AccountValidator]、[PasswordValidator]、[SmsCodeValidator]、
///   [AuthSession]；
/// * 数据层：[AuthService]（抽象）、[FakeAuthService]（可替换的本地实现）、
///   [AuthRepository]；
/// * UI 层：[LoginPage]（默认密码登录，可切换验证码登录）、
///   [ResetPasswordPage]（短信验证码 + 新密码 + 确认密码）。
///
/// 通用视觉组件（输入框、主按钮、卡片、分段控件等）来自 `package:ui_kit`。
library;

export 'src/data/repositories/auth_repository.dart';
export 'src/data/services/auth_service.dart';
export 'src/data/services/fake_auth_service.dart';
export 'src/domain/models/auth_session.dart';
export 'src/domain/validators/account_validator.dart';
export 'src/domain/validators/password_validator.dart';
export 'src/domain/validators/sms_code_validator.dart';
export 'src/ui/core/widgets/countdown_code_button.dart';
export 'src/ui/core/widgets/demo_hint.dart';
export 'src/ui/features/login/view_models/login_view_model.dart';
export 'src/ui/features/login/views/login_page.dart';
export 'src/ui/features/reset_password/view_models/reset_password_view_model.dart';
export 'src/ui/features/reset_password/views/reset_password_page.dart';
