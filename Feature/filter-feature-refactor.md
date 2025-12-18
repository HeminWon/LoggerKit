# FilterFeature TCA 重构方案

## 目录

1. [重构目标](#重构目标)
2. [架构设计](#架构设计)
3. [前置准备](#前置准备)
4. [改造步骤](#改造步骤)
5. [代码实现细节](#代码实现细节)
6. [已知问题与解决方案](#已知问题与解决方案)

---

## 重构目标

### 当前问题

筛选功能当前实现存在以下问题:

1. **状态分散**: 筛选状态(`selectedLevels`, `selectedFunctions`, `selectedFileNames` 等)分散在 `LogDetailState` 和筛选逻辑中
2. **逻辑耦合**: 筛选逻辑在 `LogDetailReducer` 的核心 Action 中处理,与其他业务逻辑混合
3. **职责不清**: 筛选功能直接操作 `LogDetailState`,没有独立的领域边界
4. **难以复用**: 筛选逻辑与 LogDetailFeature 强耦合,无法在其他场景复用(如搜索结果筛选、Session 筛选)

### 改造目标

1. ✅ **独立性**: 将筛选功能提取为独立的 `FilterFeature`,实现完整的 TCA 架构
2. ✅ **可复用**: FilterFeature 可以在其他场景复用(如搜索结果筛选、Session 列表筛选、日志流筛选)
3. ✅ **向后兼容**: 通过 Facade 模式保持现有 API 不变
4. ✅ **清晰边界**: 筛选状态和逻辑完全封装在 FilterFeature 中

---

## 架构设计

### Feature 结构

```
Sources/LoggerKit/UI/
├── SubFeatures/
│   ├── SearchReducer.swift        # 现有搜索 Reducer
│   ├── PaginationReducer.swift    # 现有分页 Reducer
│   ├── CacheReducer.swift         # 现有缓存 Reducer
│   └── ExportReducer.swift        # 现有导出 Reducer
│
└── Filter/                         # ✅ 新增:完整 FilterFeature (独立可复用)
    ├── FilterFeature.swift         # State + Action + Reducer + Environment
    └── FilterTypes.swift           # FilterError, FilterStatistics 等辅助类型
```

**设计原则**:
- **独立性**: FilterFeature 拥有自己的 State、Action、Reducer、Environment
- **可复用性**: 可在多个场景使用 (日志列表筛选、搜索结果筛选、Session 筛选)
- **解耦**: 与 LogDetailFeature 解耦，通过 Environment 注入依赖

### State 设计

```swift
// Filter/FilterFeature.swift
struct FilterFeature {
    /// Filter State
    struct State: Equatable, Sendable {
        // MARK: - Selected Filters

        /// Selected log levels
        var selectedLevels: Set<LogEvent.Level> = []

        /// Selected functions
        var selectedFunctions: Set<String> = []

        /// Selected file names
        var selectedFileNames: Set<String> = []

        /// Selected contexts
        var selectedContexts: Set<String> = []

        /// Selected threads
        var selectedThreads: Set<String> = []

        /// Selected message keywords
        var selectedMessageKeywords: Set<String> = []

        // MARK: - Available Options (用于 UI 展示)

        /// Available functions (从 statistics 获取)
        var availableFunctions: [String] = []

        /// Available file names (从 statistics 获取)
        var availableFileNames: [String] = []

        /// Available contexts
        var availableContexts: [String] = []

        /// Available threads
        var availableThreads: [String] = []

        /// Loading state for available options
        var isLoadingOptions: Bool = false

        /// Error message (if loading options fails)
        var error: Error?

        // MARK: - Computed Properties

        /// Whether any filter is active
        var hasActiveFilters: Bool {
            !selectedLevels.isEmpty || !selectedFunctions.isEmpty ||
            !selectedFileNames.isEmpty || !selectedContexts.isEmpty ||
            !selectedThreads.isEmpty || !selectedMessageKeywords.isEmpty
        }

        /// Count of active filters
        var activeFilterCount: Int {
            var count = 0
            if !selectedLevels.isEmpty { count += 1 }
            if !selectedFunctions.isEmpty { count += 1 }
            if !selectedFileNames.isEmpty { count += 1 }
            if !selectedContexts.isEmpty { count += 1 }
            if !selectedThreads.isEmpty { count += 1 }
            if !selectedMessageKeywords.isEmpty { count += 1 }
            return count
        }

        // MARK: - State Mutations

        /// Reset all filters to initial state
        mutating func reset() {
            selectedLevels.removeAll()
            selectedFunctions.removeAll()
            selectedFileNames.removeAll()
            selectedContexts.removeAll()
            selectedThreads.removeAll()
            selectedMessageKeywords.removeAll()
        }
    }
}
```

### Action 设计

```swift
// Filter/FilterFeature.swift
extension FilterFeature {
    /// Filter Actions
    enum Action: Equatable {
        // MARK: - User Actions (命令型)

        /// Toggle log level filter
        case toggleLevel(LogEvent.Level)

        /// Add function filter
        case addFunction(String)

        /// Remove function filter
        case removeFunction(String)

        /// Add file name filter
        case addFileName(String)

        /// Remove file name filter
        case removeFileName(String)

        /// Add context filter
        case addContext(String)

        /// Remove context filter
        case removeContext(String)

        /// Add thread filter
        case addThread(String)

        /// Remove thread filter
        case removeThread(String)

        /// Add message keyword filter
        case addMessageKeyword(String)

        /// Remove message keyword filter
        case removeMessageKeyword(String)

        /// Reset all filters
        case resetFilters

        /// Apply current filters (user initiates filter application)
        case applyFilters

        /// Load available options (functions, file names, etc.)
        case loadAvailableOptions

        // MARK: - System Feedback (事件型)

        /// Filters have been applied successfully (notifies parent to reload)
        case filtersApplied

        /// Available options loaded successfully
        case availableOptionsLoaded(
            functions: [String],
            fileNames: [String],
            contexts: [String],
            threads: [String]
        )

        /// Loading available options failed
        case loadingOptionsFailed(Error)

        // MARK: - Equatable

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.toggleLevel(let l), .toggleLevel(let r)):
                return l == r
            case (.addFunction(let l), .addFunction(let r)),
                 (.removeFunction(let l), .removeFunction(let r)):
                return l == r
            case (.addFileName(let l), .addFileName(let r)),
                 (.removeFileName(let l), .removeFileName(let r)):
                return l == r
            case (.addContext(let l), .addContext(let r)),
                 (.removeContext(let l), .removeContext(let r)):
                return l == r
            case (.addThread(let l), .addThread(let r)),
                 (.removeThread(let l), .removeThread(let r)):
                return l == r
            case (.addMessageKeyword(let l), .addMessageKeyword(let r)),
                 (.removeMessageKeyword(let l), .removeMessageKeyword(let r)):
                return l == r
            case (.resetFilters, .resetFilters),
                 (.applyFilters, .applyFilters),
                 (.filtersApplied, .filtersApplied),
                 (.loadAvailableOptions, .loadAvailableOptions):
                return true
            case (.availableOptionsLoaded(let lf, let ln, let lc, let lt),
                  .availableOptionsLoaded(let rf, let rn, let rc, let rt)):
                return lf == rf && ln == rn && lc == rc && lt == rt
            case (.loadingOptionsFailed(let l), .loadingOptionsFailed(let r)):
                return l.localizedDescription == r.localizedDescription
            default:
                return false
            }
        }
    }
}
```

### Reducer 设计

```swift
// Filter/FilterFeature.swift
extension FilterFeature {
    /// Filter Reducer
    struct Reducer: LoggerKit.Reducer {
        typealias State = FilterFeature.State
        typealias Action = FilterFeature.Action

        private let environment: Environment

        init(environment: Environment) {
            self.environment = environment
        }

        func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            // MARK: - Toggle Filters

            case .toggleLevel(let level):
                if state.selectedLevels.contains(level) {
                    state.selectedLevels.remove(level)
                } else {
                    state.selectedLevels.insert(level)
                }
                return .none

            case .addFunction(let function):
                state.selectedFunctions.insert(function)
                return .none

            case .removeFunction(let function):
                state.selectedFunctions.remove(function)
                return .none

            case .addFileName(let fileName):
                state.selectedFileNames.insert(fileName)
                return .none

            case .removeFileName(let fileName):
                state.selectedFileNames.remove(fileName)
                return .none

            case .addContext(let context):
                state.selectedContexts.insert(context)
                return .none

            case .removeContext(let context):
                state.selectedContexts.remove(context)
                return .none

            case .addThread(let thread):
                state.selectedThreads.insert(thread)
                return .none

            case .removeThread(let thread):
                state.selectedThreads.remove(thread)
                return .none

            case .addMessageKeyword(let keyword):
                state.selectedMessageKeywords.insert(keyword)
                return .none

            case .removeMessageKeyword(let keyword):
                state.selectedMessageKeywords.remove(keyword)
                return .none

            case .resetFilters:
                state.reset()
                return .none

            case .applyFilters:
                // 通知父 Reducer 筛选已应用
                return .send(.filtersApplied)

            case .filtersApplied:
                // 由父 Reducer 处理 (触发列表重新加载)
                return .none

            // MARK: - Load Available Options

            case .loadAvailableOptions:
                return handleLoadAvailableOptions(&state)

            case .availableOptionsLoaded(let functions, let fileNames, let contexts, let threads):
                state.isLoadingOptions = false
                state.availableFunctions = functions
                state.availableFileNames = fileNames
                state.availableContexts = contexts
                state.availableThreads = threads
                state.error = nil
                return .none

            case .loadingOptionsFailed(let error):
                state.isLoadingOptions = false
                state.error = error
                return .none
            }
        }

        // MARK: - Private Handlers

        private func handleLoadAvailableOptions(_ state: inout State) -> Effect<Action> {
            state.isLoadingOptions = true
            state.error = nil

            return .task { [environment] in
                do {
                    // 从 dataLoader 获取统计信息
                    print("🔵 [FilterFeature] Loading available options...")

                    let functions = try await environment.dataLoader.getAvailableFunctions()
                    let fileNames = try await environment.dataLoader.getAvailableFileNames()
                    let contexts = try await environment.dataLoader.getAvailableContexts()
                    let threads = try await environment.dataLoader.getAvailableThreads()

                    print("🟢 [FilterFeature] Options loaded: \(functions.count) functions, \(fileNames.count) files")

                    return .availableOptionsLoaded(
                        functions: functions,
                        fileNames: fileNames,
                        contexts: contexts,
                        threads: threads
                    )
                } catch {
                    print("🔴 [FilterFeature] Failed to load options: \(error.localizedDescription)")
                    return .loadingOptionsFailed(error)
                }
            }
        }
    }
}
```

### Environment 设计

```swift
// Filter/FilterFeature.swift
extension FilterFeature {
    /// Filter Environment (依赖注入)
    struct Environment {
        /// Data loader for fetching available filter options
        let dataLoader: LogDataLoaderProtocol

        // MARK: - Live Environment

        static func live() -> Environment {
            Environment(
                dataLoader: LogDataLoader.shared
            )
        }

        // MARK: - Mock Environment (for testing)

        static func mock(
            dataLoader: LogDataLoaderProtocol = MockLogDataLoader()
        ) -> Environment {
            Environment(
                dataLoader: dataLoader
            )
        }
    }
}
```

### Supporting Types

```swift
// Filter/FilterTypes.swift

import Foundation

// MARK: - Filter Error

/// Filter-related errors
public enum FilterError: Error, LocalizedError, Equatable {
    case loadingOptionsFailed
    case emptyFilterResult

    public var errorDescription: String? {
        switch self {
        case .loadingOptionsFailed:
            return "加载筛选选项失败"
        case .emptyFilterResult:
            return "筛选结果为空"
        }
    }
}

// MARK: - Filter Statistics

/// Filter statistics (用于 UI 展示)
public struct FilterStatistics: Equatable, Sendable {
    /// Total number of logs before filtering
    public let totalCount: Int

    /// Number of logs after filtering
    public let filteredCount: Int

    /// Filter efficiency (0.0 to 1.0)
    public var efficiency: Double {
        guard totalCount > 0 else { return 0 }
        return Double(filteredCount) / Double(totalCount)
    }

    public init(totalCount: Int, filteredCount: Int) {
        self.totalCount = totalCount
        self.filteredCount = filteredCount
    }
}
```

---

## 前置准备

### 检查依赖接口完整性

在开始第一阶段前，必须确保 `LogDataLoaderProtocol` 包含所需方法：

```swift
// DataLoader/LogDataLoaderProtocol.swift
protocol LogDataLoaderProtocol {
    // ... 现有方法

    /// 获取所有可用的函数名
    func getAvailableFunctions() async throws -> [String]

    /// 获取所有可用的文件名
    func getAvailableFileNames() async throws -> [String]

    /// 获取所有可用的上下文
    func getAvailableContexts() async throws -> [String]

    /// 获取所有可用的线程名
    func getAvailableThreads() async throws -> [String]
}
```

**验证步骤**:
1. 检查 `LogDataLoaderProtocol` 是否已包含上述方法
2. 如果没有，先在 `LogDataLoader` 中实现这些方法
3. 从数据库统计信息中提取数据 (可复用现有 statistics 查询)

**时间估计**: 1 小时

---

## 改造步骤

### 第一阶段: 创建完整 FilterFeature

**目标**: 创建独立的 FilterFeature，包含完整的 State、Action、Reducer、Environment

**步骤**:

1. ✅ 创建目录 `Sources/LoggerKit/UI/Filter/`
2. ✅ 创建 `FilterTypes.swift` - 定义 FilterError、FilterStatistics
3. ✅ 创建 `FilterFeature.swift` - 定义完整的 Feature
   - `FilterFeature.State` - 独立的筛选状态
   - `FilterFeature.Action` - 筛选相关的 Action
   - `FilterFeature.Reducer` - 筛选逻辑的 Reducer
   - `FilterFeature.Environment` - 依赖注入
4. ✅ 确保编译通过

**验证**:
```bash
# 1. 编译通过
swift build

# 2. 单元测试 FilterFeature (可选)
swift test --filter FilterFeatureTests
```

**注意事项**:
- 确保 `filtersApplied` Action 已添加
- 暂不实现 `selectedSessionIds` (待明确使用场景)
- 移除 `toFilterState()` 向后兼容方法 (如果完全迁移)

**时间估计**: 2-3 小时

---

### 第二阶段: 集成 FilterFeature 到 LogDetailFeature

**目标**: 在 LogDetailFeature 中集成 FilterFeature，替换原有筛选逻辑

**步骤**:

1. ✅ 在 `LogDetailState` 中添加 `FilterFeature.State`
   ```swift
   // LogDetail/LogDetailState.swift
   public final class LogDetailState: ObservableObject, Equatable, Sendable {
       // ... 现有属性

       // 筛选功能 (使用 FilterFeature)
       public var filterFeature: FilterFeature.State = .init()

       // ❌ 移除旧的筛选相关属性 (如果有)
   }
   ```

2. ✅ 在 `LogDetailAction` 中添加 FilterFeature Action
   ```swift
   // LogDetail/LogDetailAction.swift
   public enum LogDetailAction: Equatable {
       // ... 现有 Actions

       // 筛选功能 (委托给 FilterFeature)
       case filter(FilterFeature.Action)

       // ❌ 移除旧的筛选 Actions
   }
   ```

3. ✅ 在 `LogDetailReducer` 中集成 `FilterFeature.Reducer`
   ```swift
   // LogDetail/LogDetailReducer.swift
   public struct LogDetailReducer: Reducer {
       private let environment: LogDetailEnvironment
       private let filterReducer: FilterFeature.Reducer  // ✅ 新增

       public init(environment: LogDetailEnvironment) {
           self.environment = environment

           // 初始化 FilterReducer
           let filterEnv = FilterFeature.Environment.live()
           self.filterReducer = FilterFeature.Reducer(environment: filterEnv)
       }

       public func reduce(_ state: inout LogDetailState, _ action: LogDetailAction) -> Effect<LogDetailAction> {
           switch action {
           case .filter(let filterAction):
               // 委托给 FilterFeature.Reducer
               let filterEffect = filterReducer.reduce(&state.filterFeature, filterAction)
               return filterEffect.map { .filter($0) }

           case .filter(.filtersApplied):
               // 筛选应用完成,触发列表刷新
               state.isFilterPresented = false
               state.list.resetPagination()
               return .task { .list(.loadLogFile) }

           // ... 其他 Actions
           default:
               return handleOtherActions(&state, action)
           }
       }
   }
   ```

4. ✅ 更新 `LogDetailSceneState` 使用新的 FilterFeature
   ```swift
   // UI/LogDetailSceneState.swift
   // 更新绑定使用 filterFeature
   store.$state
       .map { $0.filterFeature.hasActiveFilters }
       .assign(to: &$hasActiveFilters)

   store.$state
       .map { $0.filterFeature.activeFilterCount }
       .assign(to: &$activeFilterCount)
   ```

**验证**:
```bash
# 1. 编译通过
swift build

# 2. 在模拟器中测试筛选功能:
#    - 切换日志级别筛选
#    - 添加/移除函数筛选
#    - 验证筛选结果正确
#    - 确认 filtersApplied 触发列表刷新
```

**关键验证点**:
- ✅ `store.send(.filter(.applyFilters))` 触发列表刷新
- ✅ 筛选面板自动关闭 (`isFilterPresented = false`)
- ✅ 分页重置 (`list.resetPagination()`)
- ✅ 新数据加载正确

**时间估计**: 2-3 小时

---

### 第三阶段: 扩展功能 (可选 - 未来)

**目标**: 利用 FilterFeature 的独立性，在多个场景复用

**可能的扩展**:

1. ⚠️ **在搜索结果中复用 FilterFeature**
   - 在 SearchState 中添加 `filterFeature: FilterFeature.State`
   - 支持对搜索结果进行二次筛选
   ```swift
   // SearchView
   Button("筛选搜索结果") {
       store.send(.filter(.applyFilters))
   }
   ```

2. ⚠️ **在 Session 列表中复用 FilterFeature**
   - 在 SessionListState 中添加 `filterFeature: FilterFeature.State`
   - 支持按日期、事件数等筛选 Session
   ```swift
   // SessionListView
   Button("筛选 Session") {
       store.send(.setFilterPresented(true))
   }
   ```

3. ⚠️ **实现筛选偏好持久化**
   - 在 Environment 中注入 `preferencesManager`
   - 支持保存/加载用户常用的筛选器
   ```swift
   extension FilterFeature.Environment {
       let preferencesManager: PreferencesManagerProtocol

       func savePreferences(_ state: State) async throws {
           try await preferencesManager.save(state)
       }
   }
   ```

4. ⚠️ **实现高级筛选功能**
   - 支持正则表达式筛选
   - 支持组合筛选器 (AND/OR/NOT)
   - 支持筛选器模板
   ```swift
   extension FilterFeature.Action {
       case setRegexPattern(String)
       case setCombineMode(CombineMode)  // .and, .or, .not
       case saveAsTemplate(String)
   }
   ```

**时间估计**: 根据需求,每个功能 2-4 小时

---

## 代码实现细节

### 完整文件结构

```
Sources/LoggerKit/UI/
├── TCA/
│   ├── Effect.swift                     # TCA Effect 类型
│   ├── Store.swift                      # TCA Store 实现
│   └── Reducer.swift                    # TCA Reducer 协议
│
├── Filter/                              # ✅ 新增:完整 FilterFeature
│   ├── FilterFeature.swift              # State + Action + Reducer + Environment
│   └── FilterTypes.swift                # FilterError + FilterStatistics
│
├── LogDetail/
│   ├── LogDetailState.swift             # ✅ 更新:使用 filterFeature: FilterFeature.State
│   ├── LogDetailAction.swift            # ✅ 更新:添加 case filter(FilterFeature.Action)
│   ├── LogDetailReducer.swift           # ✅ 更新:集成 FilterFeature.Reducer
│   └── LogDetailEnvironment.swift
│
├── LogDetailSceneState.swift            # ✅ 更新:使用 filterFeature
└── LogDetailScene.swift                 # UI 层
```

### FilterTypes 完整实现

```swift
//
//  FilterTypes.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - Filter Error

/// Filter-related errors
public enum FilterError: Error, LocalizedError, Equatable {
    case loadingOptionsFailed
    case emptyFilterResult

    public var errorDescription: String? {
        switch self {
        case .loadingOptionsFailed:
            return "加载筛选选项失败"
        case .emptyFilterResult:
            return "筛选结果为空"
        }
    }
}

// MARK: - Filter Statistics

/// Filter statistics (用于 UI 展示)
public struct FilterStatistics: Equatable, Sendable {
    /// Total number of logs before filtering
    public let totalCount: Int

    /// Number of logs after filtering
    public let filteredCount: Int

    /// Filter efficiency (0.0 to 1.0)
    public var efficiency: Double {
        guard totalCount > 0 else { return 0 }
        return Double(filteredCount) / Double(totalCount)
    }

    public init(totalCount: Int, filteredCount: Int) {
        self.totalCount = totalCount
        self.filteredCount = filteredCount
    }
}
```

### FilterFeature 完整实现

```swift
//
//  FilterFeature.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - FilterFeature

public struct FilterFeature {
    // 私有初始化器，防止外部实例化
    private init() {}
}

// MARK: - State

extension FilterFeature {
    /// Filter State
    public struct State: Equatable, Sendable {
        // MARK: - Selected Filters

        /// Selected log levels
        public var selectedLevels: Set<LogEvent.Level> = []

        /// Selected functions
        public var selectedFunctions: Set<String> = []

        /// Selected file names
        public var selectedFileNames: Set<String> = []

        /// Selected contexts
        public var selectedContexts: Set<String> = []

        /// Selected threads
        public var selectedThreads: Set<String> = []

        /// Selected message keywords
        public var selectedMessageKeywords: Set<String> = []

        // MARK: - Available Options (用于 UI 展示)

        /// Available functions (从 statistics 获取)
        public var availableFunctions: [String] = []

        /// Available file names (从 statistics 获取)
        public var availableFileNames: [String] = []

        /// Available contexts
        public var availableContexts: [String] = []

        /// Available threads
        public var availableThreads: [String] = []

        /// Loading state for available options
        public var isLoadingOptions: Bool = false

        /// Error message (if loading options fails)
        public var error: Error?

        // MARK: - Computed Properties

        /// Whether any filter is active
        public var hasActiveFilters: Bool {
            !selectedLevels.isEmpty || !selectedFunctions.isEmpty ||
            !selectedFileNames.isEmpty || !selectedContexts.isEmpty ||
            !selectedThreads.isEmpty || !selectedMessageKeywords.isEmpty
        }

        /// Count of active filters
        public var activeFilterCount: Int {
            var count = 0
            if !selectedLevels.isEmpty { count += 1 }
            if !selectedFunctions.isEmpty { count += 1 }
            if !selectedFileNames.isEmpty { count += 1 }
            if !selectedContexts.isEmpty { count += 1 }
            if !selectedThreads.isEmpty { count += 1 }
            if !selectedMessageKeywords.isEmpty { count += 1 }
            return count
        }

        // MARK: - Initializer

        public init() {}

        // MARK: - State Mutations

        /// Reset all filters to initial state
        public mutating func reset() {
            selectedLevels.removeAll()
            selectedFunctions.removeAll()
            selectedFileNames.removeAll()
            selectedContexts.removeAll()
            selectedThreads.removeAll()
            selectedMessageKeywords.removeAll()
        }

        // MARK: - Equatable

        public static func == (lhs: State, rhs: State) -> Bool {
            lhs.selectedLevels == rhs.selectedLevels &&
            lhs.selectedFunctions == rhs.selectedFunctions &&
            lhs.selectedFileNames == rhs.selectedFileNames &&
            lhs.selectedContexts == rhs.selectedContexts &&
            lhs.selectedThreads == rhs.selectedThreads &&
            lhs.selectedMessageKeywords == rhs.selectedMessageKeywords &&
            lhs.availableFunctions == rhs.availableFunctions &&
            lhs.availableFileNames == rhs.availableFileNames &&
            lhs.availableContexts == rhs.availableContexts &&
            lhs.availableThreads == rhs.availableThreads &&
            lhs.isLoadingOptions == rhs.isLoadingOptions &&
            lhs.error?.localizedDescription == rhs.error?.localizedDescription
        }
    }
}

// MARK: - Action

extension FilterFeature {
    /// Filter Actions
    public enum Action: Equatable {
        // MARK: - User Actions (命令型)

        /// Toggle log level filter
        case toggleLevel(LogEvent.Level)

        /// Add function filter
        case addFunction(String)

        /// Remove function filter
        case removeFunction(String)

        /// Add file name filter
        case addFileName(String)

        /// Remove file name filter
        case removeFileName(String)

        /// Add context filter
        case addContext(String)

        /// Remove context filter
        case removeContext(String)

        /// Add thread filter
        case addThread(String)

        /// Remove thread filter
        case removeThread(String)

        /// Add message keyword filter
        case addMessageKeyword(String)

        /// Remove message keyword filter
        case removeMessageKeyword(String)

        /// Reset all filters
        case resetFilters

        /// Apply current filters (user initiates filter application)
        case applyFilters

        /// Load available options (functions, file names, etc.)
        case loadAvailableOptions

        // MARK: - System Feedback (事件型)

        /// Filters have been applied successfully (notifies parent to reload)
        case filtersApplied

        /// Available options loaded successfully
        case availableOptionsLoaded(
            functions: [String],
            fileNames: [String],
            contexts: [String],
            threads: [String]
        )

        /// Loading available options failed
        case loadingOptionsFailed(Error)

        // MARK: - Equatable

        public static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.toggleLevel(let l), .toggleLevel(let r)):
                return l == r
            case (.addFunction(let l), .addFunction(let r)),
                 (.removeFunction(let l), .removeFunction(let r)):
                return l == r
            case (.addFileName(let l), .addFileName(let r)),
                 (.removeFileName(let l), .removeFileName(let r)):
                return l == r
            case (.addContext(let l), .addContext(let r)),
                 (.removeContext(let l), .removeContext(let r)):
                return l == r
            case (.addThread(let l), .addThread(let r)),
                 (.removeThread(let l), .removeThread(let r)):
                return l == r
            case (.addMessageKeyword(let l), .addMessageKeyword(let r)),
                 (.removeMessageKeyword(let l), .removeMessageKeyword(let r)):
                return l == r
            case (.resetFilters, .resetFilters),
                 (.applyFilters, .applyFilters),
                 (.filtersApplied, .filtersApplied),
                 (.loadAvailableOptions, .loadAvailableOptions):
                return true
            case (.availableOptionsLoaded(let lf, let ln, let lc, let lt),
                  .availableOptionsLoaded(let rf, let rn, let rc, let rt)):
                return lf == rf && ln == rn && lc == rc && lt == rt
            case (.loadingOptionsFailed(let l), .loadingOptionsFailed(let r)):
                return l.localizedDescription == r.localizedDescription
            default:
                return false
            }
        }
    }
}

// MARK: - Reducer

extension FilterFeature {
    /// Filter Reducer
    public struct Reducer: LoggerKit.Reducer {
        public typealias State = FilterFeature.State
        public typealias Action = FilterFeature.Action

        private let environment: Environment

        public init(environment: Environment) {
            self.environment = environment
        }

        public func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            // MARK: - Toggle Filters

            case .toggleLevel(let level):
                if state.selectedLevels.contains(level) {
                    state.selectedLevels.remove(level)
                } else {
                    state.selectedLevels.insert(level)
                }
                return .none

            case .addFunction(let function):
                state.selectedFunctions.insert(function)
                return .none

            case .removeFunction(let function):
                state.selectedFunctions.remove(function)
                return .none

            case .addFileName(let fileName):
                state.selectedFileNames.insert(fileName)
                return .none

            case .removeFileName(let fileName):
                state.selectedFileNames.remove(fileName)
                return .none

            case .addContext(let context):
                state.selectedContexts.insert(context)
                return .none

            case .removeContext(let context):
                state.selectedContexts.remove(context)
                return .none

            case .addThread(let thread):
                state.selectedThreads.insert(thread)
                return .none

            case .removeThread(let thread):
                state.selectedThreads.remove(thread)
                return .none

            case .addMessageKeyword(let keyword):
                state.selectedMessageKeywords.insert(keyword)
                return .none

            case .removeMessageKeyword(let keyword):
                state.selectedMessageKeywords.remove(keyword)
                return .none

            case .resetFilters:
                state.reset()
                return .none

            case .applyFilters:
                // 通知父 Reducer 筛选已应用
                return .send(.filtersApplied)

            case .filtersApplied:
                // 由父 Reducer 处理 (触发列表重新加载)
                return .none

            // MARK: - Load Available Options

            case .loadAvailableOptions:
                return handleLoadAvailableOptions(&state)

            case .availableOptionsLoaded(let functions, let fileNames, let contexts, let threads):
                state.isLoadingOptions = false
                state.availableFunctions = functions
                state.availableFileNames = fileNames
                state.availableContexts = contexts
                state.availableThreads = threads
                state.error = nil
                return .none

            case .loadingOptionsFailed(let error):
                state.isLoadingOptions = false
                state.error = error
                return .none
            }
        }

        // MARK: - Private Handlers

        private func handleLoadAvailableOptions(_ state: inout State) -> Effect<Action> {
            state.isLoadingOptions = true
            state.error = nil

            return .task { [environment] in
                do {
                    // 从 dataLoader 获取统计信息
                    print("🔵 [FilterFeature] Loading available options...")

                    let functions = try await environment.dataLoader.getAvailableFunctions()
                    let fileNames = try await environment.dataLoader.getAvailableFileNames()
                    let contexts = try await environment.dataLoader.getAvailableContexts()
                    let threads = try await environment.dataLoader.getAvailableThreads()

                    print("🟢 [FilterFeature] Options loaded: \(functions.count) functions, \(fileNames.count) files")

                    return .availableOptionsLoaded(
                        functions: functions,
                        fileNames: fileNames,
                        contexts: contexts,
                        threads: threads
                    )
                } catch {
                    print("🔴 [FilterFeature] Failed to load options: \(error.localizedDescription)")
                    return .loadingOptionsFailed(error)
                }
            }
        }
    }
}

// MARK: - Environment

extension FilterFeature {
    /// Filter Environment (依赖注入)
    public struct Environment {
        /// Data loader for fetching available filter options
        let dataLoader: LogDataLoaderProtocol

        // MARK: - Live Environment

        public static func live() -> Environment {
            Environment(
                dataLoader: LogDataLoader.shared
            )
        }

        // MARK: - Mock Environment (for testing)

        public static func mock(
            dataLoader: LogDataLoaderProtocol = MockLogDataLoader()
        ) -> Environment {
            Environment(
                dataLoader: dataLoader
            )
        }
    }
}

```

**关键点**:
1. ✅ 完全独立的 Feature，拥有自己的 State、Action、Reducer、Environment
2. ✅ 可在多个场景复用 (LogDetailFeature、SearchFeature、SessionList 等)
3. ✅ 通过 Environment 注入依赖，易于测试
4. ✅ 计算属性 `hasActiveFilters` 和 `activeFilterCount` 便于 UI 展示
5. ✅ `filtersApplied` 事件明确通知父 Reducer
6. ⚠️ 暂不实现 `selectedSessionIds` (待明确使用场景)
7. ⚠️ 移除 `toFilterState()` 向后兼容方法 (完全迁移)

---

### 集成示例

#### 在 LogDetailFeature 中集成

```swift
// LogDetail/LogDetailState.swift
public final class LogDetailState: ObservableObject, Equatable, Sendable {
    // ... 现有属性

    // ✅ 筛选功能 (使用 FilterFeature)
    public var filterFeature: FilterFeature.State = .init()
}

// LogDetail/LogDetailAction.swift
public enum LogDetailAction: Equatable {
    // ... 现有 Actions

    // ✅ 筛选功能 (委托给 FilterFeature)
    case filter(FilterFeature.Action)

    // 协调 Action
    case filterChanged  // Filter → List (重新加载)
}

// LogDetail/LogDetailReducer.swift
public struct LogDetailReducer: Reducer {
    private let environment: LogDetailEnvironment
    private let filterReducer: FilterFeature.Reducer

    public init(environment: LogDetailEnvironment) {
        self.environment = environment
        self.filterReducer = FilterFeature.Reducer(
            environment: .live()
        )
    }

    public func reduce(_ state: inout LogDetailState, _ action: LogDetailAction) -> Effect<LogDetailAction> {
        switch action {
        case .filter(let filterAction):
            // 委托给 FilterFeature.Reducer
            let filterEffect = filterReducer.reduce(&state.filterFeature, filterAction)
            return filterEffect.map { .filter($0) }

        case .filter(.filtersApplied):
            // 筛选应用完成,触发列表刷新
            state.isFilterPresented = false
            state.list.resetPagination()
            return .task { .list(.loadLogFile) }

        // ... 其他 Actions
        default:
            return .none
        }
    }
}
```

---

## 已知问题与解决方案

### 问题 1: LogDataLoaderProtocol 缺少必要方法

**问题描述**:
FilterFeature.Reducer 的 `handleLoadAvailableOptions` 方法依赖以下接口:
```swift
environment.dataLoader.getAvailableFunctions()
environment.dataLoader.getAvailableFileNames()
environment.dataLoader.getAvailableContexts()
environment.dataLoader.getAvailableThreads()
```

**解决方案**:
在开始第一阶段前，确保 `LogDataLoaderProtocol` 包含这些方法（见[前置准备](#前置准备)）

**影响**: 如果不解决，第一阶段编译会失败

---

### 问题 2: applyFilters 职责不清

**原设计问题**:
```swift
case .applyFilters:
    // 筛选应用后,由父 Reducer 处理
    return .none  // ❌ 完全依赖父 Reducer 特殊判断
```

**改进方案**:
```swift
case .applyFilters:
    // 通知父 Reducer 筛选已应用
    return .send(.filtersApplied)  // ✅ 明确的完成事件

case .filtersApplied:
    // 由父 Reducer 处理
    return .none
```

**优势**:
- 事件驱动更清晰
- 父 Reducer 无需特殊判断 `applyFilters`
- 易于扩展（如添加分析、日志）

---

### 问题 3: selectedSessionIds 使用场景不明确

**问题描述**:
State 中包含 `selectedSessionIds: Set<String>`，但在 LogDetailScene 中的使用场景不清晰

**解决方案**:
第一、第二阶段先移除此功能，待明确以下场景后再添加:
- 在 Session 列表中筛选？
- 在日志列表中按 Session 筛选？
- 跨 Session 对比分析？

**原则**: 避免过度设计，按需添加

---

### 问题 4: 向后兼容方法的必要性

**问题描述**:
`toFilterState()` 方法用于向后兼容，但如果目标是完全替换旧 FilterState，此方法会增加维护负担

**解决方案**:
- 如果是完全迁移，移除 `toFilterState()`
- 如果需要渐进式迁移，保留但添加 `@available(*, deprecated)` 标记
- 设置迁移时间表，避免长期维护两套状态

---

## 总结

### 改造收益

1. ✅ **独立性强**: FilterFeature 完全独立，可在多个场景复用
2. ✅ **架构清晰**: 拥有完整的 State、Action、Reducer、Environment
3. ✅ **易于扩展**: 可轻松添加新的筛选器类型
4. ✅ **依赖注入**: 通过 Environment 注入依赖，利于测试和维护

### 时间估算

- **前置准备**: 1 小时 (检查并补充 LogDataLoaderProtocol)
- **第一阶段**: 2-3 小时 (创建完整 FilterFeature)
- **第二阶段**: 2-3 小时 (集成到 LogDetailFeature)
- **第三阶段**: 可选,根据需求 (2-4 小时/功能)
- **总计**: **5-7 小时** (约 1 个工作日)

### 设计说明

| 方面 | 设计选择 | 原因 |
|-----|---------|------|
| **架构模式** | 完整 FilterFeature | 独立可复用，支持多场景 |
| **State 设计** | 独立的 FilterFeature.State | 完全解耦，易于维护 |
| **Action 设计** | 细粒度 Action | 精确控制每个筛选器 |
| **依赖管理** | Environment 注入 | 易于测试和替换实现 |

### 关键决策

1. **✅ 采用完整 FilterFeature** - 独立可复用，支持多场景使用
2. **✅ 独立 State 设计** - 与 LogDetailFeature 解耦，易于维护
3. **✅ Environment 注入** - 依赖倒置，易于测试
4. **✅ 事件驱动通信** - 使用 `filtersApplied` 事件替代特殊判断
5. **✅ 分阶段实施** - 前置准备 → 创建 Feature → 集成 → 扩展功能
6. **✅ 避免过度设计** - 暂不实现 `selectedSessionIds`，待明确需求

### 风险控制

1. ✅ **前置检查**: 开始前验证 LogDataLoaderProtocol 接口完整性
2. ✅ **Git 分支隔离**: 在独立分支上开发,可随时回滚
3. ✅ **编译验证**: 每个步骤后确保编译通过
4. ✅ **功能验证**: 集成后立即测试所有筛选场景
5. ✅ **增量迁移**: 前置准备 → 创建 FilterFeature → 集成到 LogDetailFeature
6. ✅ **清理冗余代码**: 移除向后兼容方法和未使用功能
