# LoggerKit TCA 重构方案

## 目录

1. [重构原则](#重构原则)
2. [架构设计](#架构设计)
3. [编码规范](#编码规范)
4. [使用指南](#使用指南)
5. [性能优化](#性能优化)
6. [测试指南](#测试指南)
7. [迁移指南](#迁移指南)
8. [API 参考](#api-参考)
9. [实现细节](#实现细节)

---

## 重构原则

对日志组件做彻底的 TCA 改造,遵循以下原则:

- ✅ **轻量化**: 采用轻量 TCA 结构,不从外部引入 TCA 架构
- ✅ **完全重构**: 不考虑现有 API 兼容性(注:实际实现通过 Facade 模式保持了兼容)
- ✅ **单向数据流**: 所有状态变化通过 Action → Reducer → State 流动
- ✅ **副作用隔离**: 网络、数据库等副作用封装在 Effect 中
- ✅ **可测试性**: 所有逻辑可通过纯函数测试

---

## 架构设计

### TCA 核心概念

LoggerKit 实现了一套轻量级的 TCA (The Composable Architecture) 架构,包含以下核心组件:

#### 1. State (状态)

不可变的数据结构,描述应用在某一时刻的完整状态。采用 **嵌套定义 + 组合模式**,由多个子 Feature State 组成。

```swift
// 顶层 Feature (嵌套定义)
struct LogFeature {
    // State 定义在 Feature 内部
    struct State: Equatable {
        // 子 Feature State
        var list: LogList.State = .init()
        var filter: Filter.State = .init()
        var search: Search.State = .init()
        var export: Export.State = .init()
        var delete: Delete.State = .init()

        // UI 状态(跨 Feature 共享)
        var isFilterPresented: Bool = false
        var isSearchPresented: Bool = false
        var isExportPresented: Bool = false
        var isDeletePresented: Bool = false

        // 全局错误
        var globalError: String?
    }
}

// 子 Feature State 示例
struct LogList {
    struct State: Equatable {
        var events: [LogEvent] = []
        var totalCount: Int = 0
        var loadingState: LoadingState = .idle
        var currentPage: Int = 0
        var hasMore: Bool = true
        var querySequenceNumber: Int = 0
        var activeQuerySequence: Int = 0

        mutating func resetPagination() {
            currentPage = 0
            hasMore = true
            querySequenceNumber += 1
        }
    }
}

struct Filter {
    struct State: Equatable {
        var selectedLevels: Set<LogLevel> = []
        var selectedFunctions: Set<String> = []
        var selectedFileNames: Set<String> = []
        var startDate: Date?
        var endDate: Date?

        var availableFunctions: [String] = []
        var availableFileNames: [String] = []

        var hasActiveFilters: Bool {
            !selectedLevels.isEmpty || !selectedFunctions.isEmpty ||
            !selectedFileNames.isEmpty || startDate != nil || endDate != nil
        }

        mutating func reset() {
            selectedLevels.removeAll()
            selectedFunctions.removeAll()
            selectedFileNames.removeAll()
            startDate = nil
            endDate = nil
        }
    }
}

struct Search {
    struct State: Equatable {
        var searchText: String = ""
        var selectedSearchFields: Set<SearchField> = [.message]
        var searchResults: CategorizedSearchResults?
        var isSearching: Bool = false
        var allEventsForPreview: [LogEvent] = []
    }
}

struct Export {
    struct State: Equatable {
        var format: ExportFormat = .json
        var isExporting: Bool = false
        var progress: Double = 0
        var exportedCount: Int = 0
        var totalCount: Int = 0
        var exportedURL: URL?
        var error: String?
    }
}

struct Delete {
    struct State: Equatable {
        var selectedSessionIds: Set<String> = []
        var availableSessions: [SessionInfo] = []
        var isDeleting: Bool = false
        var deleteProgress: Double = 0
        var error: String?
    }
}
```

#### 2. Action (动作)

枚举类型,描述系统中所有可能的状态变化。采用 **嵌套定义 + 路由模式**,通过关联值路由到子 Feature。

```swift
// 顶层 Feature (嵌套定义)
struct LogFeature {
    // Action 定义在 Feature 内部
    enum Action: Equatable {
        // 子 Feature Action(嵌套路由)
        case list(LogList.Action)
        case filter(Filter.Action)
        case search(Search.Action)
        case export(Export.Action)
        case delete(Delete.Action)

        // UI 状态管理(协调层)
        case setFilterPresented(Bool)
        case setSearchPresented(Bool)
        case setExportPresented(Bool)
        case setDeletePresented(Bool)

        // 跨 Feature 通信(协调层)
        case filterChanged          // Filter → List(重新加载)
        case searchCompleted        // Search → (关闭搜索面板)
        case exportCompleted(URL)   // Export → (显示分享)
        case deleteCompleted        // Delete → List(刷新)
    }
}

// 子 Feature Action 示例
struct LogList {
    enum Action: Equatable {
        case loadLogFile
        case loadMore
        case refresh
        case logsLoaded(Result<[LogEvent], Error>, sequence: Int)
        case totalCountLoaded(Int)
        case loadFailed(String)
        case resetPagination
    }
}

struct Filter {
    enum Action: Equatable {
        case toggleLevel(LogLevel)
        case addFunction(String)
        case removeFunction(String)
        case setStartDate(Date?)
        case setEndDate(Date?)
        case resetFilters
        case applyFilters               // 触发 LogFeature.filterChanged
        case loadAvailableOptions
        case availableOptionsLoaded(functions: [String], fileNames: [String])
    }
}

struct Search {
    enum Action: Equatable {
        case updateSearchText(String)
        case toggleSearchField(SearchField)
        case executeSearch
        case searchCompleted(CategorizedSearchResults)
        case searchFailed(String)
        case clearSearch
    }
}

struct Export {
    enum Action: Equatable {
        case selectFormat(ExportFormat)
        case startExport
        case updateProgress(progress: Double, count: Int, total: Int)
        case exportCompleted(Result<URL, Error>)
        case cancelExport
    }
}

struct Delete {
    enum Action: Equatable {
        case loadSessions
        case sessionsLoaded([SessionInfo])
        case toggleSession(String)
        case selectAllSessions
        case deselectAllSessions
        case confirmDelete
        case updateProgress(Double)
        case deleteCompleted(Result<Void, Error>)
    }
}
```

#### 3. Reducer (归约器)

纯函数,接收当前状态和动作,返回新状态和副作用。

```swift
protocol Reducer {
    associatedtype State
    associatedtype Action

    func reduce(_ state: inout State, _ action: Action) -> Effect<Action>
}
```

**核心特性**:
- ✅ **纯函数**: 相同输入必定产生相同输出
- ✅ **不可变性**: 通过 `inout` 修改状态,避免复制开销
- ✅ **可组合**: 多个小 Reducer 组合成大 Reducer

#### 4. Effect (副作用)

封装异步操作(网络、数据库、定时器等)的容器。

```swift
enum Effect<Action> {
    case none                                    // 无副作用
    case task(() async -> Action)                // 单个异步任务
    case cancellable(id: AnyHashable, () async -> Action)  // 可取消任务
    case multiple([Effect<Action>])              // 多个副作用
}
```

**特性**:
- ✅ **可取消**: 通过 `id` 标识,新请求自动取消旧请求
- ✅ **可组合**: 通过 `.merge()` 和 `.concatenate()` 组合多个 Effect
- ✅ **类型安全**: 保证 Effect 返回的 Action 类型正确

#### 5. Store (存储)

运行时,连接 View 和 Reducer,驱动整个数据流。

```swift
@MainActor
class Store<State, Action>: ObservableObject {
    @Published private(set) var state: State

    func send(_ action: Action) async {
        let effect = reducer.reduce(&state, action)
        await executeEffect(effect)
    }
}
```

**职责**:
- ✅ 维护当前状态(`@Published state`)
- ✅ 派发 Action (`send(_:)`)
- ✅ 执行 Effect 并处理结果
- ✅ 管理 Task 的生命周期(取消、清理)

---

### 数据流图

Feature-based 架构的数据流,展示嵌套 Action 路由和跨 Feature 通信:

```
┌─────────────────────────────────────────────────────────────┐
│                         用户交互                              │
│         (点击筛选、输入搜索、滚动列表、点击导出)                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    LogDetailScene (View)                     │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  // 列表操作                                            │ │
│  │  store.send(.list(.loadLogFile))                       │ │
│  │  store.send(.list(.loadMore))                          │ │
│  │                                                         │ │
│  │  // 筛选操作                                            │ │
│  │  Button("Filter") {                                    │ │
│  │      store.send(.setFilterPresented(true))             │ │
│  │  }                                                      │ │
│  │                                                         │ │
│  │  // FilterView 中:                                      │ │
│  │  Toggle { store.send(.filter(.toggleLevel(.error))) }  │ │
│  │  Button("Apply") { store.send(.filter(.applyFilters)) }│ │
│  └────────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────────┘
                         │ 嵌套 Action
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              LogFeatureStore (Store)                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  @Published var state: LogFeature.State                │ │
│  │                                                         │ │
│  │  func send(_ action: LogFeature.Action) async {        │ │
│  │      let effect = reducer.reduce(&state, action)       │ │
│  │      await executeEffect(effect)                       │ │
│  │  }                                                      │ │
│  └────────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────────┘
                         │ (LogFeature.State, LogFeature.Action)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│          LogFeature.Reducer (协调器 - 路由层)                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  func reduce(_ state: inout LogFeature.State,          │ │
│  │               _ action: LogFeature.Action)             │ │
│  │      -> Effect<LogFeature.Action> {                    │ │
│  │                                                         │ │
│  │      switch action {                                   │ │
│  │      // 路由到子 Feature                               │ │
│  │      case .list(let listAction):                       │ │
│  │          return listReducer.reduce(&state.list, ...)   │ │
│  │              .map { .list($0) }  ← 转换回顶层 Action   │ │
│  │                                                         │ │
│  │      case .filter(let filterAction):                   │ │
│  │          let effect = filterReducer.reduce(...)        │ │
│  │          if case .applyFilters = filterAction {        │ │
│  │              // 跨 Feature 通信                         │ │
│  │              return .multiple([                         │ │
│  │                  effect.map { .filter($0) },           │ │
│  │                  .task { .filterChanged }  ← 协调 Action│ │
│  │              ])                                         │ │
│  │          }                                              │ │
│  │          return effect.map { .filter($0) }             │ │
│  │                                                         │ │
│  │      // 协调层:跨 Feature 通信                          │ │
│  │      case .filterChanged:                              │ │
│  │          state.list.resetPagination()                  │ │
│  │          state.isFilterPresented = false               │ │
│  │          return .task { .list(.loadLogFile) }          │ │
│  │      }                                                  │ │
│  │  }                                                      │ │
│  └────────────────────────────────────────────────────────┘ │
└────┬────────────────────────────────────────────────────┬───┘
     │                                                    │
     │ 路由到子 Feature Reducer                            │
     ▼                                                    ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ LogListReducer   │  │ FilterReducer    │  │ SearchReducer    │
│                  │  │                  │  │                  │
│ reduce(          │  │ reduce(          │  │ reduce(          │
│   &state.list,   │  │   &state.filter, │  │   &state.search, │
│   listAction     │  │   filterAction   │  │   searchAction   │
│ )                │  │ )                │  │ )                │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                     │
         │ Effect<ListAction>  │ Effect<FilterAction>│
         └─────────────────────┴─────────────────────┘
                               │
                               │ .map { .feature($0) } ← 转换
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Effect 执行器                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  case .list(.loadLogFile):                             │ │
│  │      .task {                                            │ │
│  │          let events = await dataLoader.loadLogs(       │ │
│  │              using: state.filter  ← 读取筛选状态        │ │
│  │          )                                              │ │
│  │          return .list(.logsLoaded(.success(events)))   │ │
│  │      }                                                  │ │
│  │          ↓                                              │ │
│  │      数据库查询 → 返回结果                               │ │
│  │          ↓                                              │ │
│  │      send(.list(.logsLoaded(...)))  ← 递归回到 Store   │ │
│  └────────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────────┘
                         │ 新 LogFeatureState
                         │ (state.list.events 已更新)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              SwiftUI 自动重新渲染 View                        │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  List(store.state.list.events) { event in             │ │
│  │      LogRowView(event)  ← 渲染新数据                   │ │
│  │  }                                                      │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

### 跨 Feature 通信流程示例

#### 场景:用户应用筛选条件

```
1. 用户点击"应用筛选"
   └─> View 派发:store.send(.filter(.applyFilters))

2. LogFeatureReducer 路由到 FilterReducer
   └─> FilterReducer 处理:state.filter 已更新
   └─> 返回 Effect (例如保存筛选偏好)

3. LogFeatureReducer 检测到 .applyFilters
   └─> 触发协调 Action:.filterChanged
   └─> 返回 .multiple([filterEffect, .task { .filterChanged }])

4. LogFeatureReducer 处理 .filterChanged
   └─> state.list.resetPagination()  (重置分页)
   └─> state.isFilterPresented = false  (关闭筛选面板)
   └─> 返回 .task { .list(.loadLogFile) }  (触发重新加载)

5. LogFeatureReducer 路由到 ListReducer
   └─> ListReducer.reduce(&state.list, .loadLogFile)
   └─> 读取 state.filter 构建查询条件
   └─> 返回 Effect:数据库查询

6. Effect 执行
   └─> 数据库返回筛选后的日志
   └─> 派发:.list(.logsLoaded(.success(events)))

7. ListReducer 更新 state.list.events
   └─> SwiftUI 自动重绘列表
```

---

**Feature-based 架构的关键流程**:

1. **用户操作** → View 派发 **嵌套 Action**(如 `.filter(.toggleLevel(.error))`)
2. **LogFeatureReducer** 根据 Action 类型 **路由** 到对应的子 Reducer
3. **子 Reducer** 处理业务逻辑,更新 **子 Feature State**,返回 **子 Effect**
4. **LogFeatureReducer** 使用 `.map { .feature($0) }` 将子 Effect 转换为顶层 Effect
5. **协调层** 处理 **跨 Feature 通信**(如 `.filterChanged` 触发 List 重新加载)
6. **Store** 更新 State(触发 SwiftUI 重绘)
7. **Store** 执行 Effect(异步任务)
8. **Effect** 完成后派发新 Action(递归回到步骤 2)

---

### 模块结构

采用 **Feature-based** 架构,将功能拆分为 5 个独立的 Feature:

```
Sources/LoggerKit/UI/
│
├── TCA/                              # TCA 核心架构层
│   ├── Effect.swift                  # Effect 类型和组合器
│   ├── Reducer.swift                 # Reducer 协议和组合
│   └── Store.swift                   # Store 实现
│
├── Features/
│   ├── LogFeature/                   # 顶层 Feature(协调层)
│   │   └── LogFeature.swift          # 嵌套定义 State/Action/Reducer/Environment
│   │       // struct LogFeature {
│   │       //     struct State { }
│   │       //     enum Action { }
│   │       //     struct Reducer { }
│   │       //     struct Environment { }
│   │       // }
│   │
│   ├── LogList/                      # 日志列表 Feature
│   │   └── LogList.swift             # 嵌套定义
│   │       // struct LogList {
│   │       //     struct State { }
│   │       //     enum Action { }
│   │       //     struct Reducer { }
│   │       // }
│   │
│   ├── Filter/                       # 筛选 Feature
│   │   └── Filter.swift              # 嵌套定义
│   │
│   ├── Search/                       # 搜索 Feature
│   │   └── Search.swift              # 嵌套定义
│   │
│   ├── Export/                       # 导出 Feature
│   │   └── Export.swift              # 嵌套定义
│   │
│   └── Delete/                       # 删除 Feature
│       └── Delete.swift              # 嵌套定义
│
├── LogDetailSceneState.swift         # Facade 兼容层(保持旧 API)
└── LogDetailScene.swift              # SwiftUI View
```

**方案 A 的文件组织优势**:
- ✅ **单文件包含完整 Feature**: 一个 `LogFeature.swift` 包含 State/Action/Reducer/Environment
- ✅ **命名空间自然**: 通过 `struct LogFeature { }` 嵌套,自动获得 `LogFeature.State` 命名空间
- ✅ **代码关联性强**: 相关代码在同一文件,易于理解和维护
- ✅ **符合 Swift 惯例**: 类似标准库的 `Result.success` / `Optional.none` 风格

---

### 架构设计亮点

#### 1. **Feature 独立性**

每个 Feature 都是完全独立的模块,包含:
- ✅ **State**: 该 Feature 的完整状态
- ✅ **Action**: 该 Feature 的所有操作
- ✅ **Reducer**: 该 Feature 的业务逻辑

**优势**:
- 易于复用(可以将 FilterFeature 用于其他列表场景)
- 易于测试(每个 Feature 可独立测试)
- 易于维护(修改 Filter 不影响 List)
- 易于并行开发(不同团队成员负责不同 Feature)

#### 2. **协调层设计**

`LogFeatureReducer` 作为协调器,负责:
- ✅ **路由**: 将 Action 路由到对应的子 Reducer
- ✅ **组合**: 将子 Reducer 返回的 Effect 合并
- ✅ **通信**: 处理跨 Feature 通信(如筛选变化触发列表重新加载)

```swift
// LogFeature/LogFeature.swift
struct LogFeature {
    struct State: Equatable { /* ... */ }
    enum Action: Equatable { /* ... */ }

    // Reducer 定义在 Feature 内部
    struct Reducer {
        let environment: Environment

        // 子 Reducer
        private var listReducer: LogList.Reducer
        private var filterReducer: Filter.Reducer
        private var searchReducer: Search.Reducer
        private var exportReducer: Export.Reducer
        private var deleteReducer: Delete.Reducer

        func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            // 路由到子 Reducer
            case .list(let listAction):
                return listReducer.reduce(&state.list, listAction)
                    .map { .list($0) }

            case .filter(let filterAction):
                let effect = filterReducer.reduce(&state.filter, filterAction)

                // 筛选应用后,触发列表重新加载
                if case .applyFilters = filterAction {
                    return .multiple([
                        effect.map { .filter($0) },
                        .task { .filterChanged }
                    ])
                }

                return effect.map { .filter($0) }

            // 跨 Feature 通信
            case .filterChanged:
                state.list.resetPagination()
                state.isFilterPresented = false
                return .task { .list(.loadLogFile) }

            case .deleteCompleted:
                state.isDeletePresented = false
                return .task { .list(.refresh) }

            // ... 其他路由逻辑
            }
        }
    }

    // Environment 也定义在 Feature 内部
    struct Environment {
        let dataLoader: LogDataLoaderProtocol
        let databaseManager: LogDatabaseManagerProtocol

        static let live = Environment(
            dataLoader: LogDataLoader.shared,
            databaseManager: LogDatabaseManager.shared
        )

        static func mock(
            dataLoader: LogDataLoaderProtocol = MockLogDataLoader(),
            databaseManager: LogDatabaseManagerProtocol = MockLogDatabaseManager()
        ) -> Environment {
            Environment(dataLoader: dataLoader, databaseManager: databaseManager)
        }
    }
}

// 便捷类型别名
typealias LogFeatureStore = Store<LogFeature.State, LogFeature.Action>
```

#### 3. **Feature 间通信**

支持三种通信方式:

##### 方式 1: 通过父 Reducer 协调

```swift
// Filter 应用后通知父 Reducer
case .filter(.applyFilters):
    return .task { .filterChanged }

// 父 Reducer 触发 List 重新加载
case .filterChanged:
    return .task { .list(.loadLogFile) }
```

##### 方式 2: 通过共享 State

```swift
// List Reducer 可以读取 Filter State
func reduce(_ parentState: inout LogFeatureState, _ action: LogListAction) {
    let currentFilters = parentState.filter  // 读取筛选状态
    // 使用筛选条件加载数据
}
```

##### 方式 3: 通过 Environment 共享依赖

```swift
struct LogFeatureEnvironment {
    let dataLoader: LogDataLoaderProtocol
    let databaseManager: LogDatabaseManagerProtocol

    // 共享的筛选条件访问器
    func loadLogs(using filter: FilterState) async throws -> [LogEvent] {
        return try await dataLoader.loadLogs(/* 使用 filter 构建查询 */)
    }
}
```

#### 4. **State 组合模式**

顶层 State 通过组合子 Feature State 构成:

```swift
// LogFeature.swift
struct LogFeature {
    struct State: Equatable {
        // 子 Feature State(独立)
        var list: LogList.State = .init()
        var filter: Filter.State = .init()
        var search: Search.State = .init()
        var export: Export.State = .init()
        var delete: Delete.State = .init()

        // 跨 Feature 共享的 UI 状态
        var isFilterPresented: Bool = false
        var isSearchPresented: Bool = false
        var isExportPresented: Bool = false
        var isDeletePresented: Bool = false

        // 全局错误
        var globalError: String?
    }
}
```

**优势**:
- ✅ 清晰的职责边界(list 管理列表,filter 管理筛选)
- ✅ 避免状态冗余(不需要在多处同步相同数据)
- ✅ 易于调试(可以独立查看每个 Feature 的状态)

---

## 编码规范

### Action 命名约定

为保证代码一致性和可读性,所有 Action 命名遵循以下规则:

#### 1. 用户操作(命令型 Action)

使用**动词原形**,表示用户发起的操作或系统需要执行的命令。

```swift
// ✅ 正确示例
case loadLogFile           // 加载日志文件
case loadMore              // 加载更多
case refresh               // 刷新列表
case toggleLevel(LogLevel) // 切换日志级别
case applyFilters          // 应用筛选
case executeSearch         // 执行搜索
case startExport           // 开始导出
case confirmDelete         // 确认删除

// ❌ 错误示例
case loadingLogFile        // 不要用进行时
case loaded                // 不要用过去时表示命令
```

#### 2. 系统反馈(事件型 Action)

使用**过去时 + 结果**,表示异步操作已完成或系统事件已发生。

```swift
// ✅ 正确示例
case logsLoadSucceeded([LogEvent], sequence: Int)  // 日志加载成功
case logsLoadFailed(String)                        // 日志加载失败
case totalCountLoaded(Int)                         // 总数已加载
case filtersApplied                                // 筛选已应用
case searchCompleted(CategorizedSearchResults)     // 搜索已完成
case exportSucceeded(URL)                          // 导出成功
case deleteFailed(Error)                           // 删除失败

// ❌ 错误示例
case logsLoaded(Result<[LogEvent], Error>)  // 不要混用 Result,应拆分为 success/failed
case loadFailed(String)                      // 命名应明确是什么操作失败
```

**Result 处理规范**:
- Effect 返回时可以使用 `Result<T, Error>`
- 在 Reducer 内部应立即拆分为 `success` 和 `failed` 两个独立 Action
- 状态更新时使用具体的成功/失败 Action

```swift
// Effect 返回 Result
.task {
    let result = await dataLoader.loadLogs(...)
    return .logsLoaded(result)  // Result 包装
}

// Reducer 拆分处理
case .logsLoaded(let result):
    switch result {
    case .success(let events):
        return handleSuccess(&state, events)  // 内部处理成功
    case .failure(let error):
        return handleFailure(&state, error)   // 内部处理失败
    }

// 或者直接在 Effect 中拆分(推荐)
.task {
    do {
        let events = try await dataLoader.loadLogs(...)
        return .logsLoadSucceeded(events, sequence: querySequence)
    } catch {
        return .logsLoadFailed(error.localizedDescription)
    }
}
```

#### 3. 跨 Feature 通信(协调型 Action)

使用**名词 + Changed/Completed**,表示某个状态或操作的变化通知。

```swift
// ✅ 正确示例
case filterChanged          // 筛选条件已改变
case searchTextChanged      // 搜索文本已改变
case exportCompleted(URL)   // 导出已完成
case deleteCompleted        // 删除已完成

// ❌ 错误示例
case onFilterChange         // 不要用 on 前缀
case filterUpdate           // 不要用 update(太模糊)
```

#### 4. UI 状态管理(设置型 Action)

使用 **set + 属性名** 或 **toggle + 属性名**。

```swift
// ✅ 正确示例
case setFilterPresented(Bool)    // 设置筛选面板显示状态
case setSearchPresented(Bool)    // 设置搜索面板显示状态
case toggleSearchField(SearchField) // 切换搜索字段

// ❌ 错误示例
case showFilter(Bool)        // 不够明确
case presentFilter           // 缺少参数
```

#### 5. 命名一致性检查清单

- [ ] 用户操作使用动词原形
- [ ] 系统反馈使用过去时
- [ ] Result 在 Reducer 内部拆分,不直接存储
- [ ] 跨 Feature 通信使用 Changed/Completed 后缀
- [ ] UI 状态管理使用 set/toggle 前缀
- [ ] 命名清晰表达操作意图

---

### State 组织原则

State 应该按照职责明确划分,避免重复和混乱。

#### 1. 子 Feature State 包含

```swift
struct LogList {
    struct State: Equatable {
        // ✅ 该 Feature 的业务数据
        var events: [LogEvent] = []
        var totalCount: Int = 0

        // ✅ 该 Feature 的加载状态
        var loadingState: LoadingState = .idle
        var error: String?

        // ✅ 该 Feature 的分页状态
        var currentPage: Int = 0
        var hasMore: Bool = true
        var querySequenceNumber: Int = 0

        // ❌ 不应包含其他 Feature 的数据
        // var selectedFilters: Set<LogLevel>  // 这应该在 Filter.State
    }
}
```

#### 2. 顶层 State 包含

```swift
struct LogFeature {
    struct State: Equatable {
        // ✅ 子 Feature State 的组合
        var list: LogList.State = .init()
        var filter: Filter.State = .init()
        var search: Search.State = .init()

        // ✅ 跨 Feature 共享的 UI 状态(影响多个 Feature)
        var isFilterPresented: Bool = false  // 筛选面板显示状态
        var isSearchPresented: Bool = false  // 搜索面板显示状态

        // ✅ 全局错误/提示(影响整个界面)
        var globalError: String?
        var globalToast: Toast?

        // ❌ 不应包含单个 Feature 专属的 UI 状态
        // var isLoadingMore: Bool  // 这应该在 LogList.State.loadingState
    }
}
```

#### 3. 状态归属判断规则

**放在子 Feature State**:
- 单个 Feature 专属的业务数据
- 该 Feature 内部的加载/错误状态
- 该 Feature 内部的 UI 状态(如展开/折叠)

**放在顶层 State**:
- 多个 Feature 共享的 UI 状态(Sheet/Alert 显示状态)
- 影响全局的错误/提示
- Feature 之间的关联状态

**不应该出现**:
- 在多处重复的数据(违反单一数据源原则)
- 可以通过计算属性得出的派生状态

```swift
// ✅ 正确:使用计算属性
struct Filter.State {
    var selectedLevels: Set<LogLevel> = []
    var selectedFunctions: Set<String> = []

    var hasActiveFilters: Bool {  // 计算属性,不存储
        !selectedLevels.isEmpty || !selectedFunctions.isEmpty
    }
}

// ❌ 错误:存储派生状态
struct Filter.State {
    var selectedLevels: Set<LogLevel> = []
    var hasActiveFilters: Bool = false  // 冗余,容易不同步
}
```

---

### Effect 转换规则

Effect 转换统一在协调器层(顶层 Reducer)进行,保持子 Reducer 的独立性。

#### 规则 1: 子 Reducer 只返回子 Effect

```swift
// LogList.swift - 子 Reducer
struct LogList {
    struct Reducer {
        func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            case .loadLogFile:
                return .task {  // ✅ 返回 Effect<LogList.Action>
                    let events = await dataLoader.loadLogs(...)
                    return .logsLoadSucceeded(events)  // LogList.Action
                }
            }
        }
    }
}
```

#### 规则 2: 协调器负责 Effect 转换

```swift
// LogFeature.swift - 协调器
struct LogFeature {
    struct Reducer {
        func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            case .list(let listAction):
                // ✅ 调用子 Reducer 获取子 Effect
                let childEffect = listReducer.reduce(&state.list, listAction)

                // ✅ 使用 .map 转换为顶层 Effect
                return childEffect.map { .list($0) }

            // ❌ 错误:子 Reducer 直接返回顶层 Action
            // 这会让子 Reducer 依赖顶层,破坏模块独立性
            }
        }
    }
}
```

#### 规则 3: Effect.map 实现

```swift
// Effect.swift
enum Effect<Action> {
    case none
    case task(() async -> Action)
    case cancellable(id: AnyHashable, () async -> Action)
    case multiple([Effect<Action>])

    // ✅ map 方法:将 Effect<A> 转换为 Effect<B>
    func map<NewAction>(_ transform: @escaping (Action) -> NewAction) -> Effect<NewAction> {
        switch self {
        case .none:
            return .none

        case .task(let work):
            return .task {
                let action = await work()
                return transform(action)
            }

        case .cancellable(let id, let work):
            return .cancellable(id: id) {
                let action = await work()
                return transform(action)
            }

        case .multiple(let effects):
            return .multiple(effects.map { $0.map(transform) })
        }
    }
}
```

#### 规则 4: 组合多个 Effect

```swift
// 场景:应用筛选后,需要同时执行多个操作
case .filter(.applyFilters):
    let filterEffect = filterReducer.reduce(&state.filter, .applyFilters)
        .map { .filter($0) }

    // ✅ 使用 .multiple 组合多个 Effect
    return .multiple([
        filterEffect,                      // 1. 保存筛选偏好
        .task { .filterChanged },          // 2. 触发协调 Action
        .task { .list(.resetPagination) }  // 3. 重置分页
    ])
```

---

### 错误处理模式

统一的错误处理模式,避免混乱。

#### 模式 1: 在 Effect 中拆分 Result

```swift
// ✅ 推荐:在 Effect 中立即拆分
case .loadLogFile:
    return .task {
        do {
            let events = try await dataLoader.loadLogs(...)
            return .logsLoadSucceeded(events, sequence: state.querySequenceNumber)
        } catch {
            return .logsLoadFailed(error.localizedDescription)
        }
    }

// 在 Reducer 中处理成功/失败
case .logsLoadSucceeded(let events, let sequence):
    guard sequence == state.activeQuerySequence else { return .none }
    state.events = events
    state.loadingState = .loaded
    return .none

case .logsLoadFailed(let error):
    state.error = error
    state.loadingState = .failed
    return .none
```

#### 模式 2: 错误分类存储

```swift
struct LogList {
    struct State {
        // ✅ 根据错误类型分别存储
        var loadError: String?      // 加载错误
        var exportError: String?    // 导出错误
        var deleteError: String?    // 删除错误

        // ❌ 不推荐:通用错误字段
        // var error: String?  // 太模糊,不知道是什么错误
    }
}

// Action 也应该明确错误来源
enum Action {
    case logsLoadFailed(String)    // ✅ 明确是加载失败
    case exportFailed(String)      // ✅ 明确是导出失败
    case operationFailed(String)   // ❌ 太模糊
}
```

#### 模式 3: 全局错误 vs 局部错误

```swift
// 局部错误:不影响其他 Feature,存储在子 State
struct LogList.State {
    var loadError: String?  // 只影响列表加载
}

// 全局错误:影响整个界面,存储在顶层 State
struct LogFeature.State {
    var globalError: String?  // 需要显示全局弹窗的错误
}

// 在 Reducer 中根据严重程度分配
case .logsLoadFailed(let error):
    if isCriticalError(error) {
        state.globalError = error  // 严重错误显示全局弹窗
    } else {
        state.list.loadError = error  // 普通错误局部显示
    }
    return .none
```

---

### Equatable 实现策略

根据性能需求选择合适的 Equatable 实现方式。

#### 策略 1: 自动派生(默认)

```swift
// ✅ 简单 State,数据量小,使用自动派生
struct Filter.State: Equatable {
    var selectedLevels: Set<LogLevel> = []
    var selectedFunctions: Set<String> = []
    var startDate: Date?
    var endDate: Date?
}
// 编译器自动生成深度比较
```

#### 策略 2: 手动优化(大数组)

```swift
// ✅ 包含大数组的 State,手动实现优化比较
struct LogList.State: Equatable {
    var events: [LogEvent] = []  // 可能有数千条
    var totalCount: Int = 0
    var loadingState: LoadingState = .idle

    static func == (lhs: Self, rhs: Self) -> Bool {
        // 只比较关键字段,避免深度比较大数组
        lhs.events.count == rhs.events.count &&  // 只比较数量
        lhs.totalCount == rhs.totalCount &&
        lhs.loadingState == rhs.loadingState
    }
}
```

#### 策略 3: 使用 Identifiable

```swift
// ✅ 数组元素实现 Identifiable,SwiftUI 自动优化
struct LogEvent: Identifiable, Equatable {
    var id: String { objectID }  // 使用稳定的 ID
    var objectID: String
    var message: String
    // ...
}

// SwiftUI 只会重绘 id 变化的行
List(store.state.list.events) { event in
    LogRowView(event: event)
}
```

---

## 使用指南

### 快速开始

#### 1. 创建 Store

```swift
// 创建 Store(生产环境)
let store = LogFeatureStore.create(
    sessionIds: ["session-123", "session-456"],
    enableActionLogging: false  // 生产环境关闭日志
)

// 创建 Store(调试模式)
let store = LogFeatureStore.create(
    sessionIds: ["session-123"],
    enableActionLogging: true   // 开启 Action 日志,便于调试
)

// 创建 Store(测试环境)
let mockLoader = MockLogDataLoader()
mockLoader.mockEvents = [/* 测试数据 */]

let testEnvironment = LogFeatureEnvironment.mock(dataLoader: mockLoader)
let store = LogFeatureStore.createForTesting(environment: testEnvironment)
```

#### 2. 发送 Action

Feature-based 架构使用 **嵌套 Action**,通过 `.feature(subAction)` 格式发送:

```swift
// 列表操作
await store.send(.list(.loadLogFile))
await store.send(.list(.loadMore))
await store.send(.list(.refresh))

// 筛选操作
await store.send(.filter(.toggleLevel(.error)))
await store.send(.filter(.addFunction("viewDidLoad")))
await store.send(.filter(.applyFilters))  // 应用筛选

// 搜索操作
await store.send(.search(.updateSearchText("error message")))
await store.send(.search(.toggleSearchField(.message)))
await store.send(.search(.executeSearch))

// 导出操作
await store.send(.export(.selectFormat(.json)))
await store.send(.export(.startExport))

// 删除操作
await store.send(.delete(.loadSessions))
await store.send(.delete(.toggleSession("session-123")))
await store.send(.delete(.confirmDelete))

// UI 状态管理
await store.send(.setFilterPresented(true))   // 显示筛选面板
await store.send(.setSearchPresented(true))   // 显示搜索面板
```

#### 3. 监听状态变化

Feature-based 架构下,状态通过 **组合模式** 访问子 Feature State:

```swift
// 在 SwiftUI 中使用
struct MyView: View {
    @ObservedObject var store: LogFeatureStore

    var body: some View {
        List(store.state.list.events) { event in  // 访问 list.events
            Text(event.message)
        }
        .task {
            await store.send(.list(.loadLogFile))
        }
    }
}

// 在 Combine 中使用
// 监听列表总数
store.$state
    .map(\.list.totalCount)  // 访问 list.totalCount
    .removeDuplicates()
    .sink { count in
        print("Total logs: \(count)")
    }
    .store(in: &cancellables)

// 监听筛选状态
store.$state
    .map(\.filter.selectedLevels)  // 访问 filter.selectedLevels
    .removeDuplicates()
    .sink { levels in
        print("Selected levels: \(levels)")
    }
    .store(in: &cancellables)

// 监听导出进度
store.$state
    .map(\.export.progress)  // 访问 export.progress
    .removeDuplicates()
    .sink { progress in
        print("Export progress: \(progress * 100)%")
    }
    .store(in: &cancellables)
```

---

### SwiftUI 集成

#### 方式 1: 直接使用 Feature Store

```swift
import SwiftUI
import LoggerKit

struct ContentView: View {
    @StateObject private var store = LogFeatureStore.create(
        sessionIds: ["default"]
    )

    var body: some View {
        NavigationView {
            LogListView(store: store)
                .navigationTitle("Logs (\(store.state.list.totalCount))")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Refresh") {
                            Task { await store.send(.list(.refresh)) }
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Filter") {
                            Task { await store.send(.setFilterPresented(true)) }
                        }
                    }
                }
        }
        .task {
            await store.send(.list(.loadLogFile))
        }
        .sheet(isPresented: Binding(
            get: { store.state.isFilterPresented },
            set: { Task { await store.send(.setFilterPresented($0)) } }
        )) {
            FilterView(store: store)
        }
    }
}

