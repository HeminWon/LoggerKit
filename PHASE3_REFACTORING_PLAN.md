# 阶段3架构重构计划 - 核心优化

## 📋 总览

**目标**: 重构 LogDetailSceneState (767行) 为职责清晰的架构
**方式**: 渐进式重构，分步实施
**工作量**: ~10-12小时（核心优化）
**风险**: 中

**决策背景**:
- ✅ 时间有限，优先长期价值
- ✅ 完整职责拆分 + 依赖注入改造
- ⚠️ Timer泄漏问题暂缓，后续修复
- ⚠️ 跳过单元测试框架搭建，直接重构

---

## 🎯 核心重构步骤

### 第1步: 提取 FilterState (2-3小时)

**目标**: 消除7个过滤字段的 didSet 重复代码

#### 实现方案

**新建文件**: `Sources/LoggerKit/UI/FilterState.swift`

```swift
import Foundation
import Combine

/// 管理所有过滤条件的状态对象
@MainActor
public class FilterState: ObservableObject {
    // MARK: - Published Properties

    @Published public var selectedLevels: Set<LogEvent.Level> {
        didSet { notifyChange() }
    }

    @Published public var selectedFunctions: Set<String> = [] {
        didSet { notifyChange() }
    }

    @Published public var selectedFileNames: Set<String> = [] {
        didSet { notifyChange() }
    }

    @Published public var selectedContexts: Set<String> = [] {
        didSet { notifyChange() }
    }

    @Published public var selectedThreads: Set<String> = [] {
        didSet { notifyChange() }
    }

    @Published public var selectedMessageKeywords: Set<String> = [] {
        didSet { notifyChange() }
    }

    @Published public var selectedSessionId: String? {
        didSet { notifyChange() }
    }

    // MARK: - Callbacks

    /// 任何过滤条件变更时的回调
    public var onFilterChanged: (() -> Void)?

    // MARK: - Initialization

    public init(
        levels: Set<LogEvent.Level> = [.verbose, .debug, .info, .warning, .error]
    ) {
        self.selectedLevels = levels
    }

    // MARK: - Public Methods

    /// 计算当前激活的过滤器数量
    public var activeFilterCount: Int {
        var count = 0
        if selectedFunctions.count > 0 { count += 1 }
        if selectedFileNames.count > 0 { count += 1 }
        if selectedContexts.count > 0 { count += 1 }
        if selectedThreads.count > 0 { count += 1 }
        if selectedMessageKeywords.count > 0 { count += 1 }
        return count
    }

    /// 重置所有过滤器（级别除外）
    public func resetFilters() {
        selectedFunctions.removeAll()
        selectedFileNames.removeAll()
        selectedContexts.removeAll()
        selectedThreads.removeAll()
        selectedMessageKeywords.removeAll()
    }

    /// 检查项是否在过滤器中
    public func isInFilter(_ item: FilterItem) -> Bool {
        switch item {
        case .function(let name):
            return selectedFunctions.contains(name)
        case .fileName(let name):
            return selectedFileNames.contains(name)
        case .context(let name):
            return selectedContexts.contains(name)
        case .thread(let name):
            return selectedThreads.contains(name)
        case .messageKeyword(let keyword):
            return selectedMessageKeywords.contains(keyword)
        }
    }

    /// 添加到过滤器
    public func addToFilter(_ item: FilterItem) {
        switch item {
        case .function(let name):
            selectedFunctions.insert(name)
        case .fileName(let name):
            selectedFileNames.insert(name)
        case .context(let name):
            selectedContexts.insert(name)
        case .thread(let name):
            selectedThreads.insert(name)
        case .messageKeyword(let keyword):
            selectedMessageKeywords.insert(keyword)
        }
    }

    /// 从过滤器移除
    public func removeFromFilter(_ item: FilterItem) {
        switch item {
        case .function(let name):
            selectedFunctions.remove(name)
        case .fileName(let name):
            selectedFileNames.remove(name)
        case .context(let name):
            selectedContexts.remove(name)
        case .thread(let name):
            selectedThreads.remove(name)
        case .messageKeyword(let keyword):
            selectedMessageKeywords.remove(keyword)
        }
    }

    /// 切换过滤器状态
    public func toggleFilter(_ item: FilterItem) {
        if isInFilter(item) {
            removeFromFilter(item)
        } else {
            addToFilter(item)
        }
    }

    /// 切换日志级别
    public func toggleLevel(_ level: LogEvent.Level) {
        if selectedLevels.contains(level) {
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
    }

    // MARK: - Private Methods

    private func notifyChange() {
        onFilterChanged?()
    }
}

// MARK: - Supporting Types

public enum FilterItem {
    case function(String)
    case fileName(String)
    case context(String)
    case thread(String)
    case messageKeyword(String)
}
```

