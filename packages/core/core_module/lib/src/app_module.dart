import 'module_descriptor.dart';
import 'module_registrar.dart';

/// 模块契约：模块的唯一入口。
///
/// 约定：
/// * [register] 应当是**纯声明**——只向 [ModuleRegistrar] 登记能力，
///   不要在里做 IO、不要构造需要 DI 的对象（此时容器还没准备好）；
/// * 模块只描述「自己提供什么」，不掌握注册表，避免模块之间通过注册表
///   互相窥探。
abstract interface class AppModule {
  /// 模块身份。
  ModuleDescriptor get descriptor;

  /// 登记本模块提供的能力（路由 / 协议 / 依赖 / 事件）。
  void register(ModuleRegistrar registrar);
}
