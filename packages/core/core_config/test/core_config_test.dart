import 'package:core_config/core_config.dart';
import 'package:core_error/core_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment', () {
    test('解析环境名（大小写与空格不敏感）', () {
      expect(AppEnvironment.parse('production'), AppEnvironment.production);
      expect(AppEnvironment.parse('  STAGING '), AppEnvironment.staging);
    });

    test('无法识别时退回 development', () {
      expect(AppEnvironment.parse('nope'), AppEnvironment.development);
      expect(AppEnvironment.parse(''), AppEnvironment.development);
    });

    test('只有生产环境标记为 isProduction', () {
      expect(AppEnvironment.production.isProduction, isTrue);
      expect(AppEnvironment.staging.isProduction, isFalse);
    });

    test('生产环境没有兜底地址', () {
      expect(AppEnvironment.production.defaultApiBaseUrl, isEmpty);
      expect(AppEnvironment.development.defaultApiBaseUrl, isNotEmpty);
    });
  });

  group('AppConfig.validate', () {
    test('合法配置通过校验', () {
      const config = AppConfig(
        environment: AppEnvironment.staging,
        apiBaseUrl: 'https://api.staging.example.com',
      );
      expect(config.validate, returnsNormally);
      expect(config.isProduction, isFalse);
    });

    test('生产环境缺地址时抛 ConfigException', () {
      const config = AppConfig(
        environment: AppEnvironment.production,
        apiBaseUrl: '',
      );
      expect(
        config.validate,
        throwsA(
          isA<ConfigException>()
              .having((e) => e.key, 'key', 'API_BASE_URL')
              .having((e) => e.code, 'code', 'config.missing_api_base_url'),
        ),
      );
    });

    test('非法地址抛 ConfigException', () {
      const config = AppConfig(
        environment: AppEnvironment.development,
        apiBaseUrl: 'not a url',
      );
      expect(
        config.validate,
        throwsA(
          isA<ConfigException>().having(
            (e) => e.code,
            'code',
            'config.invalid_api_base_url',
          ),
        ),
      );
    });

    test('相对地址不被接受', () {
      const config = AppConfig(
        environment: AppEnvironment.development,
        apiBaseUrl: '/api',
      );
      expect(config.validate, throwsA(isA<ConfigException>()));
    });

    test('非正超时抛 ConfigException', () {
      const config = AppConfig(
        environment: AppEnvironment.development,
        apiBaseUrl: 'https://api.dev.example.com',
        connectTimeout: Duration.zero,
      );
      expect(
        config.validate,
        throwsA(
          isA<ConfigException>()
              .having((e) => e.key, 'key', 'connectTimeout')
              .having((e) => e.code, 'code', 'config.invalid_timeout'),
        ),
      );
    });
  });

  group('AppConfig.fromEnvironment', () {
    test('未注入 dart-define 时落到 development 且地址可用', () {
      final config = AppConfig.fromEnvironment();
      expect(config.environment, AppEnvironment.development);
      expect(config.apiBaseUrl, isNotEmpty);
      expect(config.validate, returnsNormally);
      expect(config.enableLogging, isTrue);
    });

    test('默认超时均为正数', () {
      final config = AppConfig.fromEnvironment();
      expect(config.connectTimeout, greaterThan(Duration.zero));
      expect(config.sendTimeout, greaterThan(Duration.zero));
      expect(config.receiveTimeout, greaterThan(Duration.zero));
    });
  });
}
