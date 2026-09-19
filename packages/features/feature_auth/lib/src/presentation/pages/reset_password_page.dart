import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:design_system/design_system.dart';
import 'package:signals/signals_flutter.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/password_validator.dart';
import '../../domain/services/sms_code_validator.dart';
import '../controllers/reset_password_controller.dart';
import '../widgets/countdown_code_button.dart';
import '../widgets/demo_hint.dart';

/// 重置密码页。
///
/// 视觉：iOS 分组底色（子页面）+ 单张卡片承载四个输入项，导航栏保留系统返回按钮。
///
/// 状态：Controller 暴露 signals，页面用 [SignalBuilder] 按字段订阅，输入时只重建
/// 对应输入框；倒计时每秒也只重建验证码按钮。
///
/// 流程：输入账号 → 获取短信验证码 → 输入新密码 → 再次确认 → 提交。
/// 新密码规则与登录页一致：6-30 位，仅字母 + 数字，且两者都要有。
class ResetPasswordPage extends StatefulWidget {
  /// 创建重置密码页。
  const ResetPasswordPage({
    required this.repository,
    this.onResetSuccess,
    this.demoHintText,
    super.key,
  });

  /// 认证仓库。
  final AuthRepository repository;

  /// 重置成功（用户关闭弹窗）后的回调，通常用于返回登录页。
  final VoidCallback? onResetSuccess;

  /// 演示环境提示文案，为空时不展示。
  final String? demoHintText;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  late final ResetPasswordController _controller = ResetPasswordController(
    widget.repository,
  );
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _accountController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await _controller.submit();
    if (!mounted || !success) {
      return;
    }
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('重置成功'),
        content: const Text('密码已更新，请使用新密码登录。'),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('返回登录'),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    widget.onResetSuccess?.call();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('重置密码')),
      child: AppPageBackground(
        grouped: true,
        child: SafeArea(
          child: AppFormLayout(
            scrollKey: const Key('reset_scroll_view'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xxl,
            ),
            children: <Widget>[
              const _ResetHeader(),
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
            builder: (context) => AppTextField(
              fieldKey: const Key('reset_account_field'),
              controller: _accountController,
              icon: CupertinoIcons.phone,
              placeholder: '手机号 / 邮箱',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: _controller.updateAccount,
              errorText: _controller.accountError.value,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SignalBuilder(
            builder: (context) => AppTextField(
              fieldKey: const Key('reset_sms_code_field'),
              controller: _codeController,
              icon: CupertinoIcons.chat_bubble,
              placeholder: '短信验证码',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(
                  SmsCodeValidator.allowedCharPattern,
                ),
                LengthLimitingTextInputFormatter(SmsCodeValidator.length),
              ],
              onChanged: _controller.updateSmsCode,
              errorText: _controller.smsCodeError.value,
              suffix: SignalBuilder(
                builder: (context) => CountdownCodeButton(
                  buttonKey: const Key('reset_send_code_button'),
                  countdownSeconds: _controller.countdownSeconds.value,
                  isSending: _controller.isSendingCode.value,
                  onPressed: _controller.sendSmsCode,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SignalBuilder(
            builder: (context) => AppTextField(
              fieldKey: const Key('reset_new_password_field'),
              controller: _newPasswordController,
              icon: CupertinoIcons.lock,
              placeholder: '新密码（字母+数字）',
              obscureText: _controller.obscureNewPassword.value,
              onToggleObscure: _controller.toggleNewPasswordVisibility,
              textInputAction: TextInputAction.next,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(
                  PasswordValidator.allowedCharPattern,
                ),
                LengthLimitingTextInputFormatter(PasswordValidator.maxLength),
              ],
              onChanged: _controller.updateNewPassword,
              errorText: _controller.newPasswordError.value,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              top: AppSpacing.sm - 2,
            ),
            child: Text(
              '${PasswordValidator.minLength}-${PasswordValidator.maxLength} 位，'
              '仅限字母和数字',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary(context),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SignalBuilder(
            builder: (context) => AppTextField(
              fieldKey: const Key('reset_confirm_password_field'),
              controller: _confirmPasswordController,
              icon: CupertinoIcons.lock_rotation,
              placeholder: '再次输入新密码',
              obscureText: _controller.obscureConfirmPassword.value,
              onToggleObscure: _controller.toggleConfirmPasswordVisibility,
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(
                  PasswordValidator.allowedCharPattern,
                ),
                LengthLimitingTextInputFormatter(PasswordValidator.maxLength),
              ],
              onChanged: _controller.updateConfirmPassword,
              errorText: _controller.confirmPasswordError.value,
            ),
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
              buttonKey: const Key('reset_submit_button'),
              label: '确认重置',
              isLoading: _controller.isSubmitting.value,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetHeader extends StatelessWidget {
  const _ResetHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const AppIconBadge(
          icon: CupertinoIcons.lock_rotation,
          size: 60,
          iconSize: 28,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '设置新密码',
          textAlign: TextAlign.center,
          style: AppTypography.title.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: AppSpacing.sm - 2),
        Text(
          '验证短信验证码后即可重置密码',
          textAlign: TextAlign.center,
          style: AppTypography.callout.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