#### 修改 LogDetailSceneState

```swift
@MainActor
public class LogDetailSceneState: ObservableObject {
    // MARK: - Filter State (新增)
    public let filterState: FilterState

    // MARK: - 移除这7个 @Published 属性
    // ❌ @Published var selectedLevels
    // ❌ @Published var selectedFunctions
    // ❌ @Published var selectedFileNames
    // ❌ @Published var selectedContexts
    // ❌ @Published var selectedThreads
    // ❌ @Published var selectedMessageKeywords
    // ❌ @Published var selectedSessionId

    // MARK: - Initialization
    public init(
        prefix: String,
        identifier: String,
        filterState: FilterState? = nil
    ) {
        self.prefix = prefix
        self.identifier = identifier
        self.filterState = filterState ?? FilterState()

        setupFilterStateBinding()
    }

    // MARK: - Setup
    private func setupFilterStateBinding() {
        filterState.onFilterChanged = { [weak self] in
            self?.loadTask?.cancel()
            Task { @MainActor [weak self] in
                await self?.reloadWithFilters()
            }
        }
    }

    // MARK: - 更新所有引用过滤字段的地方
    public func loadLogsFromDatabase(resetPagination: Bool = false) async {
        // 使用 filterState.selectedLevels 替代 selectedLevels
        let results = try await databaseManager?.fetchEvents(
            in: filterState.selectedSessionId,
            levels: filterState.selectedLevels,
            functions: filterState.selectedFunctions,
            fileNames: filterState.selectedFileNames,
            contexts: filterState.selectedContexts,
            threads: filterState.selectedThreads,
            searchText: searchText,
            messageKeywords: filterState.selectedMessageKeywords,
            offset: offset,
            limit: pageSize
        )
        // ...
    }
}
```

#### 更新 UI 层引用

需要更新以下文件中的所有引用：
- `LogDetailScene.swift`
- `LogFilterSheet.swift`

```swift
// 将所有 state.selectedLevels 改为 state.filterState.selectedLevels
// 将所有 state.selectedFunctions 改为 state.filterState.selectedFunctions
// ... 其他字段同理
```

**预期收益**:
- ✅ 代码减少 ~100行
- ✅ 消除7个 didSet 重复
- ✅ 职责更清晰

---

### 第2步: 提取 DataLoaderService (3-4小时)

**目标**: 统一数据加载和 Task 管理

#### 创建协议

**新建**: `Sources/LoggerKit/UI/DataLoader/LogDataLoaderProtocol.swift`

```swift
import Foundation

/// 数据加载协议
public protocol LogDataLoaderProtocol: Sendable {
    /// 加载日志事件
    func loadEvents(
        sessionId: String?,
        filterState: FilterState,
        searchText: String,
        offset: Int,
        limit: Int
    ) async throws -> [LogEvent]

    /// 加载统计信息
    func loadStatistics(sessionId: String) async throws -> LogStatistics

    /// 取消当前加载任务
    func cancelCurrentTask()
}
```

#### 实现类

**新建**: `Sources/LoggerKit/UI/DataLoader/LogDataLoader.swift`

```swift
import Foundation

/// 数据加载服务
public final class LogDataLoader: LogDataLoaderProtocol {
    private let databaseManager: LogDatabaseManager
    private var currentTask: Task<Void, Never>?

    public init(databaseManager: LogDatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    public func loadEvents(
        sessionId: String?,
        filterState: FilterState,
        searchText: String,
        offset: Int,
        limit: Int
    ) async throws -> [LogEvent] {
        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    let events = try self.databaseManager.fetchEvents(
                        in: sessionId,
                        levels: filterState.selectedLevels,
                        functions: filterState.selectedFunctions,
                        fileNames: filterState.selectedFileNames,
                        contexts: filterState.selectedContexts,
                        threads: filterState.selectedThreads,
                        searchText: searchText,
                        messageKeywords: filterState.selectedMessageKeywords,
                        offset: offset,
                        limit: limit,
                        context: context
                    )
                    continuation.resume(returning: events)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func loadStatistics(sessionId: String) async throws -> LogStatistics {
        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    let stats = try self.databaseManager.fetchStatistics(
                        in: sessionId,
                        context: context
                    )
                    continuation.resume(returning: stats)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
    }
}
```

