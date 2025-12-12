# Design: 阶段3架构重构

## Architecture Overview

### 重构前架构

```
┌─────────────────────────────────────────────────────────────┐
│               LogDetailSceneState (767行)                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ UI State (16个@Published)                            │  │
│  │ - displayEvents, isLoading, isLoadingMore, error... │  │
│  │ - searchText, searchFields                           │  │
│  │ - 7个过滤字段(各自didSet)                             │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 数据加载逻辑 (~150行)                                 │  │
│  │ - loadLogsFromDatabase()                             │  │
│  │ - loadStatistics()                                   │  │
│  │ - performBackgroundTask 调用                         │  │
│  │ - continuation 协调                                  │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Task管理 (散落各处)                                   │  │
│  │ - loadTask: Task<Void, Never>?                       │  │
│  │ - loadTask?.cancel()                                 │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 搜索逻辑 (~70行)                                      │  │
│  │ - searchResults 计算属性(5次遍历)                     │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 缓存管理 (已优化 - FilterOptionsCache)               │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
              ↓ 直接依赖
┌─────────────────────────────┐
│  LogDatabaseManager.shared  │
│  (单例,难以测试)             │
└─────────────────────────────┘
```

**问题总结**:
- ❌ 单个类 767 行,过于庞大
- ❌ 8 个职责混杂,违反单一职责原则
- ❌ 7 个过滤字段各自 didSet,代码重复
- ❌ 直接依赖单例,无法测试
- ❌ Task 管理散落,生命周期不清晰
- ❌ 搜索逻辑性能差(5次遍历)

---

### 重构后架构

```
┌──────────────────────────────────────────────────────────────┐
│        LogDetailSceneState (~250行)                          │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ UI 协调职责                                            │  │
│  │ - displayEvents: [LogEvent]                           │  │
│  │ - loadingState: LoadingState                          │  │
│  │ - statistics: LogStatistics?                          │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 分页状态管理                                           │  │
│  │ - currentPage, pageSize, hasMoreData                  │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 依赖组合(Composition)                                  │  │
│  │ - filterState: FilterState                            │  │
│  │ - dataLoader: LogDataLoaderProtocol                   │  │
│  │ - searchState: SearchState (可选)                     │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
              ↓ 依赖注入
┌───────────────────────────┐  ┌──────────────────────────────┐
│  FilterState (~150行)     │  │  DataLoader (~150行)         │
│  ┌─────────────────────┐  │  │  ┌────────────────────────┐  │
│  │ 7个过滤字段          │  │  │  │ loadEvents()           │  │
│  │ onFilterChanged()   │  │  │  │ loadStatistics()       │  │
│  │ 统一操作方法         │  │  │  │ cancelCurrentTask()    │  │
│  └─────────────────────┘  │  │  │ Task管理               │  │
└───────────────────────────┘  │  └────────────────────────┘  │
                               │          ↓ 协议依赖          │
┌───────────────────────────┐  │  ┌────────────────────────┐  │
│ SearchState (可选,~100行) │  │  │ LogDatabaseManager     │  │
│  ┌─────────────────────┐  │  │  │ (实现Protocol)         │  │
│  │ searchText          │  │  │  └────────────────────────┘  │
│  │ searchFields        │  │  └──────────────────────────────┘
│  │ computeResults()    │  │
│  │ (单次遍历优化)       │  │
│  └─────────────────────┘  │
└───────────────────────────┘
```

**优势总结**:
- ✅ 职责清晰分离,每个类专注一件事
- ✅ 代码行数控制(每个类 < 200行)
- ✅ 依赖注入,可测试性强
- ✅ 组合优于继承
- ✅ 性能优化(搜索单次遍历)

---

## Component Design

### 1. FilterState 设计

**职责**: 统一管理所有过滤条件

**接口设计**:
```swift
@MainActor
public class FilterState: ObservableObject {
    // MARK: - Published Properties
    @Published public var selectedLevels: Set<LogEvent.Level>
    @Published public var selectedFunctions: Set<String>
    @Published public var selectedFileNames: Set<String>
    @Published public var selectedContexts: Set<String>
    @Published public var selectedThreads: Set<String>
    @Published public var selectedMessageKeywords: Set<String>
    @Published public var selectedSessionId: String?

    // MARK: - Callbacks
    public var onFilterChanged: (() -> Void)?

    // MARK: - Computed Properties
    public var activeFilterCount: Int { get }

    // MARK: - Methods
    public func resetFilters()
    public func isInFilter(_ item: FilterItem) -> Bool
    public func addToFilter(_ item: FilterItem)
    public func removeFromFilter(_ item: FilterItem)
    public func toggleFilter(_ item: FilterItem)
    public func toggleLevel(_ level: LogEvent.Level)
}

public enum FilterItem {
    case function(String)
    case fileName(String)
    case context(String)
    case thread(String)
    case messageKeyword(String)
}
```

