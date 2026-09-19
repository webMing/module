/// 埋点端口。
abstract interface class AnalyticsSink {
  /// 上报一个事件。
  Future<void> track(String event, {Map<String, Object?>? properties});

  /// 关联后续事件的用户标识（登出时传 null）。
  Future<void> setUserId(String? userId);

  /// 上报当前页面，用于页面停留时长统计。
  Future<void> trackScreen(String screenName);
}

/// 不上报的默认实现。
final class NoopAnalyticsSink implements AnalyticsSink {
  /// 创建一个空埋点器。
  const NoopAnalyticsSink();

  @override
  Future<void> track(String event, {Map<String, Object?>? properties}) async {}

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> trackScreen(String screenName) async {}
}

/// 一次埋点记录。
class AnalyticsEvent {
  /// 创建一条记录。
  const AnalyticsEvent(this.name, {this.properties});

  /// 事件名。
  final String name;

  /// 事件属性。
  final Map<String, Object?>? properties;
}

/// 把事件记进内存的实现，供测试断言使用。
final class InMemoryAnalyticsSink implements AnalyticsSink {
  final List<AnalyticsEvent> _events = <AnalyticsEvent>[];
  final List<String> _screens = <String>[];

  /// 已上报的事件。
  List<AnalyticsEvent> get events => List<AnalyticsEvent>.unmodifiable(_events);

  /// 已上报的页面。
  List<String> get screens => List<String>.unmodifiable(_screens);

  /// 当前关联的用户标识。
  String? userId;

  /// 事件名是否出现过。
  bool hasEvent(String name) => _events.any((event) => event.name == name);

  @override
  Future<void> track(String event, {Map<String, Object?>? properties}) async {
    _events.add(AnalyticsEvent(event, properties: properties));
  }

  @override
  Future<void> setUserId(String? userId) async => this.userId = userId;

  @override
  Future<void> trackScreen(String screenName) async => _screens.add(screenName);
}
