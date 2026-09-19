import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// iOS 风格输入框。
///
/// 相比纯灰底输入框，这里做了更细的层次：
/// * 白底 + 极细描边，聚焦时描边变品牌色并带一层柔光；
/// * 出错时描边与图标变红，下方给出行内说明；
/// * 左侧内置图标、右侧可放显隐按钮或自定义组件（如验证码倒计时）。
class AppTextField extends StatefulWidget {
  /// 创建输入框。
  const AppTextField({
    required this.icon,
    required this.placeholder,
    required this.onChanged,
    this.fieldKey,
    this.controller,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.errorText,
    this.suffix,
    this.enabled = true,
    this.autofillHints,
    this.focusNode,
    super.key,
  });

  /// 左侧内置图标。
  final IconData icon;

  /// 占位文案。
  final String placeholder;

  /// 文本变化回调。
  final ValueChanged<String> onChanged;

  /// 作用于内部 [CupertinoTextField] 的 key，便于测试定位。
  final Key? fieldKey;

  /// 外部控制器。
  final TextEditingController? controller;

  /// 是否密文展示。
  final bool obscureText;

  /// 非空时展示「显示 / 隐藏」按钮。
  final VoidCallback? onToggleObscure;

  /// 键盘类型。
  final TextInputType? keyboardType;

  /// 键盘动作键。
  final TextInputAction? textInputAction;

  /// 输入过滤 / 长度限制。
  final List<TextInputFormatter>? inputFormatters;

  /// 错误文案，非空时进入错误态。
  final String? errorText;

  /// 右侧自定义组件（仅在未提供 [onToggleObscure] 时展示）。
  final Widget? suffix;

  /// 是否可编辑。
  final bool enabled;

  /// 自动填充提示。
  final Iterable<String>? autofillHints;

  /// 外部焦点节点。
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late final bool _ownsFocusNode = widget.focusNode == null;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
    _focused = _focusNode.hasFocus;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!mounted || _focused == _focusNode.hasFocus) {
      return;
    }
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText;
    final hasError = error != null && error.isNotEmpty;
    final focused = _focused && widget.enabled;
    final accent = hasError
        ? AppColors.danger(context)
        : AppColors.primaryOf(context);
    final borderColor = hasError || focused
        ? accent
        : AppColors.border(context);
    final iconColor = hasError
        ? accent
        : (focused ? accent : AppColors.textTertiary(context));

    final Widget? trailing;
    if (widget.onToggleObscure != null) {
      trailing = _TrailingIconButton(
        icon: widget.obscureText
            ? CupertinoIcons.eye_slash
            : CupertinoIcons.eye,
        color: AppColors.textTertiary(context),
        onPressed: widget.onToggleObscure!,
      );
    } else {
      trailing = widget.suffix;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AnimatedContainer(
          duration: AppDurations.fast,
          constraints: const BoxConstraints(minHeight: AppSizes.field),
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.sm,
          ),
          decoration: ShapeDecoration(
            color: widget.enabled
                ? AppColors.surface(context)
                : AppColors.fill(context),
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(
                color: borderColor,
                width: focused || hasError ? 1.6 : 1,
              ),
            ),
            shadows: focused && !hasError
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: <Widget>[
              Icon(widget.icon, size: AppSizes.iconSm, color: iconColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: CupertinoTextField(
                  key: widget.fieldKey,
                  controller: widget.controller,
                  focusNode: _focusNode,
                  onChanged: widget.onChanged,
                  obscureText: widget.obscureText,
                  enabled: widget.enabled,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  inputFormatters: widget.inputFormatters,
                  autofillHints: widget.autofillHints,
                  placeholder: widget.placeholder,
                  placeholderStyle: AppTypography.field.copyWith(
                    color: AppColors.placeholder(context),
                  ),
                  style: AppTypography.bodyStrong.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                  cursorColor: accent,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md - 1,
                  ),
                  decoration: const BoxDecoration(),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              top: AppSpacing.sm - 2,
            ),
            child: Text(
              error,
              style: AppTypography.caption.copyWith(
                color: AppColors.danger(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _TrailingIconButton extends StatelessWidget {
  const _TrailingIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.all(AppSpacing.sm - 2),
      onPressed: onPressed,
      child: Icon(icon, size: AppSizes.iconMd, color: color),
    );
  }
}