**设计决策**:

1. **使用 didSet 触发统一回调**
   - 每个 @Published 属性的 didSet 调用 `notifyChange()`
   - `notifyChange()` 触发 `onFilterChanged?()` 回调
   - 消除重复的 didSet 代码

2. **提供类型安全的操作方法**
   - 使用 FilterItem 枚举封装不同类型
   - switch 语句确保类型安全
   - 避免字符串拼接错误

3. **保持 @Published 特性**
   - SwiftUI 可直接绑定
   - 自动触发 UI 更新

**状态流**:
```
用户修改过滤条件
    ↓
@Published 属性变更
    ↓
didSet 触发
    ↓
notifyChange() 调用
    ↓
onFilterChanged?() 回调
    ↓
LogDetailSceneState.refresh() 执行
    ↓
重新加载日志
```

---

### 2. DataLoader 设计

**职责**: 统一数据加载和 Task 管理

**协议定义**:
```swift
public protocol LogDataLoaderProtocol: Sendable {
    func loadEvents(
        sessionId: String?,
        filterState: FilterState,
        searchText: String,
        offset: Int,
        limit: Int
    ) async throws -> [LogEvent]

    func loadStatistics(sessionId: String) async throws -> LogStatistics

    func cancelCurrentTask()
}
```

**实现类**:
```swift
public final class LogDataLoader: LogDataLoaderProtocol {
    private let databaseManager: LogDatabaseManagerProtocol
    private var currentTask: Task<Void, Never>?

    public init(databaseManager: LogDatabaseManagerProtocol)

    public func loadEvents(...) async throws -> [LogEvent] {
        // 使用 withCheckedThrowingContinuation
        // 调用 performBackgroundTask
        // 返回 [LogEvent]
    }

    public func loadStatistics(...) async throws -> LogStatistics {
        // 类似 loadEvents
    }

    public func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
    }
}
```

**加载状态枚举**:
```swift
public enum LoadingState: Equatable {
    case idle
    case loading(progress: String?)
    case loadingMore
    case loaded
    case failed(Error)

    public static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
        // 实现 Equatable
    }
}
```

**设计决策**:

1. **使用协议抽象**
   - 支持依赖注入
   - 支持 Mock 测试
   - 隔离实现细节

2. **封装 CoreData 线程安全**
   - performBackgroundTask 创建独立 context
   - withCheckedThrowingContinuation 协调异步
   - 避免 @Published 属性在闭包中访问

3. **统一 Task 管理**
   - currentTask 追踪当前任务
   - cancelCurrentTask() 提供取消接口
   - 避免并发冲突

4. **LoadingState 替代多个布尔值**
   - 单一状态源
   - 类型安全
   - 易于扩展(如添加进度信息)

**线程模型**:
```
Main Thread                    Background Thread
    │                                │
loadLogs() 调用                      │
    │                                │
    ├──→ dataLoader.loadEvents()     │
    │                                │
    │      withCheckedThrowingContinuation
    │                                │
    │      performBackgroundTask ────┤
    │                                │
    │                          查询数据库
    │                                │
    │      ←──── continuation.resume │
    │                                │
更新 displayEvents                   │
```

---

### 3. SearchState 设计(可选)

**职责**: 独立搜索逻辑 + 性能优化

**接口设计**:
```swift
@MainActor
public class SearchState: ObservableObject {
    @Published public var searchText: String
    @Published public var searchFields: Set<SearchField>

    public var onSearchChanged: (() -> Void)?

    public func computeResults(from events: [LogEvent]) -> CategorizedSearchResults

    public func toggleSearchField(_ field: SearchField)
}
```

**性能优化设计**:

**优化前(5次遍历)**:
```swift
var searchResults: CategorizedSearchResults {
    var results = CategorizedSearchResults()

    // 遍历1: message
    for event in events {
        if event.message.contains(searchText) {
            results.message.insert(event.message)
        }
    }

    // 遍历2: function
    for event in events {
        if event.function.contains(searchText) {
            results.function.insert(event.function)
        }
    }

    // ... 总共5次遍历
    return results
}
```

