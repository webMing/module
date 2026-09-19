import 'package:core_session/core_session.dart';
import 'package:flutter/foundation.dart';

/// 登录成功事件（「我发生了事情」）。
///
/// 认证模块在会话写入 [SessionStore] 之后广播它；具体跳哪一页由订阅方
/// （应用外壳或其它模块）决定，认证模块不需要知道谁在听，也不需要认识
/// 路由。新增订阅方无需改动本模块。
@immutable
class LoginSucceededEvent {
  /// 使用刚创建的会话构造事件。
  const LoginSucceededEvent(this.session);

  /// 刚写入会话存储的会话。
  final AuthSession session;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LoginSucceededEvent && other.session == session;
  }

  @override
  int get hashCode => session.hashCode;

  @override
  String toString() => 'LoginSucceededEvent($session)';
}
