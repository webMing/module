import 'package:core_model/core_model.dart';
import 'package:flutter_test/flutter_test.dart';

final class _User extends Entity<String> {
  const _User(super.id, this.name);

  final String name;
}

final class _Order extends Entity<String> {
  const _Order(super.id);
}

void main() {
  group('Entity', () {
    test('同类型同 id 相等，忽略其他字段', () {
      expect(const _User('u1', '甲'), const _User('u1', '乙'));
      expect(const _User('u1', '甲').hashCode, const _User('u1', '乙').hashCode);
    });

    test('id 不同则不等', () {
      expect(const _User('u1', '甲'), isNot(const _User('u2', '甲')));
    });

    test('不同类型即使 id 相同也不相等', () {
      expect(const _User('1', '甲'), isNot(const _Order('1')));
    });

    test('toString 带上类型与 id', () {
      expect(const _User('u1', '甲').toString(), '_User(u1)');
    });
  });

  group('JsonMapReader', () {
    test('读取基础类型', () {
      final json = <String, Object?>{
        'name': '甲',
        'age': 30,
        'score': 1.5,
        'active': true,
      };
      expect(json.readString('name'), '甲');
      expect(json.readInt('age'), 30);
      expect(json.readDouble('score'), 1.5);
      expect(json.readBool('active'), isTrue);
    });

    test('整数值也能被 readDouble 接受', () {
      expect(<String, Object?>{'n': 2}.readDouble('n'), 2.0);
    });

    test('类型不符视为缺失，不抛异常', () {
      final json = <String, Object?>{'age': 'not-a-number'};
      expect(json.readInt('age'), isNull);
      expect(json.readString('missing'), isNull);
      expect(json.readMap('missing'), isNull);
    });

    test('requireString 缺失时抛 FormatException', () {
      expect(
        () => <String, Object?>{}.requireString('token'),
        throwsA(isA<FormatException>()),
      );
      expect(<String, Object?>{'token': 't'}.requireString('token'), 't');
    });

    test('readDateTime 解析 ISO-8601，非法值返回 null', () {
      final json = <String, Object?>{'at': '2024-05-01T10:00:00.000Z'};
      expect(json.readDateTime('at'), DateTime.utc(2024, 5, 1, 10));
      expect(
        <String, Object?>{'at': 'nope'}.readDateTime('at'),
        isNull,
      );
    });

    test('readMap 读取嵌套对象', () {
      final json = <String, Object?>{
        'user': <String, Object?>{'name': '甲'},
      };
      expect(json.readMap('user')?.readString('name'), '甲');
    });

    test('readList 过滤掉类型不符的元素', () {
      final json = <String, Object?>{
        'tags': <Object?>['a', 1, 'b', null],
      };
      expect(json.readList<String>('tags'), <String>['a', 'b']);
      expect(json.readList<String>('missing'), isNull);
    });
  });
}
