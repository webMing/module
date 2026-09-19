import 'package:core_module/core_module.dart';
import 'package:flutter_test/flutter_test.dart';

/// 订单创建事件（发布方与订阅方共享的事件类型）。
class _OrderCreated {
  const _OrderCreated(this.orderId);

  final String orderId;
}

class _OtherEvent {
  const _OtherEvent();
}

void main() {
  group('订阅与发布', () {
    test('订阅者收到事件', () {
      final bus = EventBus();
      final received = <String>[];
      bus.subscribe<_OrderCreated>((event) => received.add(event.orderId));

      bus.publish(const _OrderCreated('10001'));
      expect(received, <String>['10001']);
    });

    test('多个订阅者都收到', () {
      final bus = EventBus();
      var first = 0;
      var second = 0;
      bus
        ..subscribe<_OrderCreated>((_) => first++)
        ..subscribe<_OrderCreated>((_) => second++);

      bus.publish(const _OrderCreated('1'));
      expect(<int>[first, second], <int>[1, 1]);
      expect(bus.subscriberCount<_OrderCreated>(), 2);
    });

    test('只收到自己订阅的类型', () {
      final bus = EventBus();
      final seen = <String>[];
      bus.subscribe<_OtherEvent>((_) => seen.add('other'));
      bus.subscribe<_OrderCreated>((_) => seen.add('order'));

      bus.publish(const _OrderCreated('1'));
      expect(seen, <String>['order']);
    });

    test('没有订阅者时发布是空操作', () {
      final bus = EventBus();
      expect(() => bus.publish(const _OrderCreated('1')), returnsNormally);
      expect(bus.hasSubscribers<_OrderCreated>(), isFalse);
    });

    test('取消订阅后不再收到', () {
      final bus = EventBus();
      var count = 0;
      final unsubscribe = bus.subscribe<_OrderCreated>((_) => count++);

      bus.publish(const _OrderCreated('1'));
      unsubscribe();
      bus.publish(const _OrderCreated('2'));

      expect(count, 1);
      expect(bus.hasSubscribers<_OrderCreated>(), isFalse);
    });

    test('取消订阅是幂等的', () {
      final bus = EventBus();
      final unsubscribe = bus.subscribe<_OrderCreated>((_) {});
      unsubscribe();
      expect(unsubscribe, returnsNormally);
    });

    test('clear 清空全部订阅', () {
      final bus = EventBus()..subscribe<_OrderCreated>((_) {});
      bus.clear();
      expect(bus.hasSubscribers<_OrderCreated>(), isFalse);
    });
  });

  group('异常隔离', () {
    test('单个订阅者抛异常不影响其它订阅者', () {
      final bus = EventBus();
      var reached = 0;
      bus
        ..subscribe<_OrderCreated>((_) => throw StateError('boom'))
        ..subscribe<_OrderCreated>((_) => reached++);

      expect(() => bus.publish(const _OrderCreated('1')), returnsNormally);
      expect(reached, 1, reason: '异常订阅者不应打断派发');
    });

    test('异常交给 onError 回调', () {
      final errors = <Object>[];
      final bus = EventBus(
        onError: (error, stackTrace) => errors.add(error),
      )..subscribe<_OrderCreated>((_) => throw StateError('boom'));

      bus.publish(const _OrderCreated('1'));
      expect(errors.single, isA<StateError>());
    });
  });

  group('派发期间的订阅变更', () {
    test('派发过程中取消订阅不影响本次派发', () {
      final bus = EventBus();
      final seen = <String>[];
      late void Function() unsubscribe;

      unsubscribe = bus.subscribe<_OrderCreated>((event) {
        seen.add('first:${event.orderId}');
        unsubscribe();
      });
      bus.subscribe<_OrderCreated>((event) => seen.add('second:${event.orderId}'));

      bus.publish(const _OrderCreated('1'));

      expect(seen, <String>['first:1', 'second:1']);
      expect(bus.subscriberCount<_OrderCreated>(), 1);
    });

    test('派发过程中新增的订阅者本次不收到', () {
      final bus = EventBus();
      final seen = <String>[];
      bus.subscribe<_OrderCreated>((_) {
        seen.add('original');
        bus.subscribe<_OrderCreated>((_) => seen.add('late'));
      });

      bus.publish(const _OrderCreated('1'));
      expect(seen, <String>['original']);

      bus.publish(const _OrderCreated('2'));
      expect(seen.where((s) => s == 'late').length, 1);
    });
  });
}