struct LogListView: View {
    @ObservedObject var store: LogFeatureStore

    var body: some View {
        List {
            ForEach(store.state.list.events) { event in
                LogRowView(event: event)
            }

            // 加载更多
            if store.state.list.hasMore {
                ProgressView()
                    .onAppear {
                        Task { await store.send(.list(.loadMore)) }
                    }
            }
        }
        .overlay {
            if store.state.list.loadingState == .loading {
                ProgressView("Loading...")
            }
        }
    }
}

struct FilterView: View {
    @ObservedObject var store: LogFeatureStore

    var body: some View {
        NavigationView {
            Form {
                Section("日志级别") {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Toggle(level.rawValue, isOn: Binding(
                            get: { store.state.filter.selectedLevels.contains(level) },
                            set: { _ in
                                Task { await store.send(.filter(.toggleLevel(level))) }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("筛选")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        Task { await store.send(.filter(.applyFilters)) }
                    }
                }
            }
        }
    }
}
```

#### 方式 2: 使用 Facade 兼容层

```swift
import SwiftUI
import LoggerKit

struct ContentView: View {
    @StateObject private var sceneState = LogDetailSceneState()

    var body: some View {
        LogDetailScene(sceneState: sceneState)
    }
}
```

**Facade 模式优势**:
- ✅ 保持向后兼容,无需修改现有代码
- ✅ `@Published` 属性可直接在 SwiftUI 中使用
- ✅ 内部自动同步 Store 状态

---

### UIKit 集成

```swift
import UIKit
import LoggerKit

class LogViewController: UIViewController {
    private var store: LogSceneStore!
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        // 创建 Store
        store = LogSceneStore.create(sessionIds: ["default"])

        // 监听状态变化
        store.$state
            .map(\.events)
            .removeDuplicates()
            .sink { [weak self] events in
                self?.updateUI(events: events)
            }
            .store(in: &cancellables)

        // 加载数据
        Task {
            await store.send(.loadLogFile)
        }
    }

    @IBAction func refreshButtonTapped(_ sender: UIButton) {
        Task {
            await store.send(.refresh)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height

        if offsetY > contentHeight - frameHeight - 100 {
            Task {
                await store.send(.loadMore)
            }
        }
    }
}
```

**或使用便捷方法**:

```swift
import LoggerKit

// 快速创建 ViewController
let logVC = LogDetailScene.makeViewController()
navigationController?.pushViewController(logVC, animated: true)
```

---

## 性能优化

### 1. 虚拟化列表

使用 SwiftUI 的 `List` 实现真正的视图回收:

```swift
List {
    ForEach(store.state.events) { event in
        LogRowView(event: event)  // 只渲染可见行
    }
}
```

**优化点**:
- ✅ `LogRowViewModel` 预计算 session 颜色,避免每次渲染重复计算
- ✅ `LogEvent` 实现 `Identifiable`,使用稳定的 `objectID` 作为 ID
- ✅ 行高缓存(SwiftUI 自动优化)

---

### 2. 分页加载

```swift
struct PaginationReducer: Reducer {
    func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case .loadMore:
            // 防止重复加载
            guard state.loadingState == .loaded, state.hasMore else {
                return .none
            }

            state.loadingState = .loadingMore
            state.currentPage += 1

            let querySequence = state.querySequenceNumber

            return .cancellable(id: "loadMore") {
                let newEvents = await dataLoader.loadLogs(
                    page: state.currentPage,
                    pageSize: 500
                )
                return .logsLoaded(.success(newEvents), sequence: querySequence)
            }

        case .logsLoaded(let result, let sequence):
            // 序列号机制:忽略过期数据
            guard sequence == state.activeQuerySequence else {
                return .none
            }

            // 处理结果...
        }
    }
}
```

**性能优势**:
- ✅ 默认 500 条/页,避免一次加载全部数据
- ✅ 序列号机制避免过期数据覆盖新数据
- ✅ `.cancellable(id:)` 避免重复请求

---

### 3. 缓存策略

```swift
struct LogDetailState {
    // 缓存可用的函数列表(从 statistics 获取 top 100)
    var availableFunctions: [String] = []

