/// 首页模块对外的跨模块事件。
///
/// 事件是「我发生了事情」的通知：发布方不关心谁在听，也不需要知道订阅方会
/// 做什么。这里只描述「用户请求退出登录」，至于是清空会话还是跳转登录页，
/// 由订阅它的应用装配层决定——首页模块既不持有会话状态，也不认识路由。
library;

/// 「用户请求退出登录」事件。
///
/// 无载荷：语义就是用户点了退出登录，具体如何响应由订阅方决定。
///
/// ```dart
/// eventBus.publish(const LogoutRequestedEvent());
/// ```
class LogoutRequestedEvent {
  /// 创建事件（无参数，可直接 `const`）。
  const LogoutRequestedEvent();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LogoutRequestedEvent;

  @override
  int get hashCode => Object.hashAll(const <Object?>[]);

  @override
  String toString() => 'LogoutRequestedEvent()';
}
