/// 事件处理器。
typedef EventHandler<T extends Object> = void Function(T event);

/// 跨模块事件总线（「我发生了事情」）。
///
/// 与 Module Protocol 的分工：
/// * Protocol 是**命令**——有明确目标与结果，我要让你做事情；
/// * EventBus 是**通知**——不关心谁在听，我发生了事情。
///
/// 发布方无法知道订阅方是谁，新增订阅方也不需要改动发布方，这是跨模块
/// 解耦的主要手段。
///
/// 同步派发：单个订阅者抛异常不会中断其他订阅者，而是交给 [onError]
/// （未提供时静默吞掉——事件通知不应把发布方带崩）。
class EventBus {
  /// 用可选错误回调创建总线。
  EventBus({this.onError});

  /// 订阅者抛异常时的回调；未提供时静默忽略。
  final void Function(Object error, StackTrace stackTrace)? onError;

  final Map<Type, List<void Function(Object event)>> _handlers =
      <Type, List<void Function(Object event)>>{};

  /// 订阅 [T] 事件，返回取消订阅的函数。
  void Function() subscribe<T extends Object>(EventHandler<T> handler) {
    final handlers = _handlers.putIfAbsent(
      T,
      () => <void Function(Object event)>[],
    );
    void wrapper(Object event) => handler(event as T);
    handlers.add(wrapper);

    return () {
      handlers.remove(wrapper);
      if (handlers.isEmpty) {
        _handlers.remove(T);
      }
    };
  }

  /// 发布事件。
  void publish<T extends Object>(T event) {
    final handlers = _handlers[T];
    if (handlers == null || handlers.isEmpty) {
      return;
    }
    // 复制一份：订阅者在处理过程中取消订阅不应影响本次派发。
    for (final handler in List<void Function(Object event)>.of(handlers)) {
      try {
        handler(event);
      } on Object catch (error, stackTrace) {
        onError?.call(error, stackTrace);
      }
    }
  }

  /// [T] 是否有订阅者。
  bool hasSubscribers<T extends Object>() =>
      _handlers[T]?.isNotEmpty ?? false;

  /// [T] 的订阅者数量。
  int subscriberCount<T extends Object>() => _handlers[T]?.length ?? 0;

  /// 清空全部订阅。
  void clear() => _handlers.clear();
}
