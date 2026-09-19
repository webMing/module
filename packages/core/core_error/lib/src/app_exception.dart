import 'package:meta/meta.dart';

/// 应用统一异常基类。
///
/// 约定：
/// * [message] 是可读描述，可以直接进日志；面向用户的文案由 UI 层按
///   [code] 映射，不要直接展示 [message]；
/// * [code] 是稳定的机器可读标识，用于埋点聚合与文案映射，**不要**把
///   人类语言写进 [code]；
/// * [cause] / [stackTrace] 保留底层原因，便于排查，日志层应一并上报。
@immutable
abstract class AppException implements Exception {
  /// 创建一个应用异常。
  const AppException(
    this.message, {
    this.code,
    this.cause,
    this.stackTrace,
  });

  /// 面向开发者的错误描述。
  final String message;

  /// 稳定的机器可读错误码。
  final String? code;

  /// 触发本次异常的底层原因。
  final Object? cause;

  /// 底层原因的堆栈。
  final StackTrace? stackTrace;

  /// 原始堆栈：优先使用归一化时捕获的 [stackTrace]。
  StackTrace? get effectiveStackTrace => stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer(runtimeType);
    final errorCode = code;
    if (errorCode != null) {
      buffer.write('[$errorCode]');
    }
    buffer.write(': $message');
    final rootCause = cause;
    if (rootCause != null) {
      buffer.write(' <- $rootCause');
    }
    return buffer.toString();
  }
}
