import 'package:flutter/cupertino.dart';

import 'bootstrap.dart';
import 'src/app.dart';

/// 应用入口。
///
/// 只负责读取外部唤起地址并交给 [Bootstrap]：真正的装配顺序都在
/// `bootstrap.dart` 里，方便被测试直接复用。
Future<void> main() async {
  // 外部入口（推送 / 深链 / 扫码）通过编译期变量注入，
  // 与模块内部协议 `scheme://target` 使用同一套地址格式。
  const deepLink = String.fromEnvironment('DEEP_LINK');

  final bootstrap = await Bootstrap.run(
    deepLink: deepLink.isEmpty ? null : deepLink,
  );

  runApp(ModuleApp(bootstrap: bootstrap));
}
