import 'package:core_module/core_module.dart';

/// 认证模块身份。
///
/// [ModuleDescriptor.id] 在同一个注册表内必须唯一，`auth` 是模块间寻址
/// （`auth://login`）使用的稳定标识。
const ModuleDescriptor authModuleDescriptor = ModuleDescriptor(
  id: 'auth',
  version: '1.0.0',
  displayName: '认证模块',
);
