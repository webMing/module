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
  final List<void Function(ServiceLocator locator)> _bootActions =
      <void Function(ServiceLocator locator)>[];
  ServiceLocator? _locator;

  /// 容器引用。
  ///
  /// **在 boot 之前不可用**，因此只能用在「稍后才执行」的闭包里——典型是
  /// 路由工厂与协议处理：
  ///
  /// ```dart
  /// registrar.registerRoute(
  ///   '/login',
  ///   (context) => LoginPage(repository: registrar.locator.get<AuthRepository>()),
  /// );
  /// ```
  ///
  /// 这样模块可以自己完成依赖装配，不需要全局容器，也不需要把 locator
  /// 塞进模块构造函数。
  ServiceLocator get locator {
    final value = _locator;
    if (value == null) {
      throw StateError(
        '模块 $moduleId 的 locator 在 boot 之前不可用；'
        '请只在路由工厂/协议处理等延迟执行的代码里访问它',
      );
    }
    return value;
  }

  /// [locator] 是否已就绪。
  bool get hasLocator => _locator != null;

  /// 由 `ModuleRegistry.boot` 回填。
  void attachLocator(ServiceLocator locator) => _locator = locator;

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

  /// 登记一个在 **boot 阶段**执行的动作。
  ///
  /// 用于「注册逻辑本身需要读取容器状态」的场合，最典型的是给依赖提供
  /// 兜底实现：
  ///
  /// ```dart
  /// registrar.onBoot((locator) {
  ///   if (!locator.isRegistered<AuthService>()) {
  ///     locator.registerLazySingleton<AuthService>(() => FakeAuthService());
  ///   }
  /// });
  /// ```
  ///
  /// 动作在依赖应用之前、且应用已注册完基础设施之后执行。放在这里而不是
  /// [register] 里，是因为 [register] 阶段容器还没准备好。
  void onBoot(void Function(ServiceLocator locator) action) =>
      _bootActions.add(action);

  /// 本模块登记的 boot 动作。
  List<void Function(ServiceLocator locator)> get bootActions =>
      List<void Function(ServiceLocator locator)>.unmodifiable(_bootActions);

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
