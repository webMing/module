import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:core_session/core_session.dart';
import 'package:design_system/design_system.dart';
import 'package:signals/signals_flutter.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/password_validator.dart';
import '../../domain/services/sms_code_validator.dart';
import '../controllers/login_controller.dart';
import '../widgets/countdown_code_button.dart';
import '../widgets/demo_hint.dart';

/// 登录页。
///
/// 视觉：品牌渐变背景 + 居中卡片式表单，卡片内依次为方式切换、账号、
/// 密码 / 验证码、错误提示与主按钮；「忘记密码」右对齐，演示提示独立在卡片外。
///
/// 状态：Controller 暴露 signals，页面用 [SignalBuilder] **按区域订阅**——
/// 账号输入只重建账号输入框、倒计时每秒只重建验证码按钮，避免整页重建。
///
/// 行为：
/// * 默认「密码登录」，可切换到「验证码登录」；
/// * 账号支持手机号 / 昵称 / 邮箱，密码仅允许字母 + 数字且最多 30 位；
/// * 登录成功后通过 [onLoginSuccess] 把会话交给上层跳转首页；
/// * 通过 [onForgotPassword] 跳转重置密码页。
class LoginPage extends StatefulWidget {
  /// 创建登录页。
  const LoginPage({
    required this.repository,
    required this.onLoginSuccess,
    this.onForgotPassword,
    this.demoHintText,
    super.key,
  });

  /// 认证仓库。
  final AuthRepository repository;

  /// 登录成功回调。
  final ValueChanged<AuthSession> onLoginSuccess;

  /// 「忘记密码」回调，为空时不展示入口。
  final VoidCallback? onForgotPassword;

  /// 演示环境提示文案，为空时不展示。
  final String? demoHintText;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginController _controller = LoginController(widget.repository);
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = await _controller.submit();
    if (!mounted || session == null) {
      return;
    }
    widget.onLoginSuccess(session);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: AppPageBackground(
        child: SafeArea(
          child: AppFormLayout(
            scrollKey: const Key('login_scroll_view'),
            children: <Widget>[
              const _LoginHeader(),
              const SizedBox(height: AppSpacing.xxl),
              _buildFormCard(context),
              const SizedBox(height: AppSpacing.xl),
              SignalBuilder(
                builder: (context) => DemoHint(
                  text: widget.demoHintText,
                  debugSmsCode: _controller.debugSmsCode.value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SignalBuilder(
            builder: (context) => AppSegmentedControl<LoginMode>(
              segments: const <LoginMode, String>{
                LoginMode.password: '密码登录',
                LoginMode.smsCode: '验证码登录',
              },
              groupValue: _controller.mode.value,
              onChanged: _controller.switchMode,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SignalBuilder(
            builder: (context) => AppTextField(
              fieldKey: const Key('login_account_field'),
              controller: _accountController,
              icon: CupertinoIcons.person,
              placeholder: '手机号 / 昵称 / 邮箱',
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.username],
              onChanged: _controller.updateAccount,
              errorText: _controller.accountError.value,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SignalBuilder(
            builder: (context) => _controller.isPasswordMode.value
                ? _buildPasswordField()
                : _buildSmsCodeField(),
          ),
          SignalBuilder(
            builder: (context) {
              final message = _controller.errorMessage.value;
              if (message == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: AppFormMessage(message: message),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          SignalBuilder(
            builder: (context) => AppPrimaryButton(
              buttonKey: const Key('login_submit_button'),
              label: '登 录',
              isLoading: _controller.isSubmitting.value,
              onPressed: _submit,
            ),
          ),
          if (widget.onForgotPassword != null)
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                key: const Key('login_forgot_password_button'),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                onPressed: widget.onForgotPassword,
                child: Text(
                  '忘记密码？',
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.primaryOf(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return AppTextField(
      fieldKey: const Key('login_password_field'),
      controller: _passwordController,
      icon: CupertinoIcons.lock,
      placeholder: '密码（字母+数字）',
      obscureText: _controller.obscurePassword.value,
      onToggleObscure: _controller.togglePasswordVisibility,
      textInputAction: TextInputAction.done,
      autofillHints: const <String>[AutofillHints.password],
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(PasswordValidator.allowedCharPattern),
        LengthLimitingTextInputFormatter(PasswordValidator.maxLength),
      ],
      onChanged: _controller.updatePassword,
      errorText: _controller.passwordError.value,
    );
  }

  Widget _buildSmsCodeField() {
    return AppTextField(
      fieldKey: const Key('login_sms_code_field'),
      controller: _codeController,
      icon: CupertinoIcons.chat_bubble,
      placeholder: '短信验证码',
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(SmsCodeValidator.allowedCharPattern),
        LengthLimitingTextInputFormatter(SmsCodeValidator.length),
      ],
      onChanged: _controller.updateSmsCode,
      errorText: _controller.smsCodeError.value,
      // 倒计时每秒只重建这个按钮，不影响输入框本身。
      suffix: SignalBuilder(
        builder: (context) => CountdownCodeButton(
          buttonKey: const Key('login_send_code_button'),
          countdownSeconds: _controller.countdownSeconds.value,
          isSending: _controller.isSendingCode.value,
          onPressed: _controller.sendSmsCode,
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const AppIconBadge(
          icon: CupertinoIcons.lock_shield_fill,
          size: 68,
          iconSize: 32,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          '欢迎登录',
          textAlign: TextAlign.center,
          style: AppTypography.largeTitle.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '请使用账号密码或短信验证码登录',
          textAlign: TextAlign.center,
          style: AppTypography.callout.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