#### 加载状态枚举

**新建**: `Sources/LoggerKit/UI/DataLoader/LoadingState.swift`

```swift
import Foundation

/// 数据加载状态
public enum LoadingState: Equatable {
    case idle
    case loading(progress: String?)
    case loadingMore
    case loaded
    case failed(Error)

    public static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loading, .loading),
             (.loadingMore, .loadingMore),
             (.loaded, .loaded):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}
```

#### 重构 LogDetailSceneState

```swift
@MainActor
public class LogDetailSceneState: ObservableObject {
    // MARK: - Properties
    private let dataLoader: LogDataLoaderProtocol
    public let filterState: FilterState

    @Published public var displayEvents: [LogEvent] = []
    @Published public var loadingState: LoadingState = .idle
    @Published public var statistics: LogStatistics?

    private var currentPage = 0
    private let pageSize = 500
    private var hasMoreData = true

    // MARK: - 移除这些方法和属性
    // ❌ private var loadTask: Task<Void, Never>?
    // ❌ func loadLogsFromDatabase(...) - 复杂的数据库加载逻辑
    // ❌ func loadStatistics() - 统计加载逻辑

    // MARK: - Initialization
    public init(
        prefix: String,
        identifier: String,
        dataLoader: LogDataLoaderProtocol? = nil,
        filterState: FilterState? = nil
    ) {
        self.prefix = prefix
        self.identifier = identifier
        self.dataLoader = dataLoader ?? LogDataLoader()
        self.filterState = filterState ?? FilterState()

        setupBindings()
    }

    // MARK: - 简化的加载方法
    public func loadLogs(resetPagination: Bool = false) async {
        if resetPagination {
            currentPage = 0
            hasMoreData = true
            displayEvents.removeAll()
        }

        guard hasMoreData else { return }
        loadingState = resetPagination ? .loading(progress: "加载中...") : .loadingMore

        do {
            let newEvents = try await dataLoader.loadEvents(
                sessionId: filterState.selectedSessionId,
                filterState: filterState,
                searchText: searchText,
                offset: currentPage * pageSize,
                limit: pageSize
            )

            displayEvents.append(contentsOf: newEvents)
            hasMoreData = newEvents.count == pageSize
            currentPage += 1
            loadingState = .loaded
        } catch {
            loadingState = .failed(error)
        }
    }

    public func loadMore() async {
        guard loadingState != .loadingMore else { return }
        await loadLogs(resetPagination: false)
    }

    public func refresh() async {
        dataLoader.cancelCurrentTask()
        await loadLogs(resetPagination: true)
        await loadStatisticsInternal()
    }

    private func loadStatisticsInternal() async {
        guard let sessionId = filterState.selectedSessionId else { return }
        do {
            statistics = try await dataLoader.loadStatistics(sessionId: sessionId)
        } catch {
            print("Failed to load statistics: \(error)")
        }
    }

    private func setupBindings() {
        filterState.onFilterChanged = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }
}
```

**预期收益**:
- ✅ 代码再减少 ~100行
- ✅ Task 管理统一
- ✅ 数据加载逻辑独立

---

### 第3步: 依赖注入改造 (2-3小时)

**目标**: 协议抽象，提升灵活性

#### 数据库协议抽象

**新建**: `Sources/LoggerKit/Database/LogDatabaseManagerProtocol.swift`

```swift
import Foundation
import CoreData

/// 数据库管理器协议
public protocol LogDatabaseManagerProtocol: Sendable {
    func fetchEvents(
        in sessionId: String?,
        levels: Set<LogEvent.Level>,
        functions: Set<String>,
        fileNames: Set<String>,
        contexts: Set<String>,
        threads: Set<String>,
        searchText: String,
        messageKeywords: Set<String>,
        offset: Int,
        limit: Int,
        context: NSManagedObjectContext
    ) throws -> [LogEvent]

    func fetchStatistics(
        in sessionId: String,
        context: NSManagedObjectContext
    ) throws -> LogStatistics
}

// 扩展现有类遵循协议
extension LogDatabaseManager: LogDatabaseManagerProtocol {}
```

