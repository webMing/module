import 'package:core_error/core_error.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryKeyValueStore', () {
    test('读写删查', () async {
      final store = InMemoryKeyValueStore();

      expect(await store.read('k'), isNull);
      expect(await store.containsKey('k'), isFalse);

      await store.write('k', 'v');
      expect(await store.read('k'), 'v');
      expect(await store.containsKey('k'), isTrue);

      await store.write('k', 'v2');
      expect(await store.read('k'), 'v2');

      await store.delete('k');
      expect(await store.read('k'), isNull);
    });

    test('删除不存在的键不报错', () async {
      final store = InMemoryKeyValueStore();
      await expectLater(store.delete('nope'), completes);
    });

    test('keys 与 clear', () async {
      final store = InMemoryKeyValueStore(
        initial: <String, String>{'a': '1', 'b': '2'},
      );
      expect(await store.keys(), <String>{'a', 'b'});

      await store.clear();
      expect(await store.keys(), isEmpty);
      expect(store.snapshot, isEmpty);
    });

    test('从初始数据构造时会复制，不共享外部 Map', () async {
      final source = <String, String>{'a': '1'};
      final store = InMemoryKeyValueStore(initial: source);
      source['b'] = '2';

      expect(await store.keys(), <String>{'a'});
    });

    test('空键与纯空白键被拒绝', () async {
      final store = InMemoryKeyValueStore();
      for (final bad in <String>['', '   ']) {
        expect(
          () => store.write(bad, 'v'),
          throwsA(
            isA<StorageException>().having(
              (e) => e.code,
              'code',
              'storage.empty_key',
            ),
          ),
        );
      }
    });
  });

  group('JsonStore', () {
    test('对象往返读写', () async {
      final store = JsonStore(InMemoryKeyValueStore());
      await store.writeMap('session', <String, Object?>{'account': 'demo'});

      final restored = await store.readMap('session');
      expect(restored, <String, Object?>{'account': 'demo'});
      expect(await store.containsKey('session'), isTrue);

      await store.delete('session');
      expect(await store.readMap('session'), isNull);
    });

    test('namespace 隔离不同模块的键空间', () async {
      final backing = InMemoryKeyValueStore();
      final auth = JsonStore(backing, namespace: 'auth');
      final home = JsonStore(backing, namespace: 'home');

      await auth.writeMap('state', <String, Object?>{'v': 'auth'});

      expect(await home.readMap('state'), isNull);
      expect(await auth.readMap('state'), <String, Object?>{'v': 'auth'});
      expect(await backing.keys(), <String>{'auth.state'});
    });

    test('无 namespace 时直接使用原键', () async {
      final backing = InMemoryKeyValueStore();
      final store = JsonStore(backing);
      await store.writeMap('k', <String, Object?>{'a': 1});
      expect(await backing.keys(), <String>{'k'});
    });

    test('内容损坏时抛 StorageException 而不是崩溃', () async {
      final store = JsonStore(
        InMemoryKeyValueStore(initial: <String, String>{'bad': '{not json'}),
      );
      expect(
        () => store.readMap('bad'),
        throwsA(
          isA<StorageException>()
              .having((e) => e.code, 'code', 'storage.invalid_json')
              .having((e) => e.key, 'key', 'bad'),
        ),
      );
    });

    test('JSON 根节点不是对象时同样抛 StorageException', () async {
      final store = JsonStore(
        InMemoryKeyValueStore(initial: <String, String>{'arr': '[1,2]'}),
      );
      expect(() => store.readMap('arr'), throwsA(isA<StorageException>()));
    });

    test('decodeMap 正常解析', () {
      expect(JsonStore.decodeMap('{"a":1}'), <String, Object?>{'a': 1});
    });
  });
}
