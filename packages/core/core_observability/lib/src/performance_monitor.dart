/// 一段正在计时的性能追踪。
abstract interface class PerformanceTrace {
  /// 附加维度（如接口路径、商品 id）。
  void putAttribute(String name, Object value);

  /// 结束计时并上报。
  void stop();
}

/// 性能监控端口。
abstract interface class PerformanceMonitor {
  /// 开始一段命名追踪，调用方负责 [PerformanceTrace.stop]。
  PerformanceTrace startTrace(String name);

  /// 包住一段同步逻辑。
  T trace<T>(String name, T Function() body);

  /// 包住一段异步逻辑。
  Future<T> traceAsync<T>(String name, Future<T> Function() body);
}

/// 只测量、不上报的默认实现，且不做任何计时开销之外的记录。
final class NoopPerformanceMonitor implements PerformanceMonitor {
  /// 创建一个空监控器。
  const NoopPerformanceMonitor();

  @override
  PerformanceTrace startTrace(String name) => const _NoopTrace();

  @override
  T trace<T>(String name, T Function() body) => body();

  @override
  Future<T> traceAsync<T>(String name, Future<T> Function() body) => body();
}

final class _NoopTrace implements PerformanceTrace {
  const _NoopTrace();

  @override
  void putAttribute(String name, Object value) {}

  @override
  void stop() {}
}