#### 更新 DataLoader 使用协议

```swift
public final class LogDataLoader: LogDataLoaderProtocol {
    private let databaseManager: LogDatabaseManagerProtocol  // 改用协议

    public init(databaseManager: LogDatabaseManagerProtocol) {  // 强制注入
        self.databaseManager = databaseManager
    }
}
```

#### 完整的依赖注入

```swift
@MainActor
public class LogDetailSceneState: ObservableObject {
    private let dataLoader: LogDataLoaderProtocol
    public let filterState: FilterState

    /// 完整 DI 初始化
    public init(
        prefix: String,
        identifier: String,
        dataLoader: LogDataLoaderProtocol,
        filterState: FilterState
    ) {
        self.prefix = prefix
        self.identifier = identifier
        self.dataLoader = dataLoader
        self.filterState = filterState
        setupBindings()
    }

    /// 便利初始化（生产环境）
    public convenience init(prefix: String, identifier: String) {
        let dbManager = LogDatabaseManager.shared
        let dataLoader = LogDataLoader(databaseManager: dbManager)
        let filterState = FilterState()

        self.init(
            prefix: prefix,
            identifier: identifier,
            dataLoader: dataLoader,
            filterState: filterState
        )
    }
}
```

**预期收益**:
- ✅ 支持依赖替换
- ✅ 可测试性提升
- ✅ 组件解耦

---

### 第4步: 提取 SearchState (可选, 2-3小时)

**目标**: 独立搜索逻辑 + 单次遍历优化（解决阶段2.2性能问题）

**新建**: `Sources/LoggerKit/UI/SearchState.swift`

```swift
import Foundation
import Combine

/// 搜索状态管理
@MainActor
public class SearchState: ObservableObject {
    @Published public var searchText: String = "" {
        didSet { onSearchChanged?() }
    }

    @Published public var searchFields: Set<SearchField> = [
        .message, .function, .fileName, .context, .thread
    ] {
        didSet { onSearchChanged?() }
    }

    public var onSearchChanged: (() -> Void)?

    /// 🚀 单次遍历计算搜索结果（性能优化）
    public func computeResults(from events: [LogEvent]) -> CategorizedSearchResults {
        guard !searchText.isEmpty else {
            return CategorizedSearchResults()
        }

        var results = CategorizedSearchResults()
        let lowercased = searchText.lowercased()

        // 使用字典统计匹配计数
        var messageCounts: [String: Int] = [:]
        var functionCounts: [String: Int] = [:]
        var fileNameCounts: [String: Int] = [:]
        var contextCounts: [String: Int] = [:]
        var threadCounts: [String: Int] = [:]

        // 🚀 单次遍历（优化前是5次遍历）
        for event in events {
            if searchFields.contains(.message) && event.message.lowercased().contains(lowercased) {
                messageCounts[event.message, default: 0] += 1
            }

            if searchFields.contains(.function) && event.function.lowercased().contains(lowercased) {
                functionCounts[event.function, default: 0] += 1
            }

            if searchFields.contains(.fileName) && event.fileName.lowercased().contains(lowercased) {
                fileNameCounts[event.fileName, default: 0] += 1
            }

            if searchFields.contains(.context) && event.context.lowercased().contains(lowercased) {
                contextCounts[event.context, default: 0] += 1
            }

            if searchFields.contains(.thread) && event.thread.lowercased().contains(lowercased) {
                threadCounts[event.thread, default: 0] += 1
            }
        }

        // 构建结果
        results.message = messageCounts.map {
            SearchResultItem(field: .message, value: $0.key, matchCount: $0.value)
        }
        results.function = functionCounts.map {
            SearchResultItem(field: .function, value: $0.key, matchCount: $0.value)
        }
        results.fileName = fileNameCounts.map {
            SearchResultItem(field: .fileName, value: $0.key, matchCount: $0.value)
        }
        results.context = contextCounts.map {
            SearchResultItem(field: .context, value: $0.key, matchCount: $0.value)
        }
        results.thread = threadCounts.map {
            SearchResultItem(field: .thread, value: $0.key, matchCount: $0.value)
        }

        return results
    }

    /// 切换搜索范围
    public func toggleSearchField(_ field: SearchField) {
        if searchFields.contains(field) {
            searchFields.remove(field)
        } else {
            searchFields.insert(field)
        }
    }
}
```

#### 集成到 LogDetailSceneState