    // 缓存可用的文件名
    var availableFileNames: [String] = []

    // 缓存搜索预览数据(最近 10000 条)
    var allEventsForSearchPreview: [LogEvent] = []
}

struct CacheReducer: Reducer {
    func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case .applyFilter, .updateSearchText:
            // 筛选/搜索变化时,自动失效相关缓存
            state.allEventsForSearchPreview = []
            return .none

        case .invalidateAllEventsCache:
            state.allEventsForSearchPreview = []
            return .none
        }
    }
}
```

**缓存粒度**:
- ✅ `availableFunctions`: 从 statistics 获取(top 100),避免全表扫描
- ✅ `availableFileNames`: 去重后的文件名列表
- ✅ `allEventsForSearchPreview`: 最近 10000 条事件,用于搜索预览

---

### 4. Effect 取消机制

```swift
struct FilterReducer: Reducer {
    func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case .toggleLevel(let level):
            state.selectedLevels.toggle(level)
            state.resetPagination()

            // 使用固定 ID,新请求自动取消旧请求
            return .cancellable(id: "loadLogs") {
                let events = await dataLoader.loadLogs(
                    filters: state.currentFilters,
                    page: 0,
                    pageSize: 500
                )
                return .logsLoaded(.success(events))
            }
        }
    }
}
```

**适用场景**:
- ✅ 筛选条件快速变化(用户连续点击多个级别)
- ✅ 搜索文本快速输入(避免每次输入都触发查询)
- ✅ 避免竞态条件(旧请求结果覆盖新请求)

---

### 5. 流式导出

```swift
func exportAllEventsStreaming(
    format: ExportFormat,
    progressCallback: @escaping (Double, Int, Int) -> Void
) async throws -> URL {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("logs_\(Date().timeIntervalSince1970).\(format.fileExtension)")

    let totalCount = try await databaseManager.fetchTotalCount(/* filters */)
    let batchSize = 1000
    var processedCount = 0

    for page in 0..<((totalCount + batchSize - 1) / batchSize) {
        // 批量读取
        let events = try await databaseManager.fetchEvents(
            page: page,
            pageSize: batchSize
        )

        // 流式写入
        try await LogParser.appendToFile(events, url: tempURL, format: format)

        processedCount += events.count

        // 进度回调
        let progress = Double(processedCount) / Double(totalCount)
        progressCallback(progress, processedCount, totalCount)
    }

    return tempURL
}
```

**优势**:
- ✅ 批量读取(1000 条/批),控制内存使用
- ✅ 流式写入,避免一次性构建完整 JSON
- ✅ 实时进度回调,更新 UI(圆环进度条)
- ✅ 支持超大数据集(100 万+ 日志)

---

### 6. Equatable 优化

```swift
struct LogDetailState: Equatable {
    // 手动实现 Equatable,避免深度比较
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.events.count == rhs.events.count &&
        lhs.totalCount == rhs.totalCount &&
        lhs.loadingState == rhs.loadingState &&
        lhs.exportState == rhs.exportState
        // ... 只比较关键字段
    }
}
```

**优势**:
- ✅ 减少不必要的 SwiftUI 重绘
- ✅ 避免深度比较大数组(`events`)
- ✅ 提升列表滚动性能

---

## 测试指南

### Reducer 单元测试

```swift
import Testing
@testable import LoggerKit

