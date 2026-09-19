import 'package:core_di/core_di.dart';
import 'package:core_module/core_module.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo {
  const _Repo(this.name);

  final String name;
}

class _NeedsRepo {
  const _NeedsRepo(this.repo);

  final _Repo repo;
}

class _Singleton {}

class _Lazy {}

class _Factory {}

/// 可配置的假模块：记录 register 被调用了几次，并可注入注册行为。
class _FakeModule implements AppModule {
  _FakeModule(this.descriptor, {this.onRegister});

  @override
  final ModuleDescriptor descriptor;

  final void Function(ModuleRegistrar registrar)? onRegister;

  int registerCount = 0;

  @override
  void register(ModuleRegistrar registrar) {
    registerCount++;
    onRegister?.call(registrar);
  }
}

class _RouteContribution implements ModuleContribution {
  const _RouteContribution(this.path);

  final String path;
}

class _PingProtocol implements ModuleProtocol {
  const _PingProtocol();

  @override
  String get scheme => 'ping';

  @override
  Future<ModuleResponse> handle(ModuleRequest request) async =>
      const ModuleResponse.done();
}

void main() {
  group('register 与查找', () {
    test('重复 id 直接抛错，而不是静默覆盖', () {
      final registry = ModuleRegistry()
        ..register(_FakeModule(const ModuleDescriptor(id: 'a', version: '1')));

      expect(
        () => registry.register(
          _FakeModule(const ModuleDescriptor(id: 'a', version: '2')),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('模块已注册：a'),
          ),
        ),
      );
    });

    test('find 按类型查找，找不到返回 null', () {
      final module = _FakeModule(const ModuleDescriptor(id: 'a', version: '1'));
      final registry = ModuleRegistry()..register(module);

      expect(registry.find<_FakeModule>(), same(module));
      expect(registry.find<AppModule>(), same(module));
      expect(
        registry.find<_OtherModule>(),
        isNull,
      );
    });

    test('contains / descriptors / modules', () {
      final registry = ModuleRegistry()
        ..register(_FakeModule(const ModuleDescriptor(id: 'a', version: '1')))
        ..register(_FakeModule(const ModuleDescriptor(id: 'b', version: '1')));

      expect(registry.contains('a'), isTrue);
      expect(registry.contains('z'), isFalse);
      expect(
        registry.descriptors.map((d) => d.id),
        <String>['a', 'b'],
      );
      expect(registry.modules.length, 2);
      expect(registry.isBooted, isFalse);
    });
  });

  group('boot', () {
    test('调用每个模块的 register，且只调用一次', () {
      final a = _FakeModule(const ModuleDescriptor(id: 'a', version: '1'));
      final b = _FakeModule(const ModuleDescriptor(id: 'b', version: '1'));
      final registry = ModuleRegistry()
        ..register(a)
        ..register(b)
        ..boot(ServiceLocator());

      expect(a.registerCount, 1);
      expect(b.registerCount, 1);
      expect(registry.isBooted, isTrue);
    });

    test('重复 boot 抛错（否则依赖会被注册两遍）', () {
      final registry = ModuleRegistry()
        ..register(_FakeModule(const ModuleDescriptor(id: 'a', version: '1')))
        ..boot(ServiceLocator());

      expect(
        () => registry.boot(ServiceLocator()),
        throwsA(isA<StateError>()),
      );
    });

    test('boot 之前取不到协议', () {
      final registry = ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'a', version: '1'),
            onRegister: (r) => r.registerProtocol(const _PingProtocol()),
          ),
        );

      expect(registry.protocolFor('ping'), isNull);
      registry.boot(ServiceLocator());
      expect(registry.protocolFor('ping'), isA<_PingProtocol>());
    });

    test('requires 指向未注册模块时启动即失败', () {
      final registry = ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(
              id: 'order',
              version: '1',
              requires: <String>['product'],
            ),
          ),
        );

      expect(
        () => registry.boot(ServiceLocator()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('依赖未注册的模块：product'),
          ),
        ),
      );
    });

    test('requires 满足时正常 boot', () {
      final registry = ModuleRegistry()
        ..register(_FakeModule(const ModuleDescriptor(id: 'product', version: '1')))
        ..register(
          _FakeModule(
            const ModuleDescriptor(
              id: 'order',
              version: '1',
              requires: <String>['product'],
            ),
          ),
        );

      expect(() => registry.boot(ServiceLocator()), returnsNormally);
    });

    test('跨模块 scheme 冲突时启动即失败', () {
      final registry = ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'a', version: '1'),
            onRegister: (r) => r.registerProtocol(const _PingProtocol()),
          ),
        )
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'b', version: '1'),
            onRegister: (r) => r.registerProtocol(const _PingProtocol()),
          ),
        );

      expect(
        () => registry.boot(ServiceLocator()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('协议 scheme 冲突：ping'),
          ),
        ),
      );
    });

    test('同一模块内重复 scheme 由 registrar 拒绝', () {
      final registry = ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'a', version: '1'),
            onRegister: (r) => r
              ..registerProtocol(const _PingProtocol())
              ..registerProtocol(const _PingProtocol()),
          ),
        );

      expect(
        () => registry.boot(ServiceLocator()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('重复注册协议 scheme：ping'),
          ),
        ),
      );
    });

    test('protocolSchemes 汇总所有模块的协议', () {
      final registry = ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'a', version: '1'),
            onRegister: (r) => r.registerProtocol(const _PingProtocol()),
          ),
        )
        ..boot(ServiceLocator());

      expect(registry.protocolSchemes, <String>['ping']);
    });
  });

  group('依赖应用', () {
    test('singleton / lazySingleton / factory 语义正确', () {
      final locator = ServiceLocator();
      ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'deps', version: '1'),
            onRegister: (registrar) => registrar
              ..singleton<_Singleton>((_) => _Singleton())
              ..lazySingleton<_Lazy>((_) => _Lazy())
              ..factory<_Factory>((_) => _Factory()),
          ),
        )
        ..boot(locator);

      expect(locator.get<_Singleton>(), same(locator.get<_Singleton>()));
      expect(locator.get<_Lazy>(), same(locator.get<_Lazy>()));
      expect(locator.get<_Factory>(), isNot(same(locator.get<_Factory>())));
    });

    test('工厂能拿到容器，从而解析其它依赖', () {
      final locator = ServiceLocator();
      ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'deps', version: '1'),
            onRegister: (registrar) => registrar
              ..singleton<_Repo>((_) => const _Repo('real'))
              // 懒加载 + 依赖容器 => 与声明顺序无关。
              ..lazySingleton<_NeedsRepo>(
                (locator) => _NeedsRepo(locator.get<_Repo>()),
              ),
          ),
        )
        ..boot(locator);

      expect(locator.get<_NeedsRepo>().repo.name, 'real');
    });

    test('onBoot 动作在依赖应用之前执行，且能读到应用已注册的基础设施', () {
      final locator = ServiceLocator()
        ..registerSingleton<_Repo>(const _Repo('app'));
      final order = <String>[];

      ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'deps', version: '1'),
            onRegister: (registrar) => registrar
              ..onBoot((locator) => order.add('boot:${locator.get<_Repo>().name}'))
              ..singleton<_Factory>((_) {
                order.add('dependency');
                return _Factory();
              }),
          ),
        )
        ..boot(locator);

      expect(order, <String>['boot:app', 'dependency']);
      expect(locator.get<_Factory>(), isA<_Factory>());
    });

    test('boot 动作可安装兜底依赖，供模块自身依赖解析', () {
      final locator = ServiceLocator();
      ModuleRegistry()
        ..register(_fallbackRepoModule())
        ..boot(locator);

      expect(locator.get<_NeedsRepo>().repo.name, 'fallback');
    });

    test('应用已提供实现时 boot 动作不会覆盖', () {
      final locator = ServiceLocator()
        ..registerSingleton<_Repo>(const _Repo('app'));
      ModuleRegistry()
        ..register(_fallbackRepoModule())
        ..boot(locator);

      expect(locator.get<_NeedsRepo>().repo.name, 'app');
    });
  });

  group('贡献聚合', () {
    test('contributionsOf 跨模块汇总同类贡献', () {
      final registry = ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'a', version: '1'),
            onRegister: (r) => r
              ..contribute(const _RouteContribution('/a'))
              ..contribute(const _RouteContribution('/a2')),
          ),
        )
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'b', version: '1'),
            onRegister: (r) => r.contribute(const _RouteContribution('/b')),
          ),
        )
        ..boot(ServiceLocator());

      expect(
        registry
            .contributionsOf<_RouteContribution>()
            .map((c) => c.path)
            .toList(),
        <String>['/a', '/a2', '/b'],
      );
    });

    test('contributionsOf 只返回请求的类型', () {
      final registry = ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'a', version: '1'),
            onRegister: (r) => r.contribute(const _RouteContribution('/a')),
          ),
        )
        ..boot(ServiceLocator());

      expect(
        registry.contributionsOf<ModuleContribution>().length,
        1,
        reason: 'contribute 的内容是 _RouteContribution',
      );
    });

    test('registrarOf 暴露模块的注册面板', () {
      final registry = ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'a', version: '1'),
            onRegister: (r) => r.contribute(const _RouteContribution('/a')),
          ),
        )
        ..boot(ServiceLocator());

      expect(registry.registrarOf('a')?.moduleId, 'a');
      expect(registry.registrarOf('a')?.contributions.length, 1);
      expect(registry.registrarOf('z'), isNull);
    });
  });

  group('describe', () {
    test('输出每个模块的协议、依赖与贡献数量', () {
      final registry = ModuleRegistry()
        ..register(
          _FakeModule(
            const ModuleDescriptor(id: 'auth', version: '1.0.0'),
            onRegister: (registrar) => registrar
              ..registerProtocol(const _PingProtocol())
              ..singleton<_Singleton>((_) => _Singleton())
              ..contribute(const _RouteContribution('/login')),
          ),
        )
        ..boot(ServiceLocator());

      final text = registry.describe();
      expect(text, contains('auth'));
      expect(text, contains('协议[ping]'));
      expect(text, contains('依赖[1]'));
      expect(text, contains('贡献[1]'));
    });

    test('未 boot 时为空串', () {
      expect(ModuleRegistry().describe(), isEmpty);
    });
  });
}

/// 模拟「应用没提供就装兜底实现」的模块（`AuthModule` 的同款写法）。
_FakeModule _fallbackRepoModule() => _FakeModule(
  const ModuleDescriptor(id: 'fallback', version: '1'),
  onRegister: (registrar) => registrar
    ..onBoot((locator) {
      if (!locator.isRegistered<_Repo>()) {
        locator.registerLazySingleton<_Repo>(() => const _Repo('fallback'));
      }
    })
    ..lazySingleton<_NeedsRepo>((locator) => _NeedsRepo(locator.get<_Repo>())),
);

/// 仅用于验证 `find<T>` 的类型不匹配分支。
class _OtherModule implements AppModule {
  @override
  ModuleDescriptor get descriptor =>
      const ModuleDescriptor(id: 'other', version: '1');

  @override
  void register(ModuleRegistrar registrar) {}
}