```swift
@MainActor
public class LogDetailSceneState: ObservableObject {
    public let searchState: SearchState

    // ❌ 移除 @Published var searchText
    // ❌ 移除 @Published var searchFields
    // ❌ 移除 var searchResults 复杂的计算属性

    public init(
        prefix: String,
        identifier: String,
        dataLoader: LogDataLoaderProtocol,
        filterState: FilterState,
        searchState: SearchState? = nil
    ) {
        // ...
        self.searchState = searchState ?? SearchState()
        setupBindings()
    }

    private func setupBindings() {
        searchState.onSearchChanged = { [weak self] in
            // 搜索变更处理
        }
    }

    // 简化为调用 searchState
    public var searchResults: CategorizedSearchResults {
        searchState.computeResults(from: displayEvents)
    }
}
```

**预期收益**:
- ✅ 搜索逻辑独立
- ✅ 搜索响应时间减少 50-70%（单次遍历）
- ✅ 顺便解决了阶段2.2的性能问题

---

## 📊 重构前后对比

### 代码结构变化

**重构前**:
```
LogDetailSceneState (767行)
├─ 16个 @Published 属性
├─ 7个过滤字段（各自 didSet）
├─ 复杂的数据加载逻辑
├─ Task 管理散落各处
├─ 搜索结果重复遍历
└─ 8个职责混杂
```

**重构后**:
```
LogDetailSceneState (~250行)
├─ 6个 @Published 属性
├─ 清晰的依赖注入
└─ 仅负责 UI 协调

FilterState (新建)
└─ 7个过滤字段统一管理

DataLoader (新建)
└─ 数据加载 + Task 管理

SearchState (可选)
└─ 搜索逻辑 + 性能优化
```

### 指标对比

| 指标 | 重构前 | 重构后 | 改善 |
|------|--------|--------|------|
| LogDetailSceneState 行数 | 767 | ~250 | -67% |
| 职责数量 | 8个 | 2个 | -75% |
| Published 属性 | 16个 | 6个 | -63% |
| didSet 重复代码 | 7处 | 0处 | -100% |
| 搜索遍历次数 | 5次 | 1次 | -80% |

---

## ⚠️ 风险控制

### 关键风险点

1. **状态依赖耦合**
   - 风险: FilterState 和 LogDetailSceneState 的状态同步
   - 应对: 使用 onFilterChanged 回调解耦
   - 验证: 在 Example 项目中测试过滤功能

2. **Task 生命周期**
   - 风险: DataLoader 的 Task 取消和创建
   - 应对: DataLoader 统一管理
   - 验证: 测试快速切换过滤条件

3. **线程安全**
   - 风险: performBackgroundTask 和 @MainActor
   - 应对: 使用 continuation 协调
   - 验证: 测试并发场景

### 渐进式验证

每完成一步，必须验证：
- [ ] 编译通过无警告
- [ ] 在 Example 项目运行
- [ ] 日志列表正常显示
- [ ] 过滤功能正常工作
- [ ] 搜索功能正常工作
- [ ] 分页加载正确
- [ ] 无性能回退

---

## 📅 时间规划

| 步骤 | 任务 | 预计时间 |
|------|------|----------|
| 第1步 | FilterState 提取 | 2-3h |
| 第2步 | DataLoader 提取 | 3-4h |
| 第3步 | 依赖注入改造 | 2-3h |
| 第4步 | SearchState 提取（可选） | 2-3h |
| **总计** | **核心优化** | **7-10h** |
| **总计** | **含可选** | **9-13h** |

---

## ✅ 完成标准

- [ ] LogDetailSceneState < 300 行
- [ ] 编译无警告
- [ ] Example 项目功能完整
- [ ] 无性能回退
- [ ] 职责清晰分离
- [ ] 依赖注入完整

---

## 🚫 不包含内容

本次重构**不包含**：

❌ 单元测试框架搭建
❌ 详细的测试用例编写
❌ Mock 类实现
❌ Timer 泄漏修复
❌ 错误处理统一化
❌ fileName 优化
❌ Magic Numbers 提取

---

## 📝 执行建议

1. **渐进式实施**: 每完成一步就提交
2. **及时验证**: 每步都在 Example 项目验证
3. **保持备份**: 遇到问题可以回滚
4. **专注核心**: 不被细节干扰，先完成重构

---

**更新时间**: 2025-12-12
**版本**: 2.0（精简版）
