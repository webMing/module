import 'package:get_it/get_it.dart';

/// 依赖注入门面。
///
/// 默认构造会创建**独立容器**（`GetIt.asNewInstance()`），因此测试之间不会
/// 共享注册状态；应用运行时用 [ServiceLocator.global] 拿到全局单例容器。
class ServiceLocator {
  /// 创建一个独立容器。
  ServiceLocator({GetIt? container})
    : _container = container ?? GetIt.asNewInstance();

  /// 绑定到全局容器的门面。
  factory ServiceLocator.global() => ServiceLocator(container: GetIt.instance);

  final GetIt _container;

  /// 底层容器。仅在必须与第三方库直接交互时使用，业务代码请用本类方法。
  GetIt get container => _container;

  /// 注册一个已创建的单例。
  void registerSingleton<T extends Object>(T instance) {
    _container.registerSingleton<T>(instance);
  }

  /// 注册懒加载单例：首次取用时才创建。
  void registerLazySingleton<T extends Object>(T Function() factory) {
    _container.registerLazySingleton<T>(factory);
  }

  /// 注册工厂：每次取用都创建新实例。
  void registerFactory<T extends Object>(T Function() factory) {
    _container.registerFactory<T>(factory);
  }

  /// 取用 [T]，未注册时抛 [StateError]。
  T get<T extends Object>() => _container<T>();

  /// 取用 [T]，未注册时返回 null。
  T? maybeGet<T extends Object>() => _container.maybeGet<T>();

  /// [T] 是否已注册。
  bool isRegistered<T extends Object>() => _container.isRegistered<T>();

  /// 注销 [T]。
  ///
  /// get_it 9 的 `unregister` 返回 `FutureOr`（可能是同步实现），
  /// 这里统一 `await` 掉，对调用方始终是异步契约。
  Future<void> unregister<T extends Object>() async {
    await _container.unregister<T>();
  }

  /// 清空容器（get_it 9 起为异步）。
  Future<void> reset({bool dispose = true}) =>
      _container.reset(dispose: dispose);
}
