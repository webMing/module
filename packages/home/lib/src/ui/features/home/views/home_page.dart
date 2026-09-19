import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:ui_kit/ui_kit.dart';

/// 首页模块。
///
/// 视觉：iOS 分组列表底 + 卡片化内容（问候卡 / 数据概览 / 本周活跃图表 /
/// 功能分组 / 退出登录），层次由卡片与分组标题共同承担。
///
/// 只负责展示登录后的落地页，不依赖具体路由实现：退出登录通过
/// [HomePage.onLogout] 回调交给上层处理。
class HomePage extends StatelessWidget {
  /// 创建首页。
  const HomePage({
    required this.account,
    this.loginMethodLabel,
    this.onLogout,
    super.key,
  });

  /// 当前登录账号。
  final String account;

  /// 登录方式文案（如「密码登录」），为空时不展示。
  final String? loginMethodLabel;

  /// 退出登录回调。
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>['已登录', ?loginMethodLabel].join(' · ');
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedSurface(context),
      navigationBar: const CupertinoNavigationBar(middle: Text('首页')),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: <Widget>[
                    const AppIconBadge(
                      icon: CupertinoIcons.person_fill,
                      size: 56,
                      iconSize: 26,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '你好，$account',
                            key: const Key('home_account_text'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title.copyWith(
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            subtitle,
                            style: AppTypography.callout.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: AppStatCard(
                      icon: CupertinoIcons.chart_bar,
                      value: '128',
                      label: '今日访问',
                      tint: AppColors.primaryOf(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppStatCard(
                      icon: CupertinoIcons.bell,
                      value: '6',
                      label: '未读消息',
                      tint: AppColors.warning(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppStatCard(
                      icon: CupertinoIcons.doc_text,
                      value: '3',
                      label: '待办事项',
                      tint: AppColors.success(context),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          '本周活跃',
                          style: AppTypography.headline.copyWith(
                            color: textPrimary,
                          ),
                        ),
                        const Spacer(),
                        _TrendTag(label: '+12.5%'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _WeeklyActivityChart(
                      values: <double>[
                        0.42,
                        0.66,
                        0.34,
                        0.81,
                        0.55,
                        0.96,
                        0.62,
                      ],
                      labels: <String>['一', '二', '三', '四', '五', '六', '日'],
                      todayIndex: 5,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            CupertinoListSection.insetGrouped(
              header: _SectionHeader(title: '常用功能'),
              children: <Widget>[
                _FeatureTile(
                  icon: CupertinoIcons.person,
                  tint: AppColors.primaryOf(context),
                  title: '我的资料',
                ),
                _FeatureTile(
                  icon: CupertinoIcons.bell,
                  tint: AppColors.warning(context),
                  title: '消息通知',
                ),
                _FeatureTile(
                  icon: CupertinoIcons.gear,
                  tint: AppColors.accent(context),
                  title: '设置',
                ),
                _FeatureTile(
                  icon: CupertinoIcons.question_circle,
                  tint: AppColors.info(context),
                  title: '帮助与反馈',
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: <Widget>[
                CupertinoListTile(
                  key: const Key('home_logout_tile'),
                  leadingSize: 28,
                  leading: _ListIcon(
                    icon: CupertinoIcons.power,
                    color: AppColors.danger(context),
                  ),
                  title: Text(
                    '退出登录',
                    style: AppTypography.headline.copyWith(
                      color: AppColors.danger(context),
                    ),
                  ),
                  onTap: onLogout,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Center(
                child: Text(
                  '首页模块 · Module Workspace',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.captionStrong.copyWith(
        color: AppColors.textSecondary(context),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.tint,
    required this.title,
  });

  final IconData icon;
  final Color tint;
  final String title;

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      leadingSize: 28,
      leading: _ListIcon(icon: icon, color: tint),
      title: Text(
        title,
        style: AppTypography.headline.copyWith(
          color: AppColors.textPrimary(context),
        ),
      ),
      trailing: const CupertinoListTileChevron(),
    );
  }
}

class _ListIcon extends StatelessWidget {
  const _ListIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs + 1),
        ),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _TrendTag extends StatelessWidget {
  const _TrendTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final success = AppColors.success(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: ShapeDecoration(
        color: success.withValues(alpha: 0.12),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(CupertinoIcons.arrow_up_right, size: 12, color: success),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 极简柱状图：本周活跃度，今天用品牌渐变高亮。
class _WeeklyActivityChart extends StatelessWidget {
  const _WeeklyActivityChart({
    required this.values,
    required this.labels,
    this.todayIndex = -1,
  });

  final List<double> values;
  final List<String> labels;
  final int todayIndex;

  @override
  Widget build(BuildContext context) {
    const chartHeight = 84.0;
    final primary = AppColors.primaryOf(context);

    return Column(
      children: <Widget>[
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var i = 0; i < values.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Container(
                    height: math.max(10, chartHeight * values[i].clamp(0, 1)),
                    decoration: ShapeDecoration(
                      gradient: i == todayIndex
                          ? AppColors.brandGradient(context)
                          : null,
                      color: i == todayIndex
                          ? null
                          : primary.withValues(alpha: 0.18),
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: i == todayIndex
                        ? AppColors.textPrimary(context)
                        : AppColors.textTertiary(context),
                    fontWeight: i == todayIndex
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