@Test func testToggleLevelFilter() async {
    // Given: 初始状态
    var state = LogDetailState()
    state.selectedLevels = [.info, .debug]

    let environment = LogDetailEnvironment.mock()
    let reducer = FilterReducer(environment: environment)

    // When: 切换 error 级别
    let effect = reducer.reduce(&state, .toggleLevel(.error))

    // Then: 状态已更新
    #expect(state.selectedLevels.contains(.error))

    // Then: 返回了加载 Effect
    guard case .cancellable(id: "loadLogs", _) = effect else {
        Issue.record("Expected cancellable effect with id 'loadLogs'")
        return
    }
}

@Test func testPaginationPreventsDoubleLoad() async {
    // Given: 正在加载的状态
    var state = LogDetailState()
    state.loadingState = .loadingMore
    state.hasMore = true

    let reducer = PaginationReducer(environment: .mock())

    // When: 再次调用 loadMore
    let effect = reducer.reduce(&state, .loadMore)

    // Then: 返回 .none,防止重复加载
    #expect(effect == .none)
}
```

---

### Store 集成测试

```swift
@Test func testLoadLogFileFlow() async {
    // Given: Mock 数据
    let mockLoader = MockLogDataLoader()
    mockLoader.mockEvents = [
        LogEvent(level: .info, message: "Test 1"),
        LogEvent(level: .error, message: "Test 2"),
    ]

    let environment = LogDetailEnvironment.mock(dataLoader: mockLoader)
    let store = LogSceneStore.createForTesting(environment: environment)

    // When: 加载日志
    await store.send(.loadLogFile)

    // 等待异步操作完成
    try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms

    // Then: 状态已更新
    #expect(store.state.events.count == 2)
    #expect(store.state.totalCount == 2)
    #expect(store.state.loadingState == .loaded)
}

