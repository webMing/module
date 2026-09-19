import 'package:flutter/cupertino.dart';

/// 全局颜色令牌。
///
/// 所有颜色都通过 `resolveFrom(context)` 解析，自动跟随浅色 / 深色模式，
/// 页面里不要再出现写死的十六进制颜色（渐变除外）。
abstract final class AppColors {
  /// 品牌主色（iOS systemBlue）。
  static const CupertinoDynamicColor primary = CupertinoColors.systemBlue;

  /// 解析后的品牌主色。
  static Color primaryOf(BuildContext context) => primary.resolveFrom(context);

  /// 品牌渐变：用于图标徽章、主按钮。
  static LinearGradient brandGradient(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const <Color>[Color(0xFF5AA8FF), Color(0xFF0A5BD6)]
          : const <Color>[Color(0xFF4E9CFF), Color(0xFF0A63F0)],
    );
  }

  /// 页面背景渐变（自上而下的柔和过渡）。
  static LinearGradient pageGradient(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const <Color>[Color(0xFF0C1424), Color(0xFF000000)]
          : const <Color>[Color(0xFFE8F1FF), Color(0xFFF5F8FD)],
    );
  }

  /// 一级文字。
  static Color textPrimary(BuildContext context) =>
      CupertinoColors.label.resolveFrom(context);

  /// 二级文字（说明、副标题）。
  static Color textSecondary(BuildContext context) =>
      CupertinoColors.secondaryLabel.resolveFrom(context);

  /// 三级文字（图标、占位符）。
  static Color textTertiary(BuildContext context) =>
      CupertinoColors.tertiaryLabel.resolveFrom(context);

  /// 输入框占位符。
  static Color placeholder(BuildContext context) =>
      CupertinoColors.placeholderText.resolveFrom(context);

  /// 卡片、表单等前景面。
  static Color surface(BuildContext context) =>
      CupertinoColors.systemBackground.resolveFrom(context);

  /// 分组列表页底色。
  static Color groupedSurface(BuildContext context) =>
      CupertinoColors.systemGroupedBackground.resolveFrom(context);

  /// 轻量填充（分段控件底、标签底）。
  static Color fill(BuildContext context) =>
      CupertinoColors.systemGrey6.resolveFrom(context);

  /// 描边 / 分隔线。
  static Color border(BuildContext context) =>
      CupertinoColors.separator.resolveFrom(context);

  /// 卡片描边（深色下需要一点亮度才分得清层次）。
  static Color cardBorder(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return isDark ? const Color(0xFF232C3D) : const Color(0x14000000);
  }

  /// 危险 / 错误。
  static Color danger(BuildContext context) =>
      CupertinoColors.systemRed.resolveFrom(context);

  /// 成功。
  static Color success(BuildContext context) =>
      CupertinoColors.systemGreen.resolveFrom(context);

  /// 警告。
  static Color warning(BuildContext context) =>
      CupertinoColors.systemOrange.resolveFrom(context);

  /// 信息 / 图表辅助色。
  static Color info(BuildContext context) =>
      CupertinoColors.systemTeal.resolveFrom(context);

  /// 图表辅助色。
  static Color accent(BuildContext context) =>
      CupertinoColors.systemIndigo.resolveFrom(context);
}
