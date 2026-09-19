/// 一段可结束的链路追踪。
abstract interface class Span {
  /// 链路名称。
  String get name;

  /// 附加属性。
  Map<String, Object?> get attributes;

  /// 写入一个属性。
  void setAttribute(String name, Object? value);

  /// 记录链路内发生的错误（不中断链路）。
  void recordError(Object error, {StackTrace? stackTrace});

  /// 结束链路。
  void end({bool error = false});
}

/// 分布式链路追踪端口。
abstract interface class Tracer {
  /// 开始一段链路，调用方负责 [Span.end]。
  Span startSpan(String name, {Map<String, Object?>? attributes});

  /// 包住一段异步逻辑，自动结束链路并透传结果/异常。
  Future<T> trace<T>(
    String name,
    Future<T> Function(Span span) body, {
    Map<String, Object?>? attributes,
  });
}

/// 不做任何上报的默认实现。
final class NoopTracer implements Tracer {
  /// 创建一个空 tracer。
  const NoopTracer();

  @override
  Span startSpan(String name, {Map<String, Object?>? attributes}) =>
      _NoopSpan(name, attributes);

  @override
  Future<T> trace<T>(
    String name,
    Future<T> Function(Span span) body, {
    Map<String, Object?>? attributes,
  }) async {
    final span = startSpan(name, attributes: attributes);
    try {
      final result = await body(span);
      span.end();
      return result;
    } on Object catch (error, stackTrace) {
      span
        ..recordError(error, stackTrace: stackTrace)
        ..end(error: true);
      rethrow;
    }
  }
}

final class _NoopSpan implements Span {
  _NoopSpan(this.name, Map<String, Object?>? attributes)
    : attributes = <String, Object?>{...?attributes};

  @override
  final String name;

  @override
  final Map<String, Object?> attributes;

  @override
  void setAttribute(String name, Object? value) => attributes[name] = value;

  @override
  void recordError(Object error, {StackTrace? stackTrace}) {}

  @override
  void end({bool error = false}) {}
}
