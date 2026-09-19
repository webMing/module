import 'package:core_di/core_di.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用于验证「工厂每次都新建」。
final class _Counter {
  _Counter();
}

/// 用于验证懒加载只创建一次。
final class _LazyCounter {
  _LazyCounter();
}

void main() {
  group('注册与取用', () {
    test('registerSingleton 立即持有同一实例', () {
      final locator = ServiceLocator();
      final instance = _Counter();
      locator.registerSingleton<_Counter>(instance);

      expect(locator.isRegistered<_Counter>(), isTrue);
      expect(locator.get<_Counter>(), same(instance));
    });

    test('registerLazySingleton 首次取用时创建且只创建一次', () {
      final locator = ServiceLocator();
      var created = 0;
      locator.registerLazySingleton<_LazyCounter>(() {
        created++;
        return _LazyCounter();
      });

      expect(created, 0, reason: '注册时不应创建');
      final first = locator.get<_LazyCounter>();
      final second = locator.get<_LazyCounter>();
      expect(created, 1);
      expect(first, same(second));
    });

    test('registerFactory 每次取用都新建', () {
      final locator = ServiceLocator();
      locator.registerFactory<_Counter>(_Counter.new);

      expect(locator.get<_Counter>(), isNot(same(locator.get<_Counter>())));
    });
  });

  group('查询与注销', () {
    test('未注册时 get 抛错，maybeGet 返回 null', () {
      final locator = ServiceLocator();
      expect(locator.maybeGet<_Counter>(), isNull);
      expect(locator.get<_Counter>, throwsA(isA<StateError>()));
    });

    test('unregister 之后不再注册', () async {
      final locator = ServiceLocator()..registerSingleton<_Counter>(_Counter());
      await locator.unregister<_Counter>();
      expect(locator.isRegistered<_Counter>(), isFalse);
    });

    test('reset 清空容器', () async {
      final locator = ServiceLocator()
        ..registerSingleton<_Counter>(_Counter())
        ..registerSingleton<_LazyCounter>(_LazyCounter());

      await locator.reset();
      expect(locator.isRegistered<_Counter>(), isFalse);
      expect(locator.isRegistered<_LazyCounter>(), isFalse);
    });
  });

  group('容器隔离', () {
    test('两个 ServiceLocator 互不共享注册', () {
      final first = ServiceLocator()..registerSingleton<_Counter>(_Counter());
      final second = ServiceLocator();

      expect(first.isRegistered<_Counter>(), isTrue);
      expect(second.isRegistered<_Counter>(), isFalse);
      expect(second.maybeGet<_Counter>(), isNull);
    });
  });
}