@Test func testExportProgressTracking() async {
    // Given
    let mockDB = MockLogDatabaseManager()
    mockDB.mockTotalCount = 5000

    let environment = LogDetailEnvironment.mock(databaseManager: mockDB)
    let store = LogSceneStore.createForTesting(environment: environment)

    // When: 导出日志
    await store.send(.exportLogs(.json))

    // Then: 导出状态已更新
    #expect(store.state.exportState.isExporting == true)

    // 等待导出完成
    try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms

    // Then: 导出完成
    #expect(store.state.exportState.isExporting == false)
    #expect(store.state.exportedCount == 5000)
}
```

---

### Mock 使用方法

```swift
// 1. Mock LogDataLoader
class MockLogDataLoader: LogDataLoaderProtocol {
    var mockEvents: [LogEvent] = []
    var mockTotalCount: Int = 0

    func loadLogs(
        sessionIds: [String],
        filters: FilterOptions,
        page: Int,
        pageSize: Int
    ) async throws -> [LogEvent] {
        let start = page * pageSize
        let end = min(start + pageSize, mockEvents.count)
        return Array(mockEvents[start..<end])
    }
}

// 2. Mock LogDatabaseManager
class MockLogDatabaseManager: LogDatabaseManagerProtocol {
    var mockTotalCount: Int = 0

