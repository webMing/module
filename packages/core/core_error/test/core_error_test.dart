import 'package:core_error/core_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppException 基础契约', () {
    test('toString 组合类型、错误码、消息与底层原因', () {
      final exception = UnknownException(
        '解析失败',
        code: 'parse.failed',
        cause: const FormatException('bad'),
      );
      final text = exception.toString();
      expect(text, contains('UnknownException'));
      expect(text, contains('[parse.failed]'));
      expect(text, contains('解析失败'));
      expect(text, contains('bad'));
    });

    test('没有错误码与原因时不输出多余部分', () {
      expect(const UnknownException('坏了').toString(), 'UnknownException: 坏了');
    });
  });

  group('NetworkException', () {
    test('可重试判定：超时与无连接可重试', () {
      expect(
        const NetworkException('超时', kind: NetworkErrorKind.timeout)
            .isRetryable,
        isTrue,
      );
      expect(
        const NetworkException('断网', kind: NetworkErrorKind.noConnection)
            .isRetryable,
        isTrue,
      );
    });

    test('可重试判定：5xx 可重试，4xx 不可重试', () {
      expect(
        const NetworkException(
          '服务端错误',
          kind: NetworkErrorKind.badResponse,
          statusCode: 503,
        ).isRetryable,
        isTrue,
      );
      expect(
        const NetworkException(
          '参数错误',
          kind: NetworkErrorKind.badResponse,
          statusCode: 400,
        ).isRetryable,
        isFalse,
      );
    });

    test('可重试判定：取消与负载错误不可重试', () {
      expect(
        const NetworkException('已取消', kind: NetworkErrorKind.cancelled)
            .isRetryable,
        isFalse,
      );
      expect(
        const NetworkException('结构不对', kind: NetworkErrorKind.badPayload)
            .isRetryable,
        isFalse,
      );
    });

    test('badResponse 但没有状态码时不可重试', () {
      expect(
        const NetworkException('未知响应', kind: NetworkErrorKind.badResponse)
            .isRetryable,
        isFalse,
      );
    });

    test('toString 带出 kind、状态码与地址', () {
      final exception = NetworkException(
        '请求失败',
        kind: NetworkErrorKind.badResponse,
        statusCode: 404,
        uri: Uri.parse('https://api.test/ping'),
      );
      expect(exception.toString(), contains('badResponse'));
      expect(exception.toString(), contains('404'));
      expect(exception.toString(), contains('https://api.test/ping'));
    });

    test('保留底层 cause 与 stackTrace', () {
      final cause = Exception('socket closed');
      final exception = NetworkException(
        '请求失败',
        kind: NetworkErrorKind.noConnection,
        cause: cause,
        stackTrace: StackTrace.current,
      );
      expect(exception.cause, same(cause));
      expect(exception.effectiveStackTrace, isNotNull);
      expect(exception.toString(), contains('socket closed'));
    });

    test('是 AppException，可被统一捕获', () {
      expect(
        const NetworkException('x', kind: NetworkErrorKind.unknown),
        isA<AppException>(),
      );
    });
  });

  group('带 key 的异常', () {
    test('StorageException 输出存储键', () {
      const exception = StorageException('写入失败', key: 'auth.session');
      expect(exception.toString(), contains('auth.session'));
      expect(exception.key, 'auth.session');
    });

    test('ConfigException 输出配置项名', () {
      const exception = ConfigException('缺配置', key: 'API_BASE_URL');
      expect(exception.toString(), contains('API_BASE_URL'));
      expect(exception.key, 'API_BASE_URL');
    });

    test('无 key 时不输出括号', () {
      expect(const StorageException('失败').toString(), isNot(contains('key')));
    });
  });
}