**优化后(单次遍历)**:
```swift
public func computeResults(from events: [LogEvent]) -> CategorizedSearchResults {
    var results = CategorizedSearchResults()

    var messageCounts: [String: Int] = [:]
    var functionCounts: [String: Int] = [:]
    var fileNameCounts: [String: Int] = [:]
    var contextCounts: [String: Int] = [:]
    var threadCounts: [String: Int] = [:]

    // 单次遍历
    for event in events {
        if searchFields.contains(.message) && event.message.contains(searchText) {
            messageCounts[event.message, default: 0] += 1
        }

        if searchFields.contains(.function) && event.function.contains(searchText) {
            functionCounts[event.function, default: 0] += 1
        }

        // ... 其他字段
    }

    // 构建结果(带计数)
    results.message = messageCounts.map {
        SearchResultItem(field: .message, value: $0.key, matchCount: $0.value)
    }
    // ...

    return results
}
```

**性能对比**:
```
数据集: 10000 条日志
搜索字段: 5 个(message, function, fileName, context, thread)

优化前:
  遍历次数: 5 次
  总迭代: 10000 × 5 = 50000 次
  预计时间: ~200-300ms

优化后:
  遍历次数: 1 次
  总迭代: 10000 次
  预计时间: ~50-100ms

性能提升: 50-70%
```

---

### 4. 依赖注入设计

**协议层次**:
```
┌─────────────────────────────────────┐
│  LogDatabaseManagerProtocol         │
│  - fetchEvents(...)                 │
│  - fetchStatistics(...)             │
└─────────────────────────────────────┘
              ↑ 遵循
┌─────────────────────────────────────┐
│  LogDatabaseManager                 │
│  (现有实现)                          │
└─────────────────────────────────────┘
              ↑ 注入
┌─────────────────────────────────────┐
│  LogDataLoader                      │
│  (实现 LogDataLoaderProtocol)       │
└─────────────────────────────────────┘
              ↑ 注入
┌─────────────────────────────────────┐
│  LogDetailSceneState                │
│  (UI 协调)                          │
└─────────────────────────────────────┘
```

**初始化设计**:
```swift
@MainActor
public class LogDetailSceneState: ObservableObject {
    private let dataLoader: LogDataLoaderProtocol
    public let filterState: FilterState
    public let searchState: SearchState

    // 完整 DI 初始化(用于测试)
    public init(
        prefix: String,
        identifier: String,
        dataLoader: LogDataLoaderProtocol,
        filterState: FilterState,
        searchState: SearchState
    ) {
        self.prefix = prefix
        self.identifier = identifier
        self.dataLoader = dataLoader
        self.filterState = filterState
        self.searchState = searchState

        setupBindings()
    }

    // 便利初始化(生产环境)
    public convenience init(prefix: String, identifier: String) {
        let dbManager = LogDatabaseManager.shared
        let dataLoader = LogDataLoader(databaseManager: dbManager)
        let filterState = FilterState()
        let searchState = SearchState()

        self.init(
            prefix: prefix,
            identifier: identifier,
            dataLoader: dataLoader,
            filterState: filterState,
            searchState: searchState
        )
    }
}
```

**依赖注入优势**:
1. **可测试性**: 可注入 Mock 实现
2. **灵活性**: 可替换不同实现
3. **解耦**: 依赖抽象而非具体类
4. **向后兼容**: 便利初始化保持现有用法

---

## Migration Strategy

### 渐进式重构步骤

**步骤1: FilterState 提取** (独立功能)
```
Before:
LogDetailSceneState {
    @Published var selectedLevels
    @Published var selectedFunctions { didSet { ... } }
    ...
}

After:
FilterState {
    @Published var selectedLevels { didSet { notifyChange() } }
    @Published var selectedFunctions { didSet { notifyChange() } }
    ...
}

LogDetailSceneState {
    public let filterState: FilterState
}
```

**兼容性**: ✅ 通过 `state.filterState.selectedLevels` 访问

---

**步骤2: DataLoader 提取** (依赖步骤1)
```
Before:
LogDetailSceneState {
    func loadLogsFromDatabase() { /* 100+ 行 */ }
    private var loadTask: Task<Void, Never>?
}

After:
LogDataLoader {
    func loadEvents(...) async throws -> [LogEvent]
}

LogDetailSceneState {
    private let dataLoader: LogDataLoaderProtocol
    func loadLogs() async { /* 简化调用 */ }
}
```

**兼容性**: ✅ 内部实现变化,外部 API 不变

