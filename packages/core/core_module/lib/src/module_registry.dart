import 'package:core_di/core_di.dart';

import 'app_module.dart';
import 'module_contribution.dart';
import 'module_descriptor.dart';
import 'module_protocol.dart';
import 'module_registrar.dart';

/// 模块注册表：负责模块生命周期与发现。
///
/// 两阶段模型：
/// 1. [register] 收集模块（只登记，不执行任何模块代码）；
/// 2. [boot] 调用每个模块的 `register` 收集能力 → 校验依赖与协议冲突 →
///    把依赖统一应用到容器。
///
/// 这样「声明」与「副作用」被分开：任何配置错误都在启动阶段一次性暴露，
/// 而不是等到某个页面第一次被打开。
class ModuleRegistry {
  final Map<String, AppModule> _modules = <String, AppModule>{};
  final Map<String, ModuleRegistrar> _registrars = <String, ModuleRegistrar>{};
  final Map<String, ModuleProtocol> _protocols = <String, ModuleProtocol>{};
  final Map<String, String> _protocolOwner = <String, String>{};
  bool _booted = false;

  /// 注册一个模块。
  ///
  /// 重复的 [ModuleDescriptor.id] 直接抛错：静默覆盖会让「哪个模块生效」
  /// 依赖注册顺序，是极难排查的线上问题。
  void register(AppModule module) {
    final id = module.descriptor.id;
    if (_modules.containsKey(id)) {
      throw StateError('模块已注册：$id');
    }
    _modules[id] = module;
  }

  /// 按类型查找模块。
  T? find<T extends AppModule>() {
    for (final module in _modules.values) {
      if (module is T) {
        return module;
      }
    }
    return null;
  }

  /// [id] 是否已注册。
  bool contains(String id) => _modules.containsKey(id);

  /// 已注册的模块。
  Iterable<AppModule> get modules =>
      List<AppModule>.unmodifiable(_modules.values);

  /// 已注册的模块身份。
  Iterable<ModuleDescriptor> get descriptors =>
      _modules.values.map((module) => module.descriptor);

  /// 是否已完成 boot。
  bool get isBooted => _booted;

  /// 执行 boot：收集能力、校验、应用依赖。
  ///
  /// 只能执行一次——重复 boot 会让依赖被注册两遍。
  void boot(ServiceLocator locator) {
    if (_booted) {
      throw StateError('ModuleRegistry.boot 只能执行一次');
    }

    // 1) 收集：让每个模块登记自己的能力（纯声明，无副作用）。
    for (final module in _modules.values) {
      final registrar = ModuleRegistrar(moduleId: module.descriptor.id);
      module.register(registrar);
      _registrars[module.descriptor.id] = registrar;
    }

    // 1.5) 回填容器引用：模块的延迟闭包（路由工厂、协议）会用到它。
    for (final registrar in _registrars.values) {
      registrar.attachLocator(locator);
    }

    // 2) 校验协议级依赖已满足。
    for (final module in _modules.values) {
      for (final required in module.descriptor.requires) {
        if (!_modules.containsKey(required)) {
          throw StateError('模块 ${module.descriptor.id} 依赖未注册的模块：$required');
        }
      }
    }

    // 3) 归集协议，并检测跨模块 scheme 冲突。
    for (final entry in _registrars.entries) {
      final moduleId = entry.key;
      entry.value.protocols.forEach((scheme, protocol) {
        final owner = _protocolOwner[scheme];
        if (owner != null) {
          throw StateError('协议 scheme 冲突：$scheme 同时被 $owner 与 $moduleId 注册');
        }
        _protocolOwner[scheme] = moduleId;
        _protocols[scheme] = protocol;
      });
    }

    // 4) 先跑模块的 boot 动作（此时能读到应用已注册的基础设施），
    //    再统一应用模块登记的依赖。
    for (final registrar in _registrars.values) {
      for (final action in registrar.bootActions) {
        action(locator);
      }
    }
    for (final registrar in _registrars.values) {
      for (final dependency in registrar.dependencies) {
        dependency.applyTo(locator);
      }
    }

    _booted = true;
  }

  /// 按 scheme 取协议。
  ModuleProtocol? protocolFor(String scheme) => _protocols[scheme];

  /// 已注册的协议 scheme。
  Iterable<String> get protocolSchemes => _protocols.keys;

  /// 某个模块的注册面板（boot 之后可用，便于诊断）。
  ModuleRegistrar? registrarOf(String moduleId) => _registrars[moduleId];

  /// 所有模块贡献的某一类对象（路由由 `core_router` 在这里取）。
  Iterable<T> contributionsOf<T extends ModuleContribution>() =>
      _registrars.values.expand((registrar) => registrar.contributionsOf<T>());

  /// 人类可读的能力清单，用于启动日志与排障。
  String describe() {
    final buffer = StringBuffer();
    for (final entry in _registrars.entries) {
      final registrar = entry.value;
      buffer.writeln(
        '- ${entry.key}: '
        '协议[${registrar.protocols.keys.join(', ')}] '
        '依赖[${registrar.dependencies.length}] '
        '贡献[${registrar.contributions.length}]',
      );
    }
    return buffer.toString().trimRight();
  }
}