    func fetchTotalCount(/* ... */) async throws -> Int {
        return mockTotalCount
    }
}

// 3. 创建 Mock Environment
let mockEnv = LogDetailEnvironment.mock(
    dataLoader: MockLogDataLoader(),
    databaseManager: MockLogDatabaseManager()
)

// 4. 用于测试
let store = LogSceneStore.createForTesting(environment: mockEnv)
```

---

### 调试技巧

#### 1. 开启 Action 日志

```swift
let store = LogSceneStore.create(
    sessionIds: ["test"],
    enableActionLogging: true  // 开启日志
)

// 控制台输出:
// [LogDetailAction] loadLogFile
// [LogDetailAction] logsLoaded(.success(500 events))
// [LogDetailAction] toggleLevel(.error)
// [LogDetailAction] logsLoaded(.success(123 events))
```

#### 2. 查看 Action 历史

```swift
// Store 内部维护 Action 历史(最近 100 个)
print(store.actionHistory)
// Output:
// [
//     .loadLogFile,
//     .logsLoaded(.success(...)),
//     .applyFilter(...),
//     ...
// ]
```

#### 3. 断点调试 Reducer

```swift
func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
    print("Before: \(state)")  // 打印修改前状态

    let effect = handleAction(&state, action)

    print("After: \(state)")   // 打印修改后状态
    print("Effect: \(effect)") // 打印返回的 Effect

    return effect
}
```

---

## 迁移指南

### 完全向后兼容

尽管重构目标是"不考虑兼容性",但实际实现通过 **Facade 模式** 保持了完全向后兼容。

#### Facade 层架构

```swift
@MainActor
public class LogDetailSceneState: ObservableObject {
    // 内部委托给 Store
    private let store: LogSceneStore

    // 对外暴露 @Published 属性(兼容旧 API)
    @Published public private(set) var events: [LogEvent] = []
    @Published public private(set) var totalCount: Int = 0
    @Published public private(set) var loadingState: LoadingState = .idle

    // 导出进度(新增)
    @Published public private(set) var exportProgress: Double = 0
    @Published public private(set) var exportedCount: Int = 0
    @Published public private(set) var totalExportCount: Int = 0

    init() {
        self.store = LogSceneStore.create(/* ... */)

        // Combine 绑定:Store.state → @Published 属性
        store.$state.map(\.events).assign(to: &$events)
        store.$state.map(\.totalCount).assign(to: &$totalCount)
        store.$state.map(\.exportState.progress).assign(to: &$exportProgress)
        // ...
    }

    // 兼容旧方法
    public func loadLogFile() {
        Task { await store.send(.loadLogFile) }
    }

    public func loadMore() {
        Task { await store.send(.loadMore) }
    }
}
```

---

### 旧代码无需修改

```swift
// ✅ 旧代码继续工作
struct OldView: View {
    @StateObject var sceneState = LogDetailSceneState()

    var body: some View {
        List(sceneState.events) { event in  // 使用 @Published events
            Text(event.message)
        }
        .onAppear {
            sceneState.loadLogFile()  // 调用旧方法
        }
    }
}
```

---

### 新增功能

#### 1. 导出进度追踪

```swift
// 旧 API:无进度反馈
sceneState.exportAllEventsStreaming(format: .json) { url in
    // 导出完成
}

// 新 API:实时进度
store.send(.exportLogs(.json))

// 在 View 中监听进度
ProgressView(value: store.state.exportState.progress) {
    Text("Exporting \(store.state.exportedCount) / \(store.state.totalExportCount)")
}
```

#### 2. Sheet 状态管理

```swift
// 旧方式:View 内部管理 @State
@State private var showFilter = false

// 新方式:Store 统一管理
store.send(.setFilterPresented(true))

// 绑定到 SwiftUI
.sheet(isPresented: Binding(
    get: { store.state.isFilterPresented },
    set: { store.send(.setFilterPresented($0)) }
))
```

#### 3. 更精确的错误处理

```swift
// 旧方式:通用错误
@Published var errorMessage: String?

// 新方式:分类错误
enum LogDetailAction {
    case showLoadError(String)
    case showExportError(String)
    case showDeleteError(String)
}

// 状态中区分
struct LogDetailState {
    var loadError: String?
    var exportError: String?
    var deleteError: String?
}
```

---

### Breaking Changes

**无** - 所有旧 API 通过 Facade 模式保持兼容。

如果未来需要移除 Facade 层,建议的迁移路径:

```swift
// 步骤 1: 标记旧 API 为 deprecated
@available(*, deprecated, message: "Use LogSceneStore directly")
public class LogDetailSceneState { ... }

// 步骤 2: 提供迁移工具
extension LogDetailSceneState {
    public func migrateToStore() -> LogSceneStore {
        return self.store
    }
}

// 步骤 3: 逐步迁移代码
// 旧:
let sceneState = LogDetailSceneState()
// 新:
let store = LogSceneStore.create(sessionIds: ["default"])
```

---

## API 参考

### LogFeatureStore

```swift
// 类型别名(便于使用)
typealias LogFeatureStore = Store<LogFeature.State, LogFeature.Action>

extension LogFeatureStore {
    // 创建生产环境 Store
    static func create(
        sessionIds: [String],
        enableActionLogging: Bool = false
    ) -> LogFeatureStore {
        let environment = LogFeature.Environment.live
        let reducer = LogFeature.Reducer(environment: environment)
        let store = Store(
            initialState: LogFeature.State(),
            reducer: reducer,
            enableActionLogging: enableActionLogging
        )
        return store
    }

    // 创建测试环境 Store
    static func createForTesting(
        initialState: LogFeature.State = .init(),
        environment: LogFeature.Environment
    ) -> LogFeatureStore {
        let reducer = LogFeature.Reducer(environment: environment)
        return Store(initialState: initialState, reducer: reducer)
    }
}
```

---

### LogFeature.State

```swift
// LogFeature.swift
struct LogFeature {
    // 顶层 Feature State(组合模式)
    struct State: Equatable {
        // 子 Feature State
        var list: LogList.State = .init()
        var filter: Filter.State = .init()
        var search: Search.State = .init()
        var export: Export.State = .init()
        var delete: Delete.State = .init()

        // UI 状态(跨 Feature 共享)
        var isFilterPresented: Bool = false
        var isSearchPresented: Bool = false
        var isExportPresented: Bool = false
        var isDeletePresented: Bool = false

        // 全局错误
        var globalError: String?
    }
}

// 子 Feature State 定义
// LogList.swift
struct LogList {
    struct State: Equatable {
        var events: [LogEvent] = []
        var totalCount: Int = 0
        var loadingState: LoadingState = .idle
        var currentPage: Int = 0
        var hasMore: Bool = true
        var querySequenceNumber: Int = 0
        var activeQuerySequence: Int = 0

        mutating func resetPagination() {
            currentPage = 0
            hasMore = true
            querySequenceNumber += 1
        }
    }
}

// Filter.swift
struct Filter {
    struct State: Equatable {
        var selectedLevels: Set<LogLevel> = []
        var selectedFunctions: Set<String> = []
        var selectedFileNames: Set<String> = []
        var selectedContexts: Set<String> = []
        var selectedThreads: Set<String> = []
        var startDate: Date?
        var endDate: Date?

        var availableFunctions: [String] = []
        var availableFileNames: [String] = []

        var hasActiveFilters: Bool {
            !selectedLevels.isEmpty || !selectedFunctions.isEmpty ||
            !selectedFileNames.isEmpty || startDate != nil || endDate != nil
        }

        mutating func reset() {
            selectedLevels.removeAll()
            selectedFunctions.removeAll()
            selectedFileNames.removeAll()
            selectedContexts.removeAll()
            selectedThreads.removeAll()
            startDate = nil
            endDate = nil
        }
    }
}

// Search.swift
struct Search {
    struct State: Equatable {
        var searchText: String = ""
        var selectedSearchFields: Set<SearchField> = [.message]
        var searchResults: CategorizedSearchResults?
        var isSearching: Bool = false
        var allEventsForPreview: [LogEvent] = []
    }
}

// Export.swift
struct Export {
    struct State: Equatable {
        var format: ExportFormat = .json
        var isExporting: Bool = false
        var progress: Double = 0
        var exportedCount: Int = 0
        var totalCount: Int = 0
        var exportedURL: URL?
        var error: String?
    }
}

// Delete.swift
struct Delete {
    struct State: Equatable {
        var selectedSessionIds: Set<String> = []
        var availableSessions: [SessionInfo] = []
        var isDeleting: Bool = false
        var deleteProgress: Double = 0
        var error: String?
    }
}
```

---

### LogFeature.Action

```swift
// LogFeature.swift
struct LogFeature {
    // 顶层 Feature Action(嵌套路由)
    enum Action: Equatable {
        // 子 Feature Action(嵌套)
        case list(LogList.Action)
        case filter(Filter.Action)
        case search(Search.Action)
        case export(Export.Action)
        case delete(Delete.Action)

        // UI 状态管理(协调层)
        case setFilterPresented(Bool)
        case setSearchPresented(Bool)
        case setExportPresented(Bool)
        case setDeletePresented(Bool)

        // 跨 Feature 通信(协调层)
        case filterChanged          // Filter → List(重新加载)
        case searchCompleted        // Search → (关闭搜索面板)
        case exportCompleted(URL)   // Export → (显示分享)
        case deleteCompleted        // Delete → List(刷新)
    }
}

