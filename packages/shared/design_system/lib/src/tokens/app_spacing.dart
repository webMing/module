import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

/// 4pt 基准的间距标尺。
abstract final class AppSpacing {
  /// 2
  static const double xxs = 2;

  /// 4
  static const double xs = 4;

  /// 8
  static const double sm = 8;

  /// 12
  static const double md = 12;

  /// 16
  static const double lg = 16;

  /// 20
  static const double xl = 20;

  /// 24
  static const double xxl = 24;

  /// 32
  static const double xxxl = 32;

  /// 40
  static const double huge = 40;
}

/// 圆角标尺（配合连续圆角使用）。
abstract final class AppRadius {
  /// 6
  static const double xs = 6;

  /// 10
  static const double sm = 10;

  /// 14
  static const double md = 14;

  /// 18
  static const double lg = 18;

  /// 22
  static const double xl = 22;
}

/// 控件尺寸标尺。
abstract final class AppSizes {
  /// 输入框高度（iOS 单行输入框标准 44pt）。
  static const double field = 44;

  /// 主按钮高度（比输入框更厚实，强调主要操作）。
  static const double control = 52;

  /// 分段控件高度。
  static const double segmented = 40;

  /// 表单在宽屏下的最大宽度。
  static const double formMaxWidth = 420;

  /// 图标（输入框内）。
  static const double iconSm = 18;

  /// 图标（列表、统计卡）。
  static const double iconMd = 20;
}

/// 常用动效时长。
abstract final class AppDurations {
  /// 快速（颜色、透明度）。
  static const Duration fast = Duration(milliseconds: 150);

  /// 常规（位移、展开）。
  static const Duration normal = Duration(milliseconds: 220);
}

/// 阴影令牌。
abstract final class AppShadows {
  /// 卡片阴影：浅色下极轻的双层阴影，深色下用黑色拉开层次。
  static List<BoxShadow> card(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    if (isDark) {
      return const <BoxShadow>[
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ];
    }
    return const <BoxShadow>[
      BoxShadow(
        color: Color(0x141B2A4A),
        blurRadius: 24,
        offset: Offset(0, 12),
      ),
      BoxShadow(color: Color(0x0A1B2A4A), blurRadius: 4, offset: Offset(0, 2)),
    ];
  }

  /// 品牌色发光，用于主按钮与图标徽章。
  static List<BoxShadow> brand(BuildContext context) => <BoxShadow>[
    BoxShadow(
      color: AppColors.primaryOf(context).withValues(alpha: 0.30),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  /// 分段控件滑块阴影。
  static List<BoxShadow> thumb(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return <BoxShadow>[
      BoxShadow(
        color: CupertinoColors.black.withValues(alpha: isDark ? 0.5 : 0.10),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
