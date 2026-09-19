# Flutter 生产级模块化架构设计（Modular Architecture）

> **定位**：一套可真正用于生产环境、适合多人协作开发、并支持「每个业务模块作为独立 Git Package 独立演进」的 Flutter 模块化架构。
>
> **技术栈基线**：Pub Workspace + Melos 8 + go_router + signals + get_it + Dio + Freezed / json_serializable + very_good_analysis。
>
> **设计立场**：核心能力自研（`ModuleRegistry` / `ModuleRegistrar` / `ModuleDescriptor` / `ModuleBus` / `ModuleProtocol` / `EventBus`），**不再引入任何"大型模块化框架"**；只在状态、导航、DI、网络这些成熟问题上使用成熟的库。
>
> **实现状态**：本设计已在仓库中落地——15 个成员包、`dart analyze` 覆盖 `apps/` + `packages/` 零问题、290 个测试全部通过。
> **本文示例与真实 API 有若干差异，请以[附录 A：实现现状](#附录-a实现现状as-built)为准**（含差异清单、已知缺口与实现中发现的 API 陷阱）。

---

## 目录

| # | 章节 | 关键词 |
| --- | --- | --- |
| 1 | [核心原则](#1-核心原则) | 五个不可妥协的约束 |
| 2 | [Monorepo 目录](#2-monorepo-目录) | `apps/` + `packages/` |
| 3 | [模块内部结构](#3-模块内部结构最重要) | module / protocol / router / presentation / domain / data / state |
| 4 | [模块之间不直接依赖](#4-模块之间不直接依赖) | ModuleBus |
| 5 | [ModuleRegistry 与 AppModule](#5-moduleregistry-与-appmodule) | 模块契约 |
| 6 | [ModuleRegistry 实现](#6-moduleregistry-实现) | 注册与发现 |
| 7 | [DI：GetIt](#7-digetit) | 基础设施注入 |
| 8 | [Signals](#8-signals) | 只管状态 |
| 9 | [go_router](#9-go_router) | 只管导航 |
| 10 | [Module Protocol](#10-module-protocol) | 模块间寻址协议 |
| 11 | [EventBus](#11-eventbus) | 跨模块事件 |
| 12 | [Repository](#12-repository) | 数据抽象 |
| 13 | [包依赖关系](#13-包依赖关系) | 严禁 Feature → Feature |
| 14 | [依赖包清单](#14-依赖包清单) | 受控的依赖面 |
| 15 | [Melos + Pub Workspace](#15-melos--pub-workspace) | Monorepo 工程管理 |
| 16 | [Observability 层](#16-生产环境还需要一层observability) | 日志/崩溃/监控 |
| 17 | [最终完整版](#17-最终完整版) | 全图与职责边界 |
| A | [附录 A：实现现状（as-built）](#附录-a实现现状as-built) | 已落地的 API、差异清单、缺口、验证结果 |

---

## 1. 核心原则

整套架构建立在五条原则上，后续所有目录划分与依赖规则都是为了守住它们：

| # | 原则 | 含义 | 违反后的症状 |
| --- | --- | --- | --- |
| 1 | **业务模块独立** | 每个业务模块是可独立编译、独立测试、独立发版的 Package | 模块无法拆分到独立 Git 仓库 |
| 2 | **核心能力统一** | 网络/存储/日志/错误/配置/路由只实现一次，放在 core | 同一件事每个模块各写一份，行为漂移 |
| 3 | **模块之间协议通信** | 模块之间只通过协议与事件交互，不 import 彼此 | 出现循环依赖与"牵一发动全身" |
| 4 | **状态与导航解耦** | 状态归 signals，导航归 go_router，两者互不侵入 | 业务逻辑里散落 `context.go(...)` |
| 5 | **Pub/Melos 管理 Package** | 依赖用 Pub Workspace 解析，工程操作用 Melos 编排 | 各包 lock 不一致、CI 命令不可复现 |

整体分层：

```text
┌────────────────────────────────────────────────────────────┐
│                        Application                         │
│                                                            │
│  main_app                                                   │
│      │                                                     │
│      ▼                                                     │
│  Bootstrap                                                 │
│      │                                                     │
│      ├── ModuleRegistry                                    │
│      ├── DI Container                                      │
│      ├── Router                                            │
│      ├── EventBus                                          │
│      └── Observability                                     │
│                                                            │
└───────────────────────┬────────────────────────────────────┘
                        │
              ┌─────────┴─────────┐
              │                   │
              ▼                   ▼
       Core Packages         Feature Packages
              │                   │
              │          ┌────────┼─────────┐
              │          ▼        ▼         ▼
              │       Auth     Product    Order
              │
              ├── module
              ├── router
              ├── network
              ├── storage
              ├── logger
              ├── error
              └── config
```

---

## 2. Monorepo 目录

```text
my_flutter_app/
│
├── apps/
│   └── main_app/
│       ├── lib/
│       │   ├── main.dart
│       │   └── bootstrap.dart
│       └── pubspec.yaml
│
├── packages/
│
│   ├── core/
│   │   │
│   │   ├── core_module/
│   │   ├── core_di/
│   │   ├── core_router/
│   │   ├── core_network/
│   │   ├── core_storage/
│   │   ├── core_logger/
│   │   ├── core_error/
│   │   ├── core_config/
│   │   └── core_model/
│   │
│   ├── features/
│   │   │
│   │   ├── feature_auth/
│   │   ├── feature_user/
│   │   ├── feature_home/
│   │   ├── feature_product/
│   │   ├── feature_order/
│   │   └── feature_payment/
│   │
│   └── shared/
│       ├── design_system/
│       ├── common_widgets/
│       └── common_utils/
│
├── test/
│
├── melos.yaml
├── pubspec.yaml
└── README.md
```

目录划分意图：

| 目录 | 角色 | 演进特征 |
| --- | --- | --- |
| `apps/main_app` | 唯一的应用装配层（Bootstrap、模块清单、环境配置） | 薄，只有装配代码，几乎没有业务 |
| `packages/core/*` | 与业务无关的核心能力 | 稳定，被所有 feature 依赖 |
| `packages/features/*` | 业务模块，**各自一个 Git Package** | 频繁独立演进，互不依赖 |
| `packages/shared/*` | 设计系统、通用组件、通用工具 | 只被 UI 依赖，不含业务 |
| `melos.yaml` + 根 `pubspec.yaml` | Monorepo 工程管理与工作区定义 | 工程配置的唯一入口 |

---

## 3. 模块内部结构（最重要）

每个 feature 模块内部结构完全一致，这是「可独立演进」的物理基础：

```text
feature_product/
│
├── lib/
│   ├── feature_product.dart
│   │
│   ├── module/
│   │   ├── product_module.dart
│   │   └── product_descriptor.dart
│   │
│   ├── protocol/
│   │   └── product_protocol.dart
│   │
│   ├── router/
│   │   └── product_routes.dart
│   │
│   ├── presentation/
│   │   ├── pages/
│   │   ├── widgets/
│   │   └── controllers/
│   │
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── services/
│   │
│   ├── data/
│   │   ├── models/
│   │   ├── datasources/
│   │   └── repositories/
│   │
│   └── state/
│       └── product_signals.dart
│
├── test/
└── pubspec.yaml
```

各目录的唯一职责：

| 目录 | 职责 | 对外可见 |
| --- | --- | --- |
| `feature_product.dart` | 模块 barrel，**唯一允许被外部 import 的出口** | ✅ |
| `module/` | 实现 `AppModule` 契约，声明 descriptor、注册路由/协议/DI | ✅（仅 descriptor 与 module） |
| `protocol/` | 对外的模块协议实现（`product://...`） | ✅ |
| `router/` | 路由定义（`RouteDefinition` / `GoRoute`） | ❌ |
| `presentation/` | 页面、组件、Controller | ❌ |
| `domain/` | 实体、仓储抽象、领域服务（纯 Dart，无 Flutter） | ❌ |
| `data/` | DTO 模型、数据源、仓储实现 | ❌ |
| `state/` | signals 状态定义 | ❌ |

> 关键约束：**跨模块只能看到 barrel 暴露的 `module/` 与 `protocol/`**，
> `presentation` / `domain` / `data` / `state` 是模块私有实现，外部不得 import。

---

## 4. 模块之间不直接依赖

**不要这样写**：

```dart
// ❌ 直接依赖另一个 feature 的内部实现
import 'package:feature_product/feature_product.dart';
```

**应该这样**：

```text
Home
 │
 ▼
ModuleBus
 │
 ▼
ProductProtocol
 │
 ▼
ProductModule
```

调用方只面对协议，不面对实现：

```dart
await moduleBus.open(
  'product://detail',
  params: {
    'id': '10001',
  },
);
```

好处：

- `feature_home` 的 `pubspec.yaml` 里**不出现** `feature_product`；
- 商品模块可以独立发版、独立换实现，Home 无需重新编译；
- 模块可以被整体移除（未注册即不可达），而不会造成编译失败。

---

## 5. ModuleRegistry 与 AppModule

模块契约由 `AppModule` + `ModuleDescriptor` + `ModuleRegistrar` 三者组成：

```dart
abstract interface class AppModule {
  ModuleDescriptor get descriptor;

  void register(ModuleRegistrar registrar);
}
```

模块实现示例：

```dart
class ProductModule implements AppModule {
  @override
  ModuleDescriptor get descriptor {
    return const ModuleDescriptor(
      id: 'product',
      version: '1.0.0',
    );
  }

  @override
  void register(ModuleRegistrar registrar) {
    // 无参数页面用 registerPage，签名与 `ProductDetailPage.new` 对齐
    registrar.registerPage(
      '/product/list',
      ProductListPage.new,
    );

    // 带路径参数的页面用 registerRoute，从上下文取参数
    registrar.registerRoute(
      '/product/detail/:id',
      (context) => ProductDetailPage(id: context.pathParam('id')!),
    );

    registrar.registerProtocol(
      const ProductProtocol(),
    );
  }
}
```

> **实现差异**：`registerRoute` 的工厂签名是
> `Widget Function(ModuleRouteContext)` 而不是 `Widget Function()`——
> 否则 `/product/detail/:id` 这类带参路由无法表达。无参数页面保留了
> 文档原本的写法（`registerPage('/list', ProductListPage.new)`）。
>
> `registerRoute` 来自 `core_router` 对 `ModuleRegistrar` 的**扩展方法**：
> `core_module` 是纯 Dart 包，不认识 `Widget`；路由能力通过
> `ModuleContribution` 这个标记接口插进来。

三个角色的分工：

| 类型 | 角色 | 谁提供 | 谁消费 |
| --- | --- | --- | --- |
| `AppModule` | 模块契约（生命周期入口） | 每个 feature 模块 | `ModuleRegistry` |
| `ModuleDescriptor` | 模块身份（`id` + `version`） | 每个 feature 模块 | `ModuleRegistry`（唯一性校验、诊断） |
| `ModuleRegistrar` | 模块能力的注册面板（路由/协议/DI/事件） | core_module | 每个 feature 模块 |

> 设计要点：模块**只描述自己要注册什么**，不掌握注册表本身；
> 注册表由 `ModuleRegistry` 独占，避免模块之间通过注册表互相窥探。

---

## 6. ModuleRegistry 实现

```dart
class ModuleRegistry {
  final Map<String, AppModule> _modules = {};

  void register(AppModule module) {
    final id = module.descriptor.id;

    if (_modules.containsKey(id)) {
      throw StateError(
        'Module already registered: $id',
      );
    }

    _modules[id] = module;
  }

  T? find<T extends AppModule>() {
    for (final module in _modules.values) {
      if (module is T) {
        return module;
      }
    }

    return null;
  }
}
```

应用装配（Bootstrap 阶段）：

```dart
final registry = ModuleRegistry();

registry.register(AuthModule());
registry.register(UserModule());
registry.register(ProductModule());
registry.register(OrderModule());
```

职责边界：

| 事项 | ModuleRegistry 负责 | ModuleRegistry 不负责 |
| --- | --- | --- |
| 模块注册与去重 | ✅ | — |
| 模块发现（按类型查找） | ✅ | — |
| 依赖注入 | ❌ | GetIt |
| 路由表构建 | ❌ | 由 `ModuleRegistrar` 收集、go_router 承载 |
| 协议调用 | ❌ | ModuleBus |
| 状态管理 | ❌ | Signals |

---

## 7. DI：GetIt

GetIt 负责**基础设施依赖注入**，不参与模块发现。

```text
GetIt
 │
 ├── Dio
 ├── Logger
 ├── Storage
 ├── Config
 ├── AuthRepository
 └── ProductRepository
```

业务模块通过 `ModuleRegistrar` 注册自己的依赖。

> **实现差异**：工厂收到容器（`ServiceLocator`），因此模块可以声明式地解析
> 其它依赖，而不是只能传无参构造函数。`register` 阶段容器尚未就绪，所以
> 需要「读容器状态」的注册逻辑（例如给端口装兜底实现）用 `onBoot`：

```dart
class ProductModule implements AppModule {
  @override
  void register(ModuleRegistrar registrar) {
    // 兜底：应用没有自己提供数据源时才安装演示实现
    registrar.onBoot((locator) {
      if (!locator.isRegistered<ProductRemoteDataSource>()) {
        locator.registerLazySingleton<ProductRemoteDataSource>(
          FakeProductDataSource.new,
        );
      }
    });

    registrar.lazySingleton<ProductRepository>(
      (locator) => ProductRepositoryImpl(locator.get<ProductRemoteDataSource>()),
    );
  }
}
```

约定：

- 基础设施（Dio / Logger / Storage / Config）由 Bootstrap 在**模块注册之前**注册；
- 业务依赖由模块**自己在 register 阶段**注册，模块是自身依赖图的所有者；
- 模块之间不通过 GetIt 相互取用对方的具体实现（那是协议与事件该做的事）。

---

## 8. Signals

Signals **专门负责状态**。

不要让 Signals 负责：

- DI
- 路由
- 模块发现
- API 请求

```dart
class ProductController {
  final product = signal<Product?>(null);
  final loading = signal(false);

  Future<void> load(String id) async {
    loading.value = true;

    try {
      product.value =
          await repository.getProduct(id);
    } finally {
      loading.value = false;
    }
  }
}
```

边界说明：

| 关注点 | 归属 |
| --- | --- |
| 可写状态、派生状态 | Signals |
| 页面跳转 | go_router（由页面回调触发，Controller 不碰路由） |
| 数据获取 | Repository / DataSource |
| 对象生命周期与依赖装配 | GetIt |

---

## 9. go_router

go_router **只负责导航**。不要让它变成整个模块系统。

```dart
GoRoute(
  path: '/product/detail/:id',
  builder: (_, state) {
    return ProductDetailPage(
      id: state.pathParameters['id']!,
    );
  },
);
```

模块只提供路由定义，由框架汇聚：

```text
Module
 │
 └── RouteDefinition
          │
          ▼
      go_router
```

> 路由的**收集**属于模块系统（`ModuleRegistrar.registerRoute`），
> 路由的**解析与跳转**属于 go_router。二者不要混在同一个抽象里。

---

## 10. Module Protocol

这是这套架构比较有特色的一层。

内部统一寻址协议示例：

```text
product://detail?id=10001
user://profile?id=100
order://detail?id=888
```

统一入口：

```dart
moduleBus.open(
  'product://detail?id=10001',
);
```

未来甚至可以让外部入口也走同一条链路：

```text
Push Notification
        │
        ▼
    Deep Link
        │
        ▼
 Module Protocol
        │
        ▼
      Module
```

所以 **App 内部协议和外部 Deep Link 可以统一**：同一套协议既服务于模块间调用，也服务于通知、深链、扫码等外部唤起场景。

| 层 | 职责 |
| --- | --- |
| `ModuleProtocol` | 声明某模块能响应哪些 `scheme://host` 以及参数契约 |
| `ModuleBus` | 解析 URI → 定位模块 → 调用协议 → 返回结果 |
| 模块实现 | 真正执行动作（打开页面、查询数据、修改状态） |

---

## 11. EventBus

两者的区别要先说清楚：

| 机制 | 语义 |
| --- | --- |
| **Module Protocol** | 「**我要让你做事情**」（命令，有明确目标与结果） |
| **EventBus** | 「**我发生了事情**」（通知，无目标、不关心谁听） |

例如订单创建：

```dart
eventBus.publish(
  OrderCreatedEvent(
    orderId: '10001',
  ),
);
```

其他模块：

```text
Order
 │
 ▼
EventBus
 ├── Analytics
 ├── Coupon
 ├── Notification
 └── User
```

**Order 不需要知道这些模块存在。** 新增订阅方无需改动 Order 模块，这是跨模块解耦的主要手段。

---

## 12. Repository

生产环境一定建议保留这条链路：

```text
Presentation
      ↓
Domain
      ↓
Repository
      ↓
DataSource
```

抽象：

```dart
abstract interface class ProductRepository {
  Future<Product> getProduct(String id);
}
```

实现：

```dart
class ProductRepositoryImpl
    implements ProductRepository {

  final ProductRemoteDataSource remote;

  ProductRepositoryImpl(this.remote);

  @override
  Future<Product> getProduct(String id) {
    return remote.getProduct(id);
  }
}
```

以后这些都可以替换，而上层无感：

- API
- Local DB
- Cache
- Mock
- WebSocket

---

## 13. 包依赖关系

这是生产环境最重要的部分之一。严格控制为**单向、分层**：

```text
                 core
                  ▲
                  │
        ┌─────────┴──────────┐
        │                    │
     feature A           feature B
        │                    │
        └─────────┬──────────┘
                  │
                app
```

**Feature 不应该依赖 Feature。**

正确示例：

```text
feature_order
       │
       ├── core_module
       ├── core_di
       ├── core_network
       ├── core_model
       └── design_system
```

禁止示例：

```text
feature_order
       ↓
feature_product
       ↓
feature_user
```

依赖规则速查：

| 规则 | 说明 |
| --- | --- |
| `app` → `feature` → `core` / `shared` | ✅ 允许 |
| `feature` → `feature` | ❌ 禁止 |
| `core` → `feature` | ❌ 禁止 |
| `shared` → `feature` | ❌ 禁止 |
| `core` 内部互相依赖 | ⚠️ 需谨慎，避免成环（建议 `core_model` 最底层） |

---

## 14. 依赖包清单

依赖面**控制在这一套**：

**Runtime**

```yaml
dependencies:
  flutter:
    sdk: flutter

  go_router:
  signals:
  get_it:
  dio:

  freezed_annotation:
  json_annotation:
```

**Dev**

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

  melos:
  freezed:
  json_serializable:
  very_good_analysis:
```

**然后自己实现**：

- `ModuleRegistry`
- `ModuleRegistrar`
- `ModuleDescriptor`
- `ModuleBus`
- `ModuleProtocol`
- `EventBus`

> **不要再引入一个"大型模块化框架"。** 模块化的核心抽象不超过几百行，
> 自研可以完全掌控语义，也避免框架锁定与版本升级风险。

---

## 15. Melos + Pub Workspace

Monorepo：

```text
apps/
packages/
```

由以下两者共同管理：

```text
Dart Pub Workspace
        +
      Melos
```

Melos 主要负责：

```bash
melos bootstrap
melos run test
melos run analyze
melos run format
melos run build
```

例如：

```bash
melos run test
```

一次测试所有 package。

职责划分：

| 工具 | 负责 |
| --- | --- |
| **Pub Workspace** | 依赖解析、`pubspec.lock` 唯一性、本地包互相引用 |
| **Melos** | 批量脚本编排（analyze / test / format / build / version / publish） |

---

## 16. 生产环境还需要一层：Observability

建议再加入：

```text
core_observability/
```

统一：

- Logger
- Crash
- Analytics
- Performance
- Tracing

业务代码：

```dart
logger.error(
  'Product load failed',
  error: error,
);
```

**不要**这样：

```dart
// ❌ 第三方 SDK 直接散落在业务代码里
FirebaseCrashlytics.instance...
```

散落在业务代码里面。

> 价值：业务模块只依赖 `core_observability` 的抽象，
> 未来更换崩溃/埋点/性能供应商时，改动局限在 core 包内。

---

## 17. 最终完整版

最终定稿架构：

```text
                         APP
                          │
                    ┌─────▼─────┐
                    │ Bootstrap │
                    └─────┬─────┘
                          │
                  ModuleRegistry
                          │
              ┌───────────┴───────────┐
              │                       │
       ModuleRegistrar            ModuleBus
              │                       │
       ┌──────┼──────┐                │
       │      │      │                │
       ▼      ▼      ▼                ▼
      DI     Route  Protocol       Feature
       │      │      │                │
       │      ▼      ▼                │
       │ go_router  EventBus          │
       │                             │
       └──────────────┬──────────────┘
                      │
                   Feature
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
      Presentation  Domain       Data
          │           │           │
       Signals    Repository   DataSource
                                  │
                           ┌──────┴──────┐
                           ▼             ▼
                         Dio          Storage
```

### 核心职责表

这套架构的核心职责非常明确：

| 东西 | 只负责什么 |
| --- | --- |
| Pub Workspace | Package 依赖 |
| Melos | Monorepo 工程管理 |
| ModuleRegistry | 模块生命周期 / 发现 |
| ModuleRegistrar | 模块能力注册 |
| ModuleBus | 模块调用 |
| EventBus | 跨模块事件 |
| GetIt | DI |
| Signals | 状态 |
| go_router | 导航 |
| Repository | 数据抽象 |
| Dio | 网络 |
| Storage | 持久化 |
| Observability | 日志 / 崩溃 / 监控 |

### 为什么是这一套

这比单纯的 **Riverpod + go_router + Melos** 模块化更完整，而且特别适合
「每个业务模块独立 Git Package」的路线：

- 每个 feature 的依赖面被限制在 `core` + `shared`，**可整包搬运到独立仓库**；
- 模块之间只有协议与事件两种耦合方式，**可以独立发版**；
- 状态、导航、DI、网络各自只有一个负责人，**新人上手路径清晰**；
- 模块化能力自研且极薄，**不锁定任何框架**。

---

## 附录 A：实现现状（as-built）

> 上文是**设计**；本附录是**已落地的实现**，以及与设计不一致的地方。
> 核对结果：`dart analyze` 覆盖 `apps/` + `packages/` **零问题**，15 个成员包
> 共 **290 个测试全部通过**。

### A.1 实际工作区结构

```text
module/                              # 工作区根：module_workspace（纯配置宿主，非应用包）
├── apps/
│   └── main_app/                    # 应用装配层（含 android/ios/web/linux/macos/windows）
│       └── lib/
│           ├── main.dart            # 入口：读 DEEP_LINK → Bootstrap → runApp
│           ├── bootstrap.dart       # 唯一的装配点（Composition Root）
│           └── src/app.dart         # ModuleApp：只把路由器交给 CupertinoApp.router
├── packages/
│   ├── core/                        # 11 个核心包
│   │   ├── core_model/       core_error/         core_config/
│   │   ├── core_logger/      core_di/            core_storage/
│   │   ├── core_session/     core_observability/
│   │   ├── core_network/     core_router/        core_module/
│   ├── features/
│   │   ├── feature_auth/            # 由 packages/login 迁移
│   │   └── feature_home/            # 由 packages/home 迁移
│   └── shared/
│       └── design_system/           # 由 packages/ui_kit 迁移
├── docs/
└── pubspec.yaml                     # workspace: apps/main_app + packages/{core,features,shared}/*
```

包职责对照（设计第 17 章 → 实际落地）：

| 设计中的角色 | 实际包 | 说明 |
| --- | --- | --- |
| ModuleRegistry / ModuleRegistrar / ModuleBus / EventBus | `core_module` | **纯 Dart**，不依赖 Flutter |
| Router / RouteDefinition | `core_router` | 通过 `ModuleContribution` 扩展接入模块系统 |
| DI | `core_di` | `ServiceLocator` 门面（封装 GetIt） |
| 会话状态 | `core_session` | **设计清单外新增**，理由见 A.3 |
| Observability | `core_observability` | 门面 + 端口 + noop 实现 |
| Network | `core_network` | Dio 装配 + 错误归一化 |
| Storage | `core_storage` | `KeyValueStore` 端口 + 内存实现 + JSON 助手 |
| Logger / Error / Config / Model | `core_logger` `core_error` `core_config` `core_model` | |
| design_system | `shared/design_system` | |

### A.2 模块内部结构（以 `feature_auth` 为样板）

```text
packages/features/feature_auth/
├── lib/
│   ├── feature_auth.dart            # 公开契约：module + protocol + 需被实现的端口
│   ├── testing.dart                 # 测试/演示入口：只导出 FakeAuthService
│   └── src/
│       ├── module/                  # auth_descriptor / auth_events / auth_module
│       ├── protocol/                # auth_protocol（scheme = 'auth'）
│       ├── router/                  # auth_routes（registerAuthRoutes）
│       ├── presentation/
│       │   ├── pages/               # login_page / reset_password_page
│       │   ├── widgets/             # countdown_code_button / demo_hint
│       │   └── controllers/         # login_controller / reset_password_controller
│       ├── domain/
│       │   ├── entities/            # sms_code_receipt
│       │   ├── repositories/        # auth_repository（抽象端口）
│       │   └── services/            # 三个校验器 + auth_failure
│       └── data/
│           ├── datasources/         # auth_service（端口）/ fake_auth_service
│           └── repositories/        # auth_repository_impl
├── test/                            # 与 src/ 同构镜像
└── pubspec.yaml
```

`feature_home` 是「纯视图模块」，因此只有 `module/` + `protocol/` + `router/` +
`presentation/pages/`——**故意不建** `domain/`、`data/`、`state/`。

### A.3 与设计的差异（含理由）

| # | 设计 | 实际实现 | 理由 |
| --- | --- | --- | --- |
| 1 | core 清单 9 个包 | 新增 `core_session` | 「feature 不得互相依赖」+「登录态需被首页读取」两条约束同时成立时，会话契约必须下沉到 core，否则 home 只能依赖 auth |
| 2 | `registerRoute(path, ProductDetailPage.new)` | `registerPage(path, Widget Function())` + `registerRoute(path, Widget Function(ModuleRouteContext))` | 原签名无法表达 `/detail/:id`；无参页面保留原写法 |
| 3 | `ModuleProtocol` 直接执行动作 | `handle()` 返回 `ModuleResponse`（如 `navigate('/x')`），由 `ModuleBus` 通过 `ModuleNavigator` 端口落地 | 协议保持纯翻译 ⇒ 可 `const` 构造、可脱离 Flutter 单测 |
| 4 | `registrar.singleton<T>(T Function())` | `registrar.singleton<T>(T Function(ServiceLocator))` | 工厂需要解析其它依赖；同时新增 `onBoot()` 表达「应用没提供才装兜底实现」 |
| 5 | barrel 只暴露 module + protocol | 另加「其它层必须实现的端口」（`AuthService` 及其异常/回执类型），假实现单独放 `testing.dart` | 应用层是 composition root，必须能实现端口接真实后端；把 fake 挪到 `testing.dart` 后生产代码无法误用 |
| 6 | 每个 feature 都有 `state/` | `feature_auth` 无 `state/` | 会话状态在 `core_session`，页面级状态在 `presentation/controllers`；不为对齐模板造空目录 |
| 7 | 根目录有 `melos.yaml` | melos 配置仍在根 `pubspec.yaml` 的 `melos:` 段 | Melos 8 原生支持该写法且当前可用；拆出 `melos.yaml` 属于纯搬迁，留待需要时再做 |
| 8 | dev 依赖含 `very_good_analysis` | 已声明，但实际生效的是 `flutter_lints` | 换用 very_good_analysis 会对既有代码产生大量新增 lint，需单独一次批量整改 |
| 9 | 应用包名 `module` | 根为 `module_workspace`（非包），应用为 `apps/main_app`（`name: main_app`） | 工作区根不应同时是应用包；`useRootAsPackage: false` |
| 10 | 模块清单示例 6 个 feature | 实际 2 个（`feature_auth` / `feature_home`） | 只落地真实存在的业务；`feature_product` / `feature_order` 等仍为示例 |

### A.4 尚未实现 / 已知缺口

| 项 | 现状 | 触发条件 |
| --- | --- | --- |
| `core_network` 生产消费方 | 无：演示环境用 `FakeAuthService`，不发起真实请求 | 接入真实后端时，实现 `AuthService` 的 HTTP 版本 |
| `core_storage` 持久化实现 | 只有 `InMemoryKeyValueStore`（会话可写入但重启即失） | 需要真正的本地持久化时，引入存储插件并新增一个 `KeyValueStore` 实现 |
| `shared/common_widgets`、`shared/common_utils` | 未创建 | 出现**跨模块**共享的非设计系统代码时再建，避免空壳包 |
| feature 独立 Git 仓库 | 未拆分：仍在一个 monorepo 内 | 依赖面已收敛到 `core` + `shared`，具备整包搬运条件 |
| protocol 的无 UI 动作 | `ModuleBus` 已支持（`ModuleResponse.value/done`），但暂无此类协议实例 | 出现「调用模块做一件事并取返回值」的真实需求时 |
| `ModuleDescriptor.requires` | 已实现并在 boot 校验，实际两个模块都无此声明 | 出现真实的协议级依赖时 |

### A.5 验证结果

`dart analyze apps packages` → **No issues found!**（Melos 以 `--fatal-infos`
运行，因此 info 级 lint 也必须为零）

| 包 | 用例数 | 包 | 用例数 |
| --- | --- | --- | --- |
| core_module | 51 | core_network | 22 |
| core_session | 19 | core_router | 18 |
| core_error | 12 | core_logger | 12 |
| core_model | 11 | core_config | 11 |
| core_storage | 11 | core_observability | 11 |
| core_di | 7 | design_system | 4 |
| **feature_auth** | **93** | **feature_home** | **3** |
| main_app（端到端） | 5 | **合计** | **290** |

`main_app` 的 5 个端到端用例走的是**真实装配链路**（`Bootstrap.run` →
`ModuleRegistry.boot` → 模块路由 → `EventBus` → 跳转），其中两个专门验证
深链：`home://root` 经 Module Protocol 直达首页，未注册的 scheme 不阻塞启动。

### A.6 实现过程中暴露并修掉的真实陷阱

这些是设计文档看不出来、只有跑起来才会发现的问题，记录下来避免重犯：

1. **`go_router` 的 `push()` Future 只在被压入页面 `pop()` 时才完成**。
   `AppNavigator.push` 若 `await` 它，调用方会一直挂起（测试表现为 10 分钟超时）。
   现在 `push` 显式 fire-and-forget。
2. **`signals` 7 的 `subscribe()` 会立即回调一次当前值**，而不是等首次变更。
   按「订阅后只收变更」写断言会多出一个初始值。
3. **dio 5.11 新增了 `DioExceptionType.transformTimeout`**，
   对它做 `switch` 如果不写全就会编译失败（非穷尽）。已归入 timeout 语义。
4. **重复 dispose 会让 go_router 抛 "used after being disposed"**。
   `Bootstrap.dispose()` 因此做成幂等。
5. **`MemoryLogger.child()` 若不共享父缓冲**，在父 logger 上断言子来源日志会
   得到空列表；已改为共享同一缓冲（与真实日志层级语义一致）。
6. **dio 5.11 默认注入 `ImplyContentTypeInterceptor`**，
   所以「未配置拦截器」不能断言 `interceptors.isEmpty`，要按类型断言。