// 子 Feature Action 定义
// LogList.swift
struct LogList {
    enum Action: Equatable {
        case loadLogFile
        case loadMore
        case refresh
        case logsLoaded(Result<[LogEvent], Error>, sequence: Int)
        case totalCountLoaded(Int)
        case loadFailed(String)
        case resetPagination
    }
}

// Filter.swift
struct Filter {
    enum Action: Equatable {
        case toggleLevel(LogLevel)
        case addFunction(String)
        case removeFunction(String)
        case addFileName(String)
        case removeFileName(String)
        case setStartDate(Date?)
        case setEndDate(Date?)
        case resetFilters
        case applyFilters               // 触发 LogFeature.filterChanged
        case loadAvailableOptions
        case availableOptionsLoaded(functions: [String], fileNames: [String])
    }
}

// Search.swift
struct Search {
    enum Action: Equatable {
        case updateSearchText(String)
        case toggleSearchField(SearchField)
        case executeSearch
        case searchCompleted(CategorizedSearchResults)
        case searchFailed(String)
        case clearSearch
    }
}

// Export.swift
struct Export {
    enum Action: Equatable {
        case selectFormat(ExportFormat)
        case startExport
        case updateProgress(progress: Double, count: Int, total: Int)
        case exportCompleted(Result<URL, Error>)
        case cancelExport
    }
}

// Delete.swift
struct Delete {
    enum Action: Equatable {
        case loadSessions
        case sessionsLoaded([SessionInfo])
        case toggleSession(String)
        case selectAllSessions
        case deselectAllSessions
        case confirmDelete
        case updateProgress(Double)
        case deleteCompleted(Result<Void, Error>)
    }
}
```

---

### LogFeature.Environment

```swift
// LogFeature.swift
struct LogFeature {
    // Environment 定义在 Feature 内部
    struct Environment {
        let dataLoader: LogDataLoaderProtocol
        let databaseManager: LogDatabaseManagerProtocol

        // 生产环境
        static let live = Environment(
            dataLoader: LogDataLoader.shared,
            databaseManager: LogDatabaseManager.shared
        )

        // 测试环境
        static func mock(
            dataLoader: LogDataLoaderProtocol = MockLogDataLoader(),
            databaseManager: LogDatabaseManagerProtocol = MockLogDatabaseManager()
        ) -> Environment {
            Environment(
                dataLoader: dataLoader,
                databaseManager: databaseManager
            )
        }
    }
}
```

---

### FilterOptions

```swift
struct FilterOptions: Equatable {
    var levels: Set<LogLevel>
    var functions: Set<String>
    var fileNames: Set<String>
    var contexts: Set<String>
    var threads: Set<String>
    var startDate: Date?
    var endDate: Date?

    static let empty = FilterOptions(
        levels: [],
        functions: [],
        fileNames: [],
        contexts: [],
        threads: []
    )
}
```

---

### ExportFormat

```swift
enum ExportFormat: String, CaseIterable {
    case json
    case txt

    var fileExtension: String {
        rawValue
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .txt: return "text/plain"
        }
    }
}
```

---

## 总结

### 已实现的核心功能

1. ✅ **完整的 TCA 架构**(Effect/Reducer/Store,约 545 行)
2. ✅ **LogDetail 功能模块**(State/Action/Environment/Reducer,约 1274 行)
3. ✅ **4 个细粒度子 Reducer**(Filter/Pagination/Search/Cache,约 650 行)
4. ✅ **Facade 兼容层**(保持向后兼容,约 752 行)
5. ✅ **测试支持**(Mock 实现 + 工厂方法)
6. ✅ **性能优化**(虚拟化、分页、缓存、流式导出、序列号机制)

### 架构优势

- ✅ **单向数据流**: 可预测的状态管理
- ✅ **纯函数 Reducer**: 易于测试和推理
- ✅ **副作用隔离**: Effect 封装所有异步操作
- ✅ **可组合**: 小 Reducer 组合成大 Reducer
- ✅ **类型安全**: 编译时保证正确性
- ✅ **向后兼容**: Facade 模式无缝迁移

### 参考资料

- [TCA 官方文档](https://github.com/pointfreeco/swift-composable-architecture)
- [源码位置](../Sources/LoggerKit/UI/)
- [测试示例](../Tests/LoggerKitTests/)

---

## 实现细节

本章节补充核心组件的完整实现,帮助理解架构运作机制。

### Effect 完整实现

```swift
// Effect.swift
enum Effect<Action> {
    case none
    case task(() async -> Action)
    case cancellable(id: AnyHashable, () async -> Action)
    case multiple([Effect<Action>])
}

extension Effect {
    // map: 转换 Action 类型
    func map<NewAction>(_ transform: @escaping (Action) -> NewAction) -> Effect<NewAction> {
        switch self {
        case .none:
            return .none

        case .task(let work):
            return .task {
                let action = await work()
                return transform(action)
            }

        case .cancellable(let id, let work):
            return .cancellable(id: id) {
                let action = await work()
                return transform(action)
            }

        case .multiple(let effects):
            return .multiple(effects.map { $0.map(transform) })
        }
    }

    // merge: 并行执行多个 Effect
    static func merge(_ effects: [Effect<Action>]) -> Effect<Action> {
        .multiple(effects)
    }

    // concatenate: 串行执行多个 Effect
    static func concatenate(_ effects: [Effect<Action>]) -> Effect<Action> {
        guard !effects.isEmpty else { return .none }

        return .task {
            for effect in effects {
                // 依次执行每个 Effect(串行)
                switch effect {
                case .task(let work):
                    let _ = await work()
                case .cancellable(_, let work):
                    let _ = await work()
                default:
                    break
                }
            }
            // 返回最后一个 Effect 的结果
            // (实际实现中可能需要收集所有 Action)
            fatalError("Not implemented for demo")
        }
    }
}

// Equatable 支持(用于测试)
extension Effect: Equatable where Action: Equatable {
    static func == (lhs: Effect<Action>, rhs: Effect<Action>) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.multiple(let lhs), .multiple(let rhs)):
            return lhs == rhs
        default:
            return false  // task 和 cancellable 无法比较(包含闭包)
        }
    }
}
```

---

### Store 完整实现

```swift
// Store.swift
@MainActor
class Store<State, Action>: ObservableObject {
    @Published private(set) var state: State

    private let reducer: any Reducer<State, Action>
    private var runningTasks: [AnyHashable: Task<Void, Never>] = [:]
    private let enableActionLogging: Bool

    // Action 历史(调试用)
    private(set) var actionHistory: [String] = []
    private let maxHistorySize = 100

    init(
        initialState: State,
        reducer: any Reducer<State, Action>,
        enableActionLogging: Bool = false
    ) {
        self.state = initialState
        self.reducer = reducer
        self.enableActionLogging = enableActionLogging
    }

    // 派发 Action
    func send(_ action: Action) async {
        // 记录 Action 日志
        if enableActionLogging {
            print("[Action] \(action)")
        }

        // 记录历史
        recordAction(action)

        // 调用 Reducer 获取新状态和 Effect
        let effect = reducer.reduce(&state, action)

        // 执行 Effect
        await executeEffect(effect)
    }

    // 执行 Effect
    private func executeEffect(_ effect: Effect<Action>) async {
        switch effect {
        case .none:
            break

        case .task(let work):
            let task = Task {
                let action = await work()
                await self.send(action)  // 递归派发新 Action
            }
            await task.value

        case .cancellable(let id, let work):
            // 取消旧任务
            runningTasks[id]?.cancel()

            // 启动新任务
            let task = Task {
                let action = await work()
                await self.send(action)  // 递归派发新 Action
            }
            runningTasks[id] = task
            await task.value

            // 清理已完成的任务
            runningTasks[id] = nil

        case .multiple(let effects):
            // 并行执行所有 Effect
            await withTaskGroup(of: Void.self) { group in
                for effect in effects {
                    group.addTask {
                        await self.executeEffect(effect)
                    }
                }
            }
        }
    }

    // 记录 Action 历史
    private func recordAction(_ action: Action) {
        let description = String(describing: action)
        actionHistory.append(description)

        // 限制历史大小
        if actionHistory.count > maxHistorySize {
            actionHistory.removeFirst()
        }
    }

    // 取消所有运行中的任务
    func cancelAllTasks() {
        for task in runningTasks.values {
            task.cancel()
        }
        runningTasks.removeAll()
    }

    deinit {
        cancelAllTasks()
    }
}
```

---

### 序列号机制详解

序列号机制用于解决异步操作的竞态条件问题,确保只有最新的查询结果会被应用。

#### 问题场景

```
用户快速切换筛选条件:

时刻 T1: 选择 level = .error → 查询 A 开始(耗时 300ms)
时刻 T2: 选择 level = .warning → 查询 B 开始(耗时 100ms)

时刻 T3: 查询 B 完成 → state.events 更新为 warning 日志
时刻 T4: 查询 A 完成 → state.events 被覆盖为 error 日志 ❌

结果:UI 显示 error 日志,但用户选择的是 warning!
```

#### 解决方案

```swift
struct LogList.State {
    var events: [LogEvent] = []

    // 当前查询序列号(每次发起查询时递增)
    var querySequenceNumber: Int = 0

    // 活跃查询序列号(当前正在等待的查询)
    var activeQuerySequence: Int = 0

    mutating func resetPagination() {
        currentPage = 0
        hasMore = true
        querySequenceNumber += 1  // 递增序列号
    }
}

// Reducer 实现
struct LogListReducer {
    func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case .loadLogFile:
            // 发起新查询前递增序列号
            state.resetPagination()  // querySequenceNumber += 1
            state.loadingState = .loading