---

**步骤3: 依赖注入改造** (依赖步骤1+2)
```
Before:
LogDetailSceneState {
    init(prefix: String, identifier: String) {
        // 直接使用 LogDatabaseManager.shared
    }
}

After:
LogDetailSceneState {
    // 完整 DI
    init(dataLoader: LogDataLoaderProtocol, filterState: FilterState) { ... }

    // 便利初始化
    convenience init(prefix: String, identifier: String) { ... }
}
```

**兼容性**: ✅ 便利初始化保持现有用法

---

**步骤4: SearchState 提取** (可选,独立)
```
Before:
LogDetailSceneState {
    var searchResults: CategorizedSearchResults {
        /* 5次遍历 */
    }
}

After:
SearchState {
    func computeResults(from events: [LogEvent]) -> CategorizedSearchResults {
        /* 单次遍历 */
    }
}

LogDetailSceneState {
    public let searchState: SearchState
    var searchResults: CategorizedSearchResults {
        searchState.computeResults(from: displayEvents)
    }
}
```

**兼容性**: ✅ API 不变,内部优化

---

## Risk Mitigation

### 风险1: 状态同步问题

**风险**: FilterState 和 LogDetailSceneState 状态不一致

**缓解措施**:
- 使用 onFilterChanged 回调保证同步
- 每步重构后立即验证功能
- Example 项目测试各种过滤组合

**验证方法**:
```swift
// 测试场景
1. 快速切换多个过滤条件
2. 验证 displayEvents 正确更新
3. 验证 UI 状态同步
```

---

### 风险2: Task 生命周期管理

**风险**: Task 未正确取消导致并发冲突

**缓解措施**:
- DataLoader 统一管理 currentTask
- 每次新任务前取消旧任务
- 使用 weak self 避免循环引用

**验证方法**:
```swift
// 测试场景
1. 快速切换过滤条件(触发多次加载)
2. 检查 Task 是否正确取消
3. 验证无数据竞争(Thread Sanitizer)
```

---

### 风险3: 线程安全问题

**风险**: performBackgroundTask 和 @MainActor 冲突

**缓解措施**:
- 使用 withCheckedThrowingContinuation 协调
- 闭包前捕获值,避免访问 @Published 属性
- 明确线程边界

**验证方法**:
```swift
// 测试场景
1. 并发加载测试
2. Thread Sanitizer 检测
3. 压力测试(快速操作)
```

---

### 风险4: 性能回退

**风险**: 重构导致性能下降

**缓解措施**:
- 每步验证性能基准
- SearchState 实现单次遍历优化
- 避免不必要的对象创建

**验证方法**:
```
基准测试:
- 初始加载时间
- 搜索响应时间
- 滚动帧率
- 内存占用

对比标准:
≤ 重构前(不能回退)
```

---

## Testing Strategy

### 功能验证

**每步重构后验证**:
```
✓ swift build 成功
✓ 无编译警告
✓ Example 项目运行
✓ 所有功能正常
  - 7个过滤维度
  - 搜索功能
  - 分页加载
  - 统计信息
✓ 无性能回退
```

### 性能基准

**测试场景**:
```swift
1. 初始加载 10000 条日志
   - 测量加载时间
   - 测量内存占用

2. 搜索 10000 条日志
   - 测量响应时间
   - 验证结果正确性

3. 快速切换过滤条件
   - 验证 Task 取消
   - 验证无卡顿

4. 滚动大列表
   - 测量帧率
   - 验证流畅度
```

### 回归测试

**验证清单**:
- [ ] 所有过滤组合正常
- [ ] 搜索全部字段正常
- [ ] 分页加载稳定
- [ ] 统计信息准确
- [ ] UI 交互流畅
- [ ] 无崩溃,无警告

---

## Success Criteria

### 代码质量

✅ LogDetailSceneState < 300 行
✅ 职责数量 ≤ 2
✅ @Published 属性 ≤ 6
✅ didSet 重复代码 = 0
✅ 编译无警告

### 性能指标

✅ 初始加载时间 ≤ 重构前
✅ 搜索响应时间 < 重构前(50%+改善)
✅ 滚动帧率 ≥ 60fps
✅ 内存占用 ≤ 重构前

### 架构质量

✅ 依赖注入完整
✅ 职责清晰分离
✅ 可测试性提升
✅ 组件解耦

### 功能完整性

✅ 无功能回归
✅ 所有功能正常
✅ 无新增 bug
✅ Example 项目运行正常
