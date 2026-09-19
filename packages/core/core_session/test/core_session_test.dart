import 'package:core_session/core_session.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';

AuthSession buildSession({
  String account = 'demo',
  LoginMethod method = LoginMethod.password,
  String? token = 't1',
}) => AuthSession(
  account: account,
  method: method,
  loggedInAt: DateTime.utc(2024, 5, 1, 10),
  token: token,
);

void main() {
  group('LoginMethod', () {
    test('每种方式都有面向用户的文案', () {
      expect(LoginMethod.password.label, '密码登录');
      expect(LoginMethod.smsCode.label, '验证码登录');
    });

    test('parse 识别枚举名，未知值退回 password', () {
      expect(LoginMethod.parse('smsCode'), LoginMethod.smsCode);
      expect(LoginMethod.parse(' password '), LoginMethod.password);
      expect(LoginMethod.parse('nope'), LoginMethod.password);
    });
  });

  group('AuthSession', () {
    test('toJson / fromJson 往返一致', () {
      final original = buildSession(method: LoginMethod.smsCode);
      final restored = AuthSession.fromJson(original.toJson());
      expect(restored, original);
    });

    test('token 为空时不写入 JSON', () {
      final json = buildSession(token: null).toJson();
      expect(json.containsKey('token'), isFalse);
      expect(AuthSession.fromJson(json).token, isNull);
    });

    test('缺少必填字段时抛 FormatException', () {
      expect(
        () => AuthSession.fromJson(<String, Object?>{}),
        throwsA(isA<FormatException>()),
      );
    });

    test('loggedInAt 非法时抛 FormatException', () {
      expect(
        () => AuthSession.fromJson(<String, Object?>{
          'account': 'demo',
          'method': 'password',
          'loggedInAt': 'not-a-date',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('相等性覆盖全部字段', () {
      expect(buildSession(), buildSession());
      expect(buildSession(), isNot(buildSession(account: 'other')));
      expect(buildSession(), isNot(buildSession(method: LoginMethod.smsCode)));
      expect(buildSession(), isNot(buildSession(token: 't2')));
      expect(buildSession().hashCode, buildSession().hashCode);
    });

    test('toString 保留原有格式', () {
      expect(
        buildSession().toString(),
        'AuthSession(account: demo, method: LoginMethod.password, token: t1)',
      );
    });
  });

  group('SessionStore 状态', () {
    test('初始未登录', () {
      final store = SessionStore();
      expect(store.current, isNull);
      expect(store.hasSession, isFalse);
      expect(store.isAuthenticated.value, isFalse);
      store.dispose();
    });

    test('set 之后会话可读且派生信号翻转', () {
      final store = SessionStore();
      final session = buildSession();

      store.set(session);
      expect(store.current, session);
      expect(store.hasSession, isTrue);
      expect(store.isAuthenticated.value, isTrue);
      store.dispose();
    });

    test('订阅时会先回调一次当前值', () {
      final store = SessionStore();
      final seen = <AuthSession?>[];
      final dispose = store.session.subscribe(seen.add);
      dispose();

      expect(
        seen,
        <AuthSession?>[null],
        reason: 'signals 7 的 subscribe 会立即回调当前值，而非等待首次变更',
      );
      store.dispose();
    });

    test('会话变化会通知订阅者', () {
      final store = SessionStore();
      final seen = <AuthSession?>[];
      final dispose = store.session.subscribe(seen.add);

      final session = buildSession();
      store.set(session);
      store.clear();
      dispose();

      // [0] 是订阅时的当前值，之后依次是 set 与 clear。
      expect(seen, <AuthSession?>[null, session, null]);
      store.dispose();
    });

    test('写入相同值不重复通知（signals 相等性）', () {
      final store = SessionStore();
      var notifications = 0;
      final dispose = store.session.subscribe((_) => notifications++);

      store.set(buildSession());
      store.set(buildSession());
      dispose();

      // 1 次订阅回调 + 1 次首次 set；第二次 set 因值相等被忽略。
      expect(notifications, 2);
      store.dispose();
    });

    test('clear 之后回到未登录', () {
      final store = SessionStore(initial: buildSession());
      store.clear();
      expect(store.current, isNull);
      expect(store.isAuthenticated.value, isFalse);
      store.dispose();
    });
  });

  group('SessionStore 持久化', () {
    test('无 storage 时 restore / set 均为空操作', () async {
      final store = SessionStore();
      await store.restore();
      store.set(buildSession());
      await store.flush();
      expect(store.current, isNotNull);
      store.dispose();
    });

    test('set 会写入存储，restore 能读回', () async {
      final backing = InMemoryKeyValueStore();
      final writer = SessionStore(storage: backing);
      writer.set(buildSession(method: LoginMethod.smsCode));
      await writer.flush();

      expect(await backing.containsKey('auth.session'), isTrue);

      final reader = SessionStore(storage: backing);
      await reader.restore();
      expect(reader.current, buildSession(method: LoginMethod.smsCode));

      writer.dispose();
      reader.dispose();
    });

    test('clear 会删除已持久化的会话', () async {
      final backing = InMemoryKeyValueStore();
      final store = SessionStore(storage: backing)
        ..set(buildSession());
      await store.flush();
      expect(await backing.containsKey('auth.session'), isTrue);

      store.clear();
      await store.flush();
      expect(await backing.containsKey('auth.session'), isFalse);
      store.dispose();
    });

    test('数据损坏时清除并保持未登录', () async {
      final backing = InMemoryKeyValueStore(
        initial: <String, String>{'auth.session': '{not json'},
      );
      final store = SessionStore(storage: backing);

      await store.restore();
      expect(store.current, isNull);
      expect(await backing.containsKey('auth.session'), isFalse);
      store.dispose();
    });

    test('可自定义存储键', () async {
      final backing = InMemoryKeyValueStore();
      final store = SessionStore(storage: backing, storageKey: 'custom.key')
        ..set(buildSession());
      await store.flush();

      expect(await backing.containsKey('custom.key'), isTrue);
      expect(await backing.containsKey('auth.session'), isFalse);
      store.dispose();
    });
  });
}
