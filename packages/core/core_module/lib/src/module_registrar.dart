import 'package:core_di/core_di.dart';
import 'package:meta/meta.dart';

import 'module_contribution.dart';
import 'module_protocol.dart';

/// 一项待应用的依赖注册。
///
/// 用闭包而不是「类型 + 工厂」的元组，是为了保住泛型：把 `T` 在
/// `ModuleRegistrar` 的泛型方法里就固定下来，应用阶段不需要再做类型转换。
@immutable
class DependencyRegistration {
  /// 用一个「把自身应用到容器」的闭包创建。
  const DependencyRegistration(this.applyTo);

  /// 应用到容器。
  final void Function(ServiceLocator locator) applyTo;
}

/// 模块的能力注册面板。
///
/// 由 `ModuleRegistry` 在 boot 阶段创建并交给模块，模块**只能**通过它
/// 登记能力，拿不到注册表本身。
///
/// 所有方法都只做收集，不产生副作用：依赖在 `ModuleRegistry.boot` 末尾
/// 统一应用到容器，保证模块的 `register` 阶段是纯声明。
class ModuleRegistrar {
  /// 为 [moduleId] 创建注册面板。
  ModuleRegistrar({required this.moduleId});

  /// 所属模块 id。
  final String moduleId;

  final List<ModuleContribution> _contributions = <ModuleContribution>[];
  final Map<String, ModuleProtocol> _protocols = <String, ModuleProtocol>{};
  final List<DependencyRegistration> _dependencies = <DependencyRegistration>[];

  /// 登记一项通用贡献（路由由 `core_router` 的扩展方法调用它）。
  void contribute(ModuleContribution contribution) =>
      _contributions.add(contribution);

  /// 本模块贡献的某一类对象。
  Iterable<T> contributionsOf<T extends ModuleContribution>() =>
      _contributions.whereType<T>();

  /// 登记一个 URI 协议。
  ///
  /// 同一个模块内 scheme 重复会直接抛错——静默覆盖会让「哪个协议生效」
  /// 变成依赖注册顺序的隐式行为。
  void registerProtocol(ModuleProtocol protocol) {
    final scheme = protocol.scheme;
    final existing = _protocols[scheme];
    if (existing != null) {
      throw StateError(
        '模块 $moduleId 重复注册协议 scheme：$scheme',
      );
    }
    _protocols[scheme] = protocol;
  }

  /// 登记一个已创建的单例依赖。
  void singleton<T extends Object>(T Function(ServiceLocator locator) factory) {
    _dependencies.add(
      DependencyRegistration(
        (locator) => locator.registerSingleton<T>(factory(locator)),
      ),
    );
  }

  /// 登记一个懒加载单例依赖（首次取用时才创建）。
  void lazySingleton<T extends Object>(
    T Function(ServiceLocator locator) factory,
  ) {
    _dependencies.add(
      DependencyRegistration(
        (locator) => locator.registerLazySingleton<T>(() => factory(locator)),
      ),
    );
  }

  /// 登记一个工厂依赖（每次取用都新建）。
  void factory<T extends Object>(T Function(ServiceLocator locator) factory) {
    _dependencies.add(
      DependencyRegistration(
        (locator) => locator.registerFactory<T>(() => factory(locator)),
      ),
    );
  }

  /// 本模块登记的协议（按 scheme）。
  Map<String, ModuleProtocol> get protocols =>
      Map<String, ModuleProtocol>.unmodifiable(_protocols);

  /// 本模块登记的依赖注册项。
  List<DependencyRegistration> get dependencies =>
      List<DependencyRegistration>.unmodifiable(_dependencies);

  /// 全部贡献（诊断输出用）。
  List<ModuleContribution> get contributions =>
      List<ModuleContribution>.unmodifiable(_contributions);
}
