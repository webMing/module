/// 运行环境。
enum AppEnvironment {
  /// 本地开发。
  development(label: '开发', defaultApiBaseUrl: 'https://api.dev.example.com'),

  /// 预发 / 联调。
  staging(label: '预发', defaultApiBaseUrl: 'https://api.staging.example.com'),

  /// 生产。**没有**默认地址，必须由构建参数显式提供。
  production(label: '生产', defaultApiBaseUrl: '');

  const AppEnvironment({required this.label, required this.defaultApiBaseUrl});

  /// 面向人的环境名。
  final String label;

  /// 该环境的兜底 API 地址；生产为空串，表示「必须显式配置」。
  final String defaultApiBaseUrl;

  /// 是否为生产环境。
  bool get isProduction => this == AppEnvironment.production;

  /// 解析环境名，无法识别时退回 [development]（并让 [AppConfig.validate]
  /// 在需要严格性的场合报错）。
  static AppEnvironment parse(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final value in values) {
      if (value.name == normalized) {
        return value;
      }
    }
    return development;
  }
}
