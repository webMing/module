/// 崩溃上报端口。
abstract interface class CrashReporter {
  /// 上报一次错误；[fatal] 用于区分「崩溃」与「可恢复失败」。
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal,
  });

  /// 关联后续上报的用户标识（登出时传 null）。
  Future<void> setUserId(String? userId);

  /// 记录一条面包屑，用于还原崩溃前的操作路径。
  Future<void> log(String message);
}

/// 不上报的默认实现。
final class NoopCrashReporter implements CrashReporter {
  /// 创建一个空上报器。
  const NoopCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> log(String message) async {}
}

/// 一次上报记录。
class CrashRecord {
  /// 创建一条记录。
  const CrashRecord({
    required this.error,
    required this.reason,
    required this.fatal,
    this.stackTrace,
  });

  /// 错误对象。
  final Object error;

  /// 业务上下文描述。
  final String? reason;

  /// 是否为致命错误。
  final bool fatal;

  /// 堆栈。
  final StackTrace? stackTrace;
}

/// 把上报记进内存的实现，供测试与本地调试使用。
final class InMemoryCrashReporter implements CrashReporter {
  final List<CrashRecord> _records = <CrashRecord>[];
  final List<String> _breadcrumbs = <String>[];

  /// 已上报的错误。
  List<CrashRecord> get records => List<CrashRecord>.unmodifiable(_records);

  /// 已记录的面包屑。
  List<String> get breadcrumbs => List<String>.unmodifiable(_breadcrumbs);

  /// 当前关联的用户标识。
  String? userId;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    _records.add(
      CrashRecord(
        error: error,
        reason: reason,
        fatal: fatal,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  Future<void> setUserId(String? userId) async => this.userId = userId;

  @override
  Future<void> log(String message) async => _breadcrumbs.add(message);
}