            let querySequence = state.querySequenceNumber
            state.activeQuerySequence = querySequence  // 记录活跃序列号

            return .cancellable(id: "loadLogs") {
                let events = await dataLoader.loadLogs(...)
                return .logsLoadSucceeded(events, sequence: querySequence)
            }

        case .logsLoadSucceeded(let events, let sequence):
            // 检查序列号:只接受最新的查询结果
            guard sequence == state.activeQuerySequence else {
                print("Ignoring stale query result: \(sequence)")
                return .none  // 忽略过期数据
            }

            state.events = events
            state.loadingState = .loaded
            return .none

        case .loadMore:
            // 加载更多不改变序列号(在当前查询基础上追加)
            state.currentPage += 1

            let querySequence = state.activeQuerySequence

            return .cancellable(id: "loadMore") {
                let newEvents = await dataLoader.loadLogs(
                    page: state.currentPage,
                    pageSize: 500
                )
                return .moreLogsLoadSucceeded(newEvents, sequence: querySequence)
            }
        }
    }
}
```

#### 完整流程示例

```
时刻 T1: 选择 level = .error
  └─> querySequenceNumber: 0 → 1
  └─> activeQuerySequence: 0 → 1
  └─> 查询 A 开始(sequence: 1)

时刻 T2: 选择 level = .warning
  └─> querySequenceNumber: 1 → 2
  └─> activeQuerySequence: 1 → 2
  └─> 查询 A 被取消(.cancellable 自动取消)
  └─> 查询 B 开始(sequence: 2)

时刻 T3: 查询 B 完成(sequence: 2)
  └─> sequence(2) == activeQuerySequence(2) ✅
  └─> state.events 更新为 warning 日志

时刻 T4: 查询 A 完成(sequence: 1,如果没被取消)
  └─> sequence(1) != activeQuerySequence(2) ❌
  └─> 忽略过期数据,state.events 保持不变
```

---

### Reducer 组合模式

完整的 Reducer 组合实现示例。

```swift
// Reducer 协议
protocol Reducer<State, Action> {
    associatedtype State
    associatedtype Action

    func reduce(_ state: inout State, _ action: Action) -> Effect<Action>
}

// 子 Reducer 示例
struct LogListReducer: Reducer {
    let environment: LogFeature.Environment

    func reduce(_ state: inout LogList.State, _ action: LogList.Action) -> Effect<LogList.Action> {
        switch action {
        case .loadLogFile:
            state.loadingState = .loading
            state.resetPagination()

            let querySequence = state.querySequenceNumber
            state.activeQuerySequence = querySequence

            return .cancellable(id: "loadLogs") {
                do {
                    let events = try await self.environment.dataLoader.loadLogs(
                        sessionIds: self.environment.sessionIds,
                        filters: self.environment.currentFilters,
                        page: 0,
                        pageSize: 500
                    )
                    return .logsLoadSucceeded(events, sequence: querySequence)
                } catch {
                    return .logsLoadFailed(error.localizedDescription)
                }
            }

        case .logsLoadSucceeded(let events, let sequence):
            guard sequence == state.activeQuerySequence else {
                return .none
            }

            state.events = events
            state.loadingState = .loaded
            return .none

        case .logsLoadFailed(let error):
            state.loadError = error
            state.loadingState = .failed
            return .none

        default:
            return .none
        }
    }
}

// 协调器 Reducer
struct LogFeatureReducer: Reducer {
    let environment: LogFeature.Environment

    // 子 Reducer 实例
    private lazy var listReducer = LogListReducer(environment: environment)
    private lazy var filterReducer = FilterReducer(environment: environment)
    private lazy var searchReducer = SearchReducer(environment: environment)

    func reduce(_ state: inout LogFeature.State, _ action: LogFeature.Action) -> Effect<LogFeature.Action> {
        switch action {
        // 路由到子 Reducer
        case .list(let listAction):
            let childEffect = listReducer.reduce(&state.list, listAction)
            return childEffect.map { .list($0) }

        case .filter(let filterAction):
            let childEffect = filterReducer.reduce(&state.filter, filterAction)

            // 特殊处理:筛选应用后触发列表刷新
            if case .applyFilters = filterAction {
                return .multiple([
                    childEffect.map { .filter($0) },
                    .task { .filterChanged }
                ])
            }

            return childEffect.map { .filter($0) }

        case .search(let searchAction):
            let childEffect = searchReducer.reduce(&state.search, searchAction)
            return childEffect.map { .search($0) }

        // 协调层:处理跨 Feature 通信
        case .filterChanged:
            state.list.resetPagination()
            state.isFilterPresented = false
            return .task { .list(.loadLogFile) }

        case .deleteCompleted:
            state.isDeletePresented = false
            return .task { .list(.refresh) }

        // UI 状态管理
        case .setFilterPresented(let isPresented):
            state.isFilterPresented = isPresented
            return .none

        case .setSearchPresented(let isPresented):
            state.isSearchPresented = isPresented
            return .none

        default:
            return .none
        }
    }
}
```

---

### Environment 设计模式

Environment 用于依赖注入,便于测试和模块化。

```swift
// LogFeature.swift
struct LogFeature {
    struct Environment {
        // 依赖项
        let dataLoader: LogDataLoaderProtocol
        let databaseManager: LogDatabaseManagerProtocol
        let sessionIds: [String]

        // 计算属性:动态获取当前筛选条件
        var currentFilters: FilterOptions {
            // 从某处获取当前筛选条件
            // (实际实现中可能通过闭包传递)
            FilterOptions.empty
        }

        // 生产环境
        static func live(sessionIds: [String]) -> Environment {
            Environment(
                dataLoader: LogDataLoader.shared,
                databaseManager: LogDatabaseManager.shared,
                sessionIds: sessionIds
            )
        }

        // 测试环境
        static func mock(
            dataLoader: LogDataLoaderProtocol = MockLogDataLoader(),
            databaseManager: LogDatabaseManagerProtocol = MockLogDatabaseManager(),
            sessionIds: [String] = ["test-session"]
        ) -> Environment {
            Environment(
                dataLoader: dataLoader,
                databaseManager: databaseManager,
                sessionIds: sessionIds
            )
        }
    }
}

// 使用示例
// 生产环境
let liveEnv = LogFeature.Environment.live(sessionIds: ["session-123"])
let store = LogFeatureStore(
    initialState: .init(),
    reducer: LogFeature.Reducer(environment: liveEnv)
)

// 测试环境
let mockLoader = MockLogDataLoader()
mockLoader.mockEvents = [/* 测试数据 */]

let testEnv = LogFeature.Environment.mock(
    dataLoader: mockLoader,
    sessionIds: ["test"]
)
let testStore = LogFeatureStore(
    initialState: .init(),
    reducer: LogFeature.Reducer(environment: testEnv)
)
```

---

### 类型安全的 Action 路由

使用 Swift 的类型系统保证 Action 路由的正确性。

```swift
// 问题:手动路由容易出错
case .list(let action):
    listReducer.reduce(&state.filter, action)  // ❌ 编译通过但逻辑错误!

// 解决:使用类型约束
protocol FeatureReducer {
    associatedtype FeatureState
    associatedtype FeatureAction

    func reduce(
        _ state: inout FeatureState,
        _ action: FeatureAction
    ) -> Effect<FeatureAction>
}

// 协调器使用泛型方法
extension LogFeatureReducer {
    func reduceChild<R: FeatureReducer>(
        reducer: R,
        state: inout R.FeatureState,
        action: R.FeatureAction,
        toParent: @escaping (R.FeatureAction) -> LogFeature.Action
    ) -> Effect<LogFeature.Action> {
        let childEffect = reducer.reduce(&state, action)
        return childEffect.map(toParent)
    }
}

// 使用
case .list(let listAction):
    return reduceChild(
        reducer: listReducer,
        state: &state.list,          // ✅ 类型必须匹配
        action: listAction,           // ✅ 类型必须匹配
        toParent: { .list($0) }
    )
```

---

## 总结

### 规范遵循检查清单

在开始编码前,请确保理解以下规范:

#### Action 命名
- [ ] 用户操作使用动词原形(load, toggle, apply)
- [ ] 系统反馈使用过去时 + 结果(logsLoadSucceeded, exportFailed)
- [ ] 跨 Feature 通信使用 Changed/Completed 后缀
- [ ] UI 状态管理使用 set/toggle 前缀
- [ ] Result 在 Effect 中拆分,不直接传递给 Reducer

#### State 组织
- [ ] 子 Feature State 只包含该 Feature 的业务数据和状态
- [ ] 顶层 State 包含子 State 组合和跨 Feature 共享状态
- [ ] 不存储可以通过计算属性得出的派生状态
- [ ] 不在多处重复存储相同数据

#### Effect 转换
- [ ] 子 Reducer 只返回子 Effect
- [ ] 协调器负责使用 .map 转换 Effect
- [ ] 子 Reducer 不依赖顶层 Action 类型
- [ ] 使用 .multiple 组合多个 Effect

#### 错误处理
- [ ] 在 Effect 中使用 do-catch 拆分成功/失败
- [ ] 根据错误类型分别存储(loadError, exportError)
- [ ] 区分全局错误和局部错误
- [ ] Action 命名明确错误来源

#### 性能优化
- [ ] 大数组 State 手动实现 Equatable
- [ ] 数组元素实现 Identifiable
- [ ] 使用序列号机制防止竞态条件
- [ ] 使用 .cancellable 避免重复请求

---

**最后更新**: 2025-12-18
