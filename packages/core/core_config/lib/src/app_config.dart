import 'package:core_error/core_error.dart';
import 'package:meta/meta.dart';

import 'app_environment.dart';

/// 应用配置。
///
/// 通过 `--dart-define` 注入，例如：
/// `flutter run --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=...`
@immutable
class AppConfig {
  /// 直接构造一份配置（测试常用）。
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.sendTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
    this.enableLogging = true,
  });

  /// 从编译期环境变量读取配置。
  factory AppConfig.fromEnvironment() {
    const rawEnvironment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const rawBaseUrl = String.fromEnvironment('API_BASE_URL');
    const loggingEnabled = bool.fromEnvironment(
      'ENABLE_LOGGING',
      defaultValue: true,
    );

    final environment = AppEnvironment.parse(rawEnvironment);
    return AppConfig(
      environment: environment,
      apiBaseUrl: rawBaseUrl.isEmpty
          ? environment.defaultApiBaseUrl
          : rawBaseUrl,
      enableLogging: loggingEnabled,
    );
  }

  /// 当前环境。
  final AppEnvironment environment;

  /// API 根地址（不含结尾斜杠）。
  final String apiBaseUrl;

  /// 建立连接超时。
  final Duration connectTimeout;

  /// 发送超时。
  final Duration sendTimeout;

  /// 接收超时。
  final Duration receiveTimeout;

  /// 是否输出日志。
  final bool enableLogging;

  /// 是否为生产环境。
  bool get isProduction => environment.isProduction;

  /// 复制并覆盖部分字段（派生测试配置与多环境组合时使用）。
  AppConfig copyWith({
    AppEnvironment? environment,
    String? apiBaseUrl,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableLogging,
  }) => AppConfig(
    environment: environment ?? this.environment,
    apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    connectTimeout: connectTimeout ?? this.connectTimeout,
    sendTimeout: sendTimeout ?? this.sendTimeout,
    receiveTimeout: receiveTimeout ?? this.receiveTimeout,
    enableLogging: enableLogging ?? this.enableLogging,
  );

  /// 校验配置，非法时抛 [ConfigException]。
  ///
  /// 应当在 Bootstrap 阶段调用：宁可启动即失败，也不要等到第一次发请求
  /// 才在生产环境暴露「地址没配」。
  void validate() {
    if (apiBaseUrl.trim().isEmpty) {
      throw ConfigException(
        '环境 ${environment.name} 未配置 API_BASE_URL',
        key: 'API_BASE_URL',
        code: 'config.missing_api_base_url',
      );
    }

    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.isAbsolute || !uri.hasScheme) {
      throw ConfigException(
        'API_BASE_URL 不是合法的绝对地址：$apiBaseUrl',
        key: 'API_BASE_URL',
        code: 'config.invalid_api_base_url',
      );
    }

    for (final entry in <String, Duration>{
      'connectTimeout': connectTimeout,
      'sendTimeout': sendTimeout,
      'receiveTimeout': receiveTimeout,
    }.entries) {
      if (entry.value <= Duration.zero) {
        throw ConfigException(
          '${entry.key} 必须为正数，当前为 ${entry.value}',
          key: entry.key,
          code: 'config.invalid_timeout',
        );
      }
    }
  }
}
