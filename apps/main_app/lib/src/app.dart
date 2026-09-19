import 'package:flutter/cupertino.dart';

import '../bootstrap.dart';

/// 应用根组件。
///
/// 只做两件事：把 [Bootstrap] 装配好的路由器交给 `CupertinoApp.router`，
/// 以及卸载时释放资源。这里**不再出现任何页面 import**——路由完全由模块
/// 通过 `ModuleRegistrar` 提供。
class ModuleApp extends StatefulWidget {
  /// 用装配结果创建根组件。
  const ModuleApp({required this.bootstrap, super.key});

  /// 装配结果。
  final Bootstrap bootstrap;

  @override
  State<ModuleApp> createState() => _ModuleAppState();
}

class _ModuleAppState extends State<ModuleApp> {
  @override
  void dispose() {
    widget.bootstrap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoApp.router(
    title: '模块化应用',
    debugShowCheckedModeBanner: false,
    theme: const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: CupertinoColors.systemBlue,
    ),
    routerConfig: widget.bootstrap.appRouter.router,
  );
}

/// 路由未匹配时的兜底页。
class RouteErrorPage extends StatelessWidget {
  /// 用错误描述创建兜底页。
  const RouteErrorPage({required this.message, super.key});

  /// 错误描述。
  final String message;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('页面不存在')),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}
