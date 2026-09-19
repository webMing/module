import 'dart:async';
import 'dart:convert';

import 'package:core_storage/core_storage.dart';
import 'package:signals/signals.dart';

import 'auth_session.dart';

/// 响应式会话存储。
///
/// 职责边界（严格限定）：
/// * 持有当前会话这一份**状态**，并以 signals 暴露给 UI；
/// * 可选地把它持久化到 [KeyValueStore]；
/// * **不**负责登录、不碰路由、不碰 DI。
class SessionStore {
  /// 创建会话存储。
  ///
  /// [storage] 为空时退化为纯内存（测试与无持久化场景）；
  /// [storageKey] 是持久化时使用的键。
  SessionStore({
    AuthSession? initial,
    this.storage,
    this.storageKey = 'auth.session',
  }) : _session = signal<AuthSession?>(initial);

  final Signal<AuthSession?> _session;

  /// 持久化后端；为空时退化为纯内存。
  final KeyValueStore? storage;

  /// 持久化使用的键。
  final String storageKey;

  Future<void> _pendingWrite = Future<void>.value();

  /// 当前会话的只读信号，UI 用 `SignalBuilder` 订阅。
  ReadonlySignal<AuthSession?> get session => _session;

  /// 是否已登录的派生信号。
  late final ReadonlySignal<bool> isAuthenticated = computed(
    () => _session.value != null,
  );

  /// 当前会话（非响应式读取，供一次性判断使用）。
  AuthSession? get current => _session.value;

  /// 是否已登录。
  bool get hasSession => _session.value != null;

  /// 从 [storage] 恢复会话；无存储或数据损坏时保持未登录。
  ///
  /// 损坏数据会被就地清除，避免每次启动都重复失败。
  Future<void> restore() async {
    final store = storage;
    if (store == null) {
      return;
    }
    try {
      final raw = await store.read(storageKey);
      if (raw == null) {
        return;
      }
      final decoded = JsonStore.decodeMap(raw, key: storageKey);
      _session.value = AuthSession.fromJson(decoded);
    } on Object {
      await store.delete(storageKey);
      _session.value = null;
    }
  }

  /// 写入会话并异步持久化。
  void set(AuthSession value) {
    _session.value = value;
    _pendingWrite = _persist();
  }

  /// 清空会话并异步清除持久化数据。
  void clear() {
    _session.value = null;
    _pendingWrite = _persist();
  }

  /// 等待最近一次持久化完成（启动与测试中需要确定性时使用）。
  Future<void> flush() => _pendingWrite;

  /// 释放信号。持久化失败不影响内存态，因此这里只做资源回收。
  void dispose() {
    _session.dispose();
    isAuthenticated.dispose();
  }

  Future<void> _persist() async {
    final store = storage;
    if (store == null) {
      return;
    }
    try {
      final value = _session.value;
      if (value == null) {
        await store.delete(storageKey);
      } else {
        await store.write(storageKey, jsonEncode(value.toJson()));
      }
    } on Object {
      // 持久化是尽力而为：写失败不应让登录流程失败。
    }
  }
}
