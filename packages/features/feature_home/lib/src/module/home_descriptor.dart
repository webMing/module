import 'package:core_module/core_module.dart';

/// 首页模块的身份描述。
///
/// 不声明 [ModuleDescriptor.requires]：首页只依赖 core 提供的能力
/// （会话来自 `core_session`、事件总线来自 `core_module`），不依赖其它业务模块。
const ModuleDescriptor homeModuleDescriptor = ModuleDescriptor(
  id: 'home',
  version: '1.0.0',
  displayName: '首页模块',
);
