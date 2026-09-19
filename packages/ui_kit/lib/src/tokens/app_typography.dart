import 'package:flutter/cupertino.dart';

/// 字体令牌。
///
/// 不指定 fontFamily：iOS / macOS 走系统字体（SF Pro + 苹方），
/// Android 走系统默认字体，避免引入字体资源。
/// 颜色由调用方通过 `copyWith(color: ...)` 叠加。
abstract final class AppTypography {
  /// 页面主标题（登录页「欢迎登录」）。
  static const TextStyle largeTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.25,
  );

  /// 区块标题。
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.28,
  );

  /// 卡片标题 / 列表主文案。
  static const TextStyle headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// 正文。
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// 加粗正文（输入框内容）。
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 说明文字（副标题）。
  static const TextStyle callout = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// 次级标签 / 链接。
  static const TextStyle subheadline = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// 小号说明 / 错误提示。
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 极小号注释。
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// 分组标题（列表 section header）。
  static const TextStyle captionStrong = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.3,
  );

  /// 按钮文字。
  static const TextStyle button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.2,
  );

  /// 数字强调（统计值）。
  static const TextStyle metric = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.15,
  );

  /// 输入框内文字。
  static const TextStyle field = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
}
