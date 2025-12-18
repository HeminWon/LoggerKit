# ExportFeature TCA 重构方案

## 目录

1. [重构目标](#重构目标)
2. [架构设计](#架构设计)
3. [改造步骤](#改造步骤)
4. [代码实现细节](#代码实现细节)

---

## 重构目标

### 当前问题

导出功能当前实现存在以下问题:

1. **状态分散**: 导出状态(`isExporting`, `exportProgress`, `exportedCount` 等)分散在 `LogDetailState` 和 `ExportState` 中
2. **逻辑耦合**: 导出逻辑在 `LogDetailReducer` 的核心 Action 中处理,与其他业务逻辑混合
3. **职责不清**: `LogDetailSceneState.exportAllEventsStreaming()` 方法直接操作导出,绕过了 TCA 架构
4. **难以复用**: 导出逻辑与 LogDetailFeature 强耦合,无法在其他场景复用(如导出单个 Session)

### 改造目标

1. ✅ **独立性**: 将导出功能提取为独立的 `ExportFeature`,实现完整的 TCA 架构
2. ✅ **可复用**: ExportFeature 可以在其他场景复用(如导出单个 session、导出搜索结果)
3. ✅ **向后兼容**: 通过 Facade 模式保持现有 API 不变

---

## 架构设计

### Feature 结构

```
Sources/LoggerKit/UI/
├── SubFeatures/
│   ├── FilterReducer.swift        # 现有过滤 Reducer
│   ├── PaginationReducer.swift    # 现有分页 Reducer
│   ├── SearchReducer.swift        # 现有搜索 Reducer
│   └── CacheReducer.swift         # 现有缓存 Reducer
│
└── Export/                         # ✅ 新增:完整 ExportFeature (独立可复用)
    ├── ExportFeature.swift         # State + Action + Reducer + Environment
    └── ExportTypes.swift           # ExportFormat, ExportError, FilterOptions
```

**设计原则**:
- **独立性**: ExportFeature 拥有自己的 State、Action、Reducer、Environment
- **可复用性**: 可在多个场景使用 (导出所有日志、导出 Session、导出搜索结果)
- **解耦**: 与 LogDetailFeature 解耦，通过 Environment 注入依赖

### State 设计

```swift
// Export/ExportFeature.swift
struct ExportFeature {
    /// Export State
    struct State: Equatable, Sendable {
        // MARK: - Export Configuration

        /// Selected export format
        var format: ExportFormat = .log

        /// Session IDs to export (empty = all sessions)
        var sessionIds: Set<String> = []

        /// Filter options (optional, for exporting filtered results)
        var filterOptions: FilterOptions?

        // MARK: - Progress State

        /// Whether export is currently in progress
        var isExporting: Bool = false

        /// Export progress (0.0 to 1.0)
        var progress: Double = 0.0

        /// Number of events exported so far
        var exportedCount: Int = 0

        /// Total number of events to export
        var totalCount: Int = 0

        // MARK: - Result State

        /// URL of the exported file (set when export completes successfully)
        var exportedFileURL: URL?

        /// Export error (if any)
        var error: Error?

        // MARK: - Computed Properties

        /// Whether export is in idle state (not started, completed, or failed)
        var isIdle: Bool {
            !isExporting && exportedFileURL == nil && error == nil
        }

        /// Whether export completed successfully
        var isCompleted: Bool {
            !isExporting && exportedFileURL != nil
        }

        /// Whether export failed
        var isFailed: Bool {
            !isExporting && error != nil
        }

        // MARK: - State Mutations

        /// Reset to initial state
        mutating func reset() {
            isExporting = false
            progress = 0.0
            exportedCount = 0
            totalCount = 0
            exportedFileURL = nil
            error = nil
        }

        /// Update progress
        mutating func updateProgress(exported: Int, total: Int) {
            exportedCount = exported
            totalCount = total
            progress = total > 0 ? Double(exported) / Double(total) : 0.0
        }
    }
}
```

### Action 设计

```swift
// Export/ExportFeature.swift
extension ExportFeature {
    /// Export Actions
    enum Action: Equatable {
        // MARK: - User Actions (命令型)

        /// Start export with specified format
        case startExport(format: ExportFormat)

        /// Cancel ongoing export
        case cancelExport

        /// Reset export state to initial
        case resetExport

        // MARK: - System Feedback (事件型)

        /// Export preparation started (counting total events)
        case exportPreparationStarted

        /// Total count calculated
        case totalCountCalculated(Int)

        /// Progress updated
        case progressUpdated(exported: Int, total: Int)

        /// Export completed successfully
        case exportSucceeded(URL)

        /// Export failed with error
        case exportFailed(Error)

        // MARK: - Equatable

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.startExport(let lf), .startExport(let rf)):
                return lf == rf
            case (.cancelExport, .cancelExport),
                 (.resetExport, .resetExport),
                 (.exportPreparationStarted, .exportPreparationStarted):
                return true
            case (.totalCountCalculated(let l), .totalCountCalculated(let r)):
                return l == r
            case (.progressUpdated(let le, let lt), .progressUpdated(let re, let rt)):
                return le == re && lt == rt
            case (.exportSucceeded(let l), .exportSucceeded(let r)):
                return l == r
            case (.exportFailed(let l), .exportFailed(let r)):
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
// Export/ExportFeature.swift
extension ExportFeature {
    /// Export Reducer
    struct Reducer: LoggerKit.Reducer {
        typealias State = ExportFeature.State
        typealias Action = ExportFeature.Action

        private let environment: Environment

        init(environment: Environment) {
            self.environment = environment
        }

        func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            case .startExport(let format):
                return handleStartExport(&state, format: format)

            case .cancelExport:
                return handleCancelExport(&state)

            case .resetExport:
                state.reset()
                return .none

            case .exportPreparationStarted:
                state.isExporting = true
                state.progress = 0.0
                state.error = nil
                state.exportedFileURL = nil
                return .none

            case .totalCountCalculated(let total):
                state.totalCount = total
                return .none

            case .progressUpdated(let exported, let total):
                state.updateProgress(exported: exported, total: total)
                return .none

            case .exportSucceeded(let url):
                state.isExporting = false
                state.exportedFileURL = url
                state.progress = 1.0
                return .none

            case .exportFailed(let error):
                state.isExporting = false
                state.error = error
                return .none
            }
        }

        // MARK: - Private Handlers

        private func handleStartExport(_ state: inout State, format: ExportFormat) -> Effect<Action> {
            // Update state
            state.format = format
            state.reset()
            state.isExporting = true

            // Capture values
            let sessionIds = state.sessionIds.isEmpty ? environment.allSessionIds : state.sessionIds
            let filterOptions = state.filterOptions

            return .multiple([
                // 1. Signal preparation started
                .task { .exportPreparationStarted },

                // 2. Execute export
                .cancellable(id: CancellationID.export) { [environment] in
                    do {
                        // Step 1: Count total events
                        print("🔵 [ExportFeature] Counting total events...")
                        let totalCount = try await environment.dataLoader.countEvents(
                            sessionIds: sessionIds,
                            filterState: filterOptions?.toFilterState()
                        )
                        print("🟢 [ExportFeature] Total events: \(totalCount)")

                        // Send total count
                        await MainActor.run {
                            // Note: This would normally be handled by the Store
                            // but for clarity we're showing the action flow
                        }

                        guard totalCount > 0 else {
                            throw ExportError.emptyData
                        }

                        // Step 2: Generate file name
                        let fileName = generateFileName(
                            sessionIds: sessionIds,
                            format: format
                        )

                        // Step 3: Stream export to file
                        print("🔵 [ExportFeature] Starting streaming export...")
                        let fileURL = try await LogParser.logEventToTempFileStreaming(
                            fileName: fileName,
                            batchSize: 1000,
                            progressHandler: { written, _ in
                                // Note: In real implementation, we'd dispatch .progressUpdated
                                // here through a callback mechanism
                                print("📊 [ExportFeature] Progress: \(written)/\(totalCount)")
                            },
                            eventFetcher: { offset, limit in
                                print("🔵 [ExportFeature] Fetching batch: offset=\(offset), limit=\(limit)")
                                return try await environment.dataLoader.loadEvents(
                                    sessionIds: sessionIds,
                                    filterState: filterOptions?.toFilterState(),
                                    offset: offset,
                                    limit: limit
                                )
                            }
                        )

                        print("🟢 [ExportFeature] Export completed: \(fileURL.path)")
                        return .exportSucceeded(fileURL)

                    } catch {
                        print("🔴 [ExportFeature] Export failed: \(error.localizedDescription)")
                        return .exportFailed(error)
                    }
                }
            ])
        }

        private func handleCancelExport(_ state: inout State) -> Effect<Action> {
            state.isExporting = false

            // Cancel the ongoing export task
            return .cancel(id: CancellationID.export)
        }

        // MARK: - Helpers

        private func generateFileName(sessionIds: Set<String>, format: ExportFormat) -> String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let dateString = dateFormatter.string(from: Date())

            let sessionIdentifier = sessionIds.count == 1 ? sessionIds.first! : "all"
            let ext = format == .json ? "json" : "log"

            return "logs_\(sessionIdentifier)_\(dateString).\(ext)"
        }

        // MARK: - Cancellation IDs

        enum CancellationID: Hashable {
            case export
        }
    }
}
```

### Environment 设计

```swift
// Export/ExportFeature.swift
extension ExportFeature {
    /// Export Environment (依赖注入)
    struct Environment {
        /// Data loader for fetching events
        let dataLoader: LogDataLoaderProtocol

        /// All available session IDs (for "export all" scenario)
        let allSessionIds: Set<String>

        // MARK: - Live Environment

        static func live(sessionIds: Set<String>) -> Environment {
            Environment(
                dataLoader: LogDataLoader.shared,
                allSessionIds: sessionIds
            )
        }

        // MARK: - Mock Environment (for testing)

        static func mock(
            dataLoader: LogDataLoaderProtocol = MockLogDataLoader(),
            allSessionIds: Set<String> = ["mock-session"]
        ) -> Environment {
            Environment(
                dataLoader: dataLoader,
                allSessionIds: allSessionIds
            )
        }
    }
}
```

### Supporting Types

```swift
// Export/ExportFeature.swift

/// Export format options
public enum ExportFormat: String, Equatable, CaseIterable, Sendable {
    case log    // Plain text log format
    // ⚠️ 第一阶段只支持 .log
    // case json   // JSON format (第三阶段扩展功能)

    public var displayName: String {
        switch self {
        case .log: return "Text (.log)"
        }
    }
}

/// Export errors
public enum ExportError: Error, LocalizedError, Equatable {
    case emptyData
    case fileCreationFailed
    case writeFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .emptyData:
            return "No data to export"
        case .fileCreationFailed:
            return "Failed to create export file"
        case .writeFailed(let reason):
            return "Write failed: \(reason)"
        case .cancelled:
            return "Export cancelled by user"
        }
    }
}

/// Filter options (for exporting filtered results)
public struct FilterOptions: Equatable, Sendable {
    var levels: Set<LogEvent.Level> = []
    var functions: Set<String> = []
    var fileNames: Set<String> = []
    var contexts: Set<String> = []
    var threads: Set<String> = []
    var messageKeywords: Set<String> = []
    var sessionIds: Set<String> = []

    func toFilterState() -> FilterState? {
        guard !isEmpty else { return nil }

        let state = FilterState()
        state.selectedLevels = levels
        state.selectedFunctions = functions
        state.selectedFileNames = fileNames
        state.selectedContexts = contexts
        state.selectedThreads = threads
        state.selectedMessageKeywords = messageKeywords
        state.selectedSessionIds = sessionIds
        return state
    }

    var isEmpty: Bool {
        levels.isEmpty && functions.isEmpty && fileNames.isEmpty &&
        contexts.isEmpty && threads.isEmpty && messageKeywords.isEmpty &&
        sessionIds.isEmpty
    }
}
```

---

## 改造步骤

### 前置步骤: 添加 Effect.cancel 支持

**目标**: 为 TCA 基础设施添加取消功能支持

**步骤**:

1. ✅ 在 `Effect.swift` 中添加 `case cancel(id: AnyHashable)`
2. ✅ 在 `Store.swift` 的 `executeEffect` 中处理 `.cancel` 分支
3. ✅ 编译验证

**验证**:
```bash
# 编译通过
swift build
```

**时间估计**: 30 分钟

---

### 第一阶段: 创建完整 ExportFeature

**目标**: 创建独立的 ExportFeature，包含完整的 State、Action、Reducer、Environment

**步骤**:

1. ✅ 创建目录 `Sources/LoggerKit/UI/Export/`
2. ✅ 创建 `ExportTypes.swift` - 定义 ExportFormat、ExportError、FilterOptions
3. ✅ 创建 `ExportFeature.swift` - 定义完整的 Feature
   - `ExportFeature.State` - 独立的导出状态
   - `ExportFeature.Action` - 导出相关的 Action
   - `ExportFeature.Reducer` - 导出逻辑的 Reducer
   - `ExportFeature.Environment` - 依赖注入
4. ✅ 确保编译通过

**验证**:
```bash
# 编译通过
swift build
```

**时间估计**: 3-4 小时

---

### 第二阶段: 集成 ExportFeature 到 LogDetailFeature

**目标**: 在 LogDetailFeature 中集成 ExportFeature，替换原有导出逻辑

**步骤**:

1. ✅ 在 `LogDetailState` 中添加 `ExportFeature.State`
   ```swift
   // LogDetail/LogDetailState.swift
   public final class LogDetailState: ObservableObject, Equatable, Sendable {
       // ... 现有属性

       // 导出功能 (使用 ExportFeature)
       public var exportFeature: ExportFeature.State = .init()

       // ❌ 移除旧的 exportState: ExportState
   }
   ```

2. ✅ 在 `LogDetailAction` 中添加 ExportFeature Action
   ```swift
   // LogDetail/LogDetailAction.swift
   public enum LogDetailAction: Equatable {
       // ... 现有 Actions

       // 导出功能 (委托给 ExportFeature)
       case export(ExportFeature.Action)

       // ❌ 移除旧的导出 Actions:
       // case .exportStarted
       // case .exportProgressUpdated
       // case .exportLogs
       // case .exportCompleted
       // case .exportFailed
   }
   ```

3. ✅ 在 `LogDetailReducer` 中集成 `ExportFeature.Reducer`
   ```swift
   // LogDetail/LogDetailReducer.swift
   public struct LogDetailReducer: Reducer {
       private let environment: LogDetailEnvironment
       private let exportReducer: ExportFeature.Reducer  // ✅ 新增

       public init(environment: LogDetailEnvironment) {
           self.environment = environment

           // 初始化 ExportReducer
           let exportEnv = ExportFeature.Environment.live(
               dataLoader: environment.dataLoader,
               allSessionIds: environment.sessionIds
           )
           self.exportReducer = ExportFeature.Reducer(environment: exportEnv)
       }

       public func reduce(_ state: inout LogDetailState, _ action: LogDetailAction) -> Effect<LogDetailAction> {
           switch action {
           case .export(let exportAction):
               // 委托给 ExportFeature.Reducer
               let exportEffect = exportReducer.reduce(&state.exportFeature, exportAction)
               return exportEffect.map { .export($0) }

           // ... 其他 Actions
           default:
               return handleOtherActions(&state, action)
           }
       }
   }
   ```

4. ✅ 更新 `LogDetailSceneState` 使用新的 ExportFeature
   ```swift
   // UI/LogDetailSceneState.swift
   // 更新绑定使用 exportFeature
   store.$state
       .map { $0.exportFeature.isExporting }
       .assign(to: &$isExporting)

   store.$state
       .map { $0.exportFeature.exportedFileURL }
       .assign(to: &$exportedFileURL)

   // 更新导出方法
   func exportAllEventsStreaming() async throws -> URL {
       await store.send(.export(.startExport(format: .log)))
       // ... 等待完成
   }
   ```

**验证**:
```bash
# 1. 编译通过
swift build

# 2. 在模拟器中测试导出功能:
#    - 导出所有日志
#    - 导出带筛选条件的日志
#    - 验证进度更新正常
#    - 验证导出文件内容正确
```

**时间估计**: 1-2 小时

---

### 第三阶段: 扩展功能 (可选 - 未来)

**目标**: 利用 ExportFeature 的独立性，在多个场景复用

**可能的扩展**:

1. ⚠️ **支持 JSON 导出格式**
   - 在 `LogParser` 中实现 JSON 序列化
   - 在 `ExportTypes.swift` 中更新 `ExportFormat` 枚举
   ```swift
   public enum ExportFormat: String, Equatable, CaseIterable, Sendable {
       case log
       case json  // ✅ 新增
   }
   ```

2. ⚠️ **在 Session 列表中复用 ExportFeature**
   - 在 SessionListState 中添加 `exportFeature: ExportFeature.State`
   - 添加"导出此 Session"按钮
   ```swift
   // SessionListView
   Button("导出此 Session") {
       var exportState = ExportFeature.State()
       exportState.sessionIds = [selectedSessionId]
       store.send(.export(.startExport(format: .log)))
   }
   ```

3. ⚠️ **在搜索结果中复用 ExportFeature**
   - 在 SearchState 中添加 `exportFeature: ExportFeature.State`
   - 添加"导出搜索结果"按钮
   - 通过 `filterOptions` 传递搜索条件
   ```swift
   var exportState = ExportFeature.State()
   exportState.filterOptions = FilterOptions(/* 搜索条件 */)
   store.send(.export(.startExport(format: .log)))
   ```

4. ⚠️ **实现取消导出功能**
   - ExportFeature 已支持 `.cancelExport` Action
   - 在 UI 中添加"取消"按钮
   ```swift
   if state.exportFeature.isExporting {
       Button("取消导出") {
           store.send(.export(.cancelExport))
       }
   }
   ```

**时间估计**: 根据需求,每个功能 2-4 小时

---

## 代码实现细节

### 完整文件结构

```
Sources/LoggerKit/UI/
├── TCA/
│   ├── Effect.swift                     # ⚠️ 需要添加 .cancel(id:) 支持
│   ├── Store.swift                      # ⚠️ 需要在 executeEffect 中处理 .cancel
│   └── Reducer.swift
│
├── Export/                              # ✅ 新增:完整 ExportFeature
│   ├── ExportFeature.swift              # State + Action + Reducer + Environment
│   └── ExportTypes.swift                # ExportFormat + ExportError + FilterOptions
│
├── LogDetail/
│   ├── LogDetailState.swift             # ✅ 更新:使用 exportFeature: ExportFeature.State
│   ├── LogDetailAction.swift            # ✅ 更新:添加 case export(ExportFeature.Action)
│   ├── LogDetailReducer.swift           # ✅ 更新:集成 ExportFeature.Reducer
│   └── LogDetailEnvironment.swift
│
├── LogDetailSceneState.swift            # ✅ 更新:使用 exportFeature
└── LogDetailScene.swift                 # UI 层
```

### ExportTypes 完整实现

首先创建支持类型定义:

```swift
//
//  ExportTypes.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - Export Format

/// Export format options
public enum ExportFormat: String, Equatable, CaseIterable, Sendable {
    case log    // Plain text log format
    // case json   // JSON format (第三阶段扩展功能)

    public var displayName: String {
        switch self {
        case .log: return "Text (.log)"
        }
    }
}

// MARK: - Export Error

/// Export errors
public enum ExportError: Error, LocalizedError, Equatable {
    case emptyData
    case fileCreationFailed
    case writeFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .emptyData:
            return "无数据可导出"
        case .fileCreationFailed:
            return "创建导出文件失败"
        case .writeFailed(let reason):
            return "写入失败: \(reason)"
        case .cancelled:
            return "用户取消导出"
        }
    }
}

// MARK: - Filter Options

/// Filter options (用于导出筛选后的结果)
public struct FilterOptions: Equatable, Sendable {
    var levels: Set<LogEvent.Level> = []
    var functions: Set<String> = []
    var fileNames: Set<String> = []
    var contexts: Set<String> = []
    var threads: Set<String> = []
    var messageKeywords: Set<String> = []
    var sessionIds: Set<String> = []

    /// 转换为 FilterState
    func toFilterState() -> FilterState? {
        guard !isEmpty else { return nil }

        let state = FilterState()
        state.selectedLevels = levels
        state.selectedFunctions = functions
        state.selectedFileNames = fileNames
        state.selectedContexts = contexts
        state.selectedThreads = threads
        state.selectedMessageKeywords = messageKeywords
        state.selectedSessionIds = sessionIds
        return state
    }

    /// 是否为空
    var isEmpty: Bool {
        levels.isEmpty && functions.isEmpty && fileNames.isEmpty &&
        contexts.isEmpty && threads.isEmpty && messageKeywords.isEmpty &&
        sessionIds.isEmpty
    }
}
```

### ExportFeature 完整实现

这是完整的 ExportFeature，包含 State、Action、Reducer、Environment:

```swift
//
//  ExportFeature.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - ExportFeature

public struct ExportFeature {
    // 私有初始化器，防止外部实例化
    private init() {}
}

// MARK: - State

extension ExportFeature {
    /// Export State
    public struct State: Equatable, Sendable {
        // MARK: - Export Configuration

        /// Selected export format
        public var format: ExportFormat = .log

        /// Session IDs to export (empty = all sessions)
        public var sessionIds: Set<String> = []

        /// Filter options (optional, for exporting filtered results)
        public var filterOptions: FilterOptions?

        // MARK: - Progress State

        /// Whether export is currently in progress
        public var isExporting: Bool = false

        /// Export progress (0.0 to 1.0)
        public var progress: Double = 0.0

        /// Number of events exported so far
        public var exportedCount: Int = 0

        /// Total number of events to export
        public var totalCount: Int = 0

        // MARK: - Result State

        /// URL of the exported file (set when export completes successfully)
        public var exportedFileURL: URL?

        /// Export error (if any)
        public var error: Error?

        // MARK: - Computed Properties

        /// Whether export is in idle state (not started, completed, or failed)
        public var isIdle: Bool {
            !isExporting && exportedFileURL == nil && error == nil
        }

        /// Whether export completed successfully
        public var isCompleted: Bool {
            !isExporting && exportedFileURL != nil
        }

        /// Whether export failed
        public var isFailed: Bool {
            !isExporting && error != nil
        }

        // MARK: - Initializer

        public init() {}

        // MARK: - State Mutations

        /// Reset to initial state
        public mutating func reset() {
            isExporting = false
            progress = 0.0
            exportedCount = 0
            totalCount = 0
            exportedFileURL = nil
            error = nil
        }

        /// Update progress
        public mutating func updateProgress(exported: Int, total: Int) {
            exportedCount = exported
            totalCount = total
            progress = total > 0 ? Double(exported) / Double(total) : 0.0
        }

        // MARK: - Equatable

        public static func == (lhs: State, rhs: State) -> Bool {
            lhs.format == rhs.format &&
            lhs.sessionIds == rhs.sessionIds &&
            lhs.filterOptions == rhs.filterOptions &&
            lhs.isExporting == rhs.isExporting &&
            lhs.progress == rhs.progress &&
            lhs.exportedCount == rhs.exportedCount &&
            lhs.totalCount == rhs.totalCount &&
            lhs.exportedFileURL == rhs.exportedFileURL &&
            lhs.error?.localizedDescription == rhs.error?.localizedDescription
        }
    }
}

// MARK: - Action

extension ExportFeature {
    /// Export Actions
    public enum Action: Equatable {
        // MARK: - User Actions (命令型)

        /// Start export with specified format
        case startExport(format: ExportFormat)

        /// Cancel ongoing export
        case cancelExport

        /// Reset export state to initial
        case resetExport

        // MARK: - System Feedback (事件型)

        /// Export preparation started (counting total events)
        case exportPreparationStarted

        /// Total count calculated
        case totalCountCalculated(Int)

        /// Progress updated
        case progressUpdated(exported: Int, total: Int)

        /// Export completed successfully
        case exportSucceeded(URL)

        /// Export failed with error
        case exportFailed(Error)

        // MARK: - Equatable

        public static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.startExport(let lf), .startExport(let rf)):
                return lf == rf
            case (.cancelExport, .cancelExport),
                 (.resetExport, .resetExport),
                 (.exportPreparationStarted, .exportPreparationStarted):
                return true
            case (.totalCountCalculated(let l), .totalCountCalculated(let r)):
                return l == r
            case (.progressUpdated(let le, let lt), .progressUpdated(let re, let rt)):
                return le == re && lt == rt
            case (.exportSucceeded(let l), .exportSucceeded(let r)):
                return l == r
            case (.exportFailed(let l), .exportFailed(let r)):
                return l.localizedDescription == r.localizedDescription
            default:
                return false
            }
        }
    }
}

// MARK: - Reducer

extension ExportFeature {
    /// Export Reducer
    public struct Reducer: LoggerKit.Reducer {
        public typealias State = ExportFeature.State
        public typealias Action = ExportFeature.Action

        private let environment: Environment

        public init(environment: Environment) {
            self.environment = environment
        }

        public func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            case .startExport(let format):
                return handleStartExport(&state, format: format)

            case .cancelExport:
                return handleCancelExport(&state)

            case .resetExport:
                state.reset()
                return .none

            case .exportPreparationStarted:
                state.isExporting = true
                state.progress = 0.0
                state.error = nil
                state.exportedFileURL = nil
                return .none

            case .totalCountCalculated(let total):
                state.totalCount = total
                return .none

            case .progressUpdated(let exported, let total):
                state.updateProgress(exported: exported, total: total)
                return .none

            case .exportSucceeded(let url):
                state.isExporting = false
                state.exportedFileURL = url
                state.progress = 1.0
                return .none

            case .exportFailed(let error):
                state.isExporting = false
                state.error = error
                return .none
            }
        }

        // MARK: - Private Handlers

        private func handleStartExport(_ state: inout State, format: ExportFormat) -> Effect<Action> {
            // Update state
            state.format = format
            state.reset()
            state.isExporting = true

            // Capture values
            let sessionIds = state.sessionIds.isEmpty ? environment.allSessionIds : state.sessionIds
            let filterOptions = state.filterOptions

            return .cancellable(id: CancellationID.export) { [environment] in
                do {
                    // Step 1: Count total events
                    print("🔵 [ExportFeature] Counting total events...")
                    let totalCount = try await environment.dataLoader.countEvents(
                        sessionIds: sessionIds,
                        filterState: filterOptions?.toFilterState()
                    )
                    print("🟢 [ExportFeature] Total events: \(totalCount)")

                    guard totalCount > 0 else {
                        throw ExportError.emptyData
                    }

                    // Step 2: Generate file name
                    let fileName = generateFileName(
                        sessionIds: sessionIds,
                        format: format
                    )

                    // Step 3: Stream export to file
                    print("🔵 [ExportFeature] Starting streaming export...")
                    let fileURL = try await LogParser.logEventToTempFileStreaming(
                        fileName: fileName,
                        batchSize: 1000,
                        progressHandler: { written, _ in
                            print("📊 [ExportFeature] Progress: \(written)/\(totalCount)")
                        },
                        eventFetcher: { offset, limit in
                            print("🔵 [ExportFeature] Fetching batch: offset=\(offset), limit=\(limit)")
                            return try await environment.dataLoader.loadEvents(
                                sessionIds: sessionIds,
                                filterState: filterOptions?.toFilterState(),
                                offset: offset,
                                limit: limit
                            )
                        }
                    )

                    print("🟢 [ExportFeature] Export completed: \(fileURL.path)")
                    return .exportSucceeded(fileURL)

                } catch {
                    print("🔴 [ExportFeature] Export failed: \(error.localizedDescription)")
                    return .exportFailed(error)
                }
            }
        }

        private func handleCancelExport(_ state: inout State) -> Effect<Action> {
            state.isExporting = false
            return .cancel(id: CancellationID.export)
        }

        // MARK: - Helpers

        private func generateFileName(sessionIds: Set<String>, format: ExportFormat) -> String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let dateString = dateFormatter.string(from: Date())

            let sessionIdentifier = sessionIds.count == 1 ? sessionIds.first! : "all"
            let ext = format == .log ? "log" : "json"

            return "logs_\(sessionIdentifier)_\(dateString).\(ext)"
        }

        // MARK: - Cancellation IDs

        enum CancellationID: Hashable {
            case export
        }
    }
}

// MARK: - Environment

extension ExportFeature {
    /// Export Environment (依赖注入)
    public struct Environment {
        /// Data loader for fetching events
        let dataLoader: LogDataLoaderProtocol

        /// All available session IDs (for "export all" scenario)
        let allSessionIds: Set<String>

        // MARK: - Live Environment

        public static func live(
            dataLoader: LogDataLoaderProtocol,
            allSessionIds: Set<String>
        ) -> Environment {
            Environment(
                dataLoader: dataLoader,
                allSessionIds: allSessionIds
            )
        }
    }
}
```

**关键点**:
1. ✅ 完全独立的 Feature，拥有自己的 State、Action、Reducer、Environment
2. ✅ 可在多个场景复用 (LogDetailFeature、SessionList、SearchResults 等)
3. ✅ 通过 Environment 注入依赖，易于测试
4. ✅ 支持取消功能 (通过 Effect.cancel)

---

### 前置依赖: Effect.cancel 实现

**⚠️ 关键**: 取消导出功能依赖 Effect 的 cancel 支持,必须先实现

**1. 在 `Effect.swift` 中添加 `.cancel(id:)` 枚举**

```swift
// Sources/LoggerKit/UI/TCA/Effect.swift

public enum Effect<Action> {
    case none
    case task(() async -> Action?)
    case cancellable(id: AnyHashable, () async throws -> Action?)
    case multiple([Effect<Action>])
    case cancel(id: AnyHashable)  // ✅ 新增: 取消指定 ID 的 Effect
}
```

**2. 在 `Store.swift` 的 `executeEffect` 中处理 cancel**

```swift
// Sources/LoggerKit/UI/TCA/Store.swift

@MainActor
public final class Store<State: Equatable, Action>: ObservableObject, EffectExecutorProtocol {
    // ... 现有代码

    // MARK: - Effect Execution

    private func executeEffect(_ effect: Effect<Action>) async {
        switch effect {
        case .none:
            return

        case .task(let asyncTask):
            if let action = await asyncTask() {
                await send(action)
            }

        case .cancellable(let id, let asyncTask):
            // 取消旧任务
            cancel(id: id)

            // 启动新任务
            runningTasks[id] = Task { [weak self] in
                guard let self = self else { return }

                if let action = try? await asyncTask() {
                    await self.send(action)
                }

                await MainActor.run {
                    self.runningTasks[id] = nil
                }
            }

        case .cancel(let id):  // ✅ 新增: 处理取消
            cancel(id: id)

        case .multiple(let effects):
            await withTaskGroup(of: Void.self) { group in
                for effect in effects {
                    group.addTask { [weak self] in
                        await self?.executeEffect(effect)
                    }
                }
            }
        }
    }
}
```

**3. 验证**

```bash
# 编译确认无错误
swift build

# 预期输出: BUILD SUCCEEDED
```

### 进度更新机制简化

**问题**: LogParser 使用回调 `(Int, Int) -> Void`,而 TCA 推荐通过 Action 更新状态

**现有 API**:
```swift
public static func logEventToTempFileStreaming(
    fileName: String,
    batchSize: Int = 1000,
    progressHandler: @escaping (Int, Int) -> Void,  // ⚠️ 回调机制
    eventFetcher: (Int, Int) async throws -> [LogEvent]
) async throws -> URL
```

**解决方案对比**:

| 方案 | 优点 | 缺点 | 推荐度 |
|-----|------|------|--------|
| **A. 直接回调** | 简单直接,0额外代码 | 进度不经过 State,不符合纯 TCA | ⭐⭐⭐⭐⭐ (推荐) |
| B. Actor 桥接 | 类型安全,进度可追踪 | 增加 50+ 行代码,过度工程化 | ⭐⭐ |
| C. AsyncStream | 完全符合 TCA,可时间旅行 | 复杂度高,调试困难 | ⭐⭐⭐ (未来) |

**采用方案 A - 直接回调** (务实选择):

```swift
// SubFeatures/ExportReducer.swift
private func handleExport(..., progress: @escaping @Sendable (Double) -> Void) -> Effect<LogDetailAction> {
    // 重置导出状态
    state.exportState = ExportState()
    state.exportState.isExporting = true

    // ... 准备参数

    return .task { [environment] in
        do {
            // 1. 计算总数
            let totalCount = try await environment.dataLoader.countEvents(...)

            // 2. 流式导出,直接使用回调
            let fileURL = try await LogParser.logEventToTempFileStreaming(
                fileName: fileName,
                batchSize: 1000,
                progressHandler: { written, _ in
                    // ✅ 直接调用回调,不通过 Action
                    let progressPercent = Double(written) / Double(totalCount)
                    progress(progressPercent)
                },
                eventFetcher: { offset, limit in
                    try await environment.dataLoader.loadEvents(...)
                }
            )

            return .exportCompleted(fileURL)
        } catch {
            return .exportFailed(error)
        }
    }
}
```

**为什么推荐方案 A**:
1. ✅ **简洁**: 0 额外代码,直接使用现有 API
2. ✅ **务实**: 进度条是 UI 效果,不需要状态追踪
3. ✅ **兼容**: 与现有 `LogDetailSceneState.exportAllEventsStreaming` 保持一致
4. ✅ **性能**: 避免频繁的 Action 派发(每秒可能数十次)

**未来优化** (可选):
- 如需状态回溯,再升级到 AsyncStream 方案
- 当前阶段,保持简单最重要

---

## 回滚方案

### 如果集成后出现问题

**症状**: ExportFeature 集成后导出失败或性能问题

**回滚步骤**:
1. 从 Git 恢复到集成前的状态
   ```bash
   # 回滚到集成前的提交
   git reset --hard <集成前的commit-hash>
   ```

2. 或者手动恢复：
   - 从 `LogDetailState` 中移除 `exportFeature` 属性
   - 从 `LogDetailAction` 中移除 `case export(ExportFeature.Action)`
   - 从 `LogDetailReducer` 中移除 ExportFeature 相关代码
   - 恢复原有的导出实现

3. 重新编译和部署
   ```bash
   swift build
   ```

4. 验证旧实现正常工作

### 如果 ExportFeature 本身有问题

**症状**: ExportFeature 创建过程中发现设计缺陷

**回滚步骤**:
1. 删除 ExportFeature 相关文件
   ```bash
   git rm Sources/LoggerKit/UI/Export/ExportFeature.swift
   git rm Sources/LoggerKit/UI/Export/ExportTypes.swift
   git commit -m "回滚 ExportFeature"
   ```

2. 保留现有的导出实现，重新设计方案

3. 或者切换到其他分支继续开发
   ```bash
   git checkout -b feature/export-alternative-approach
   ```

---

## 总结

### 改造收益

1. ✅ **独立性强**: ExportFeature 完全独立，可在多个场景复用
2. ✅ **架构清晰**: 拥有完整的 State、Action、Reducer、Environment
3. ✅ **易于扩展**: 可轻松添加新的导出格式和导出场景
4. ✅ **依赖注入**: 通过 Environment 注入依赖，利于测试和维护

### 时间估算

- **前置步骤**: 30 分钟 (添加 Effect.cancel 支持)
- **第一阶段**: 3-4 小时 (创建完整 ExportFeature)
- **第二阶段**: 2-3 小时 (集成到 LogDetailFeature)
- **第三阶段**: 可选,根据需求 (2-4 小时/功能)
- **总计**: **6-8 小时** (约一个工作日)

### 设计说明

| 方面 | 设计选择 | 原因 |
|-----|---------|------|
| **架构模式** | 完整 ExportFeature | 独立可复用，支持多场景 |
| **State 设计** | 独立的 ExportFeature.State | 完全解耦，易于维护 |
| **进度更新** | 直接回调 | 简化实现，避免过度工程化 |
| **导出格式** | 仅 .log (JSON 作为扩展) | 专注核心功能 |
| **依赖管理** | Environment 注入 | 易于测试和替换实现 |

### 关键决策

1. **✅ 采用完整 ExportFeature** - 独立可复用，支持多场景使用
2. **✅ 独立 State 设计** - 与 LogDetailFeature 解耦，易于维护
3. **✅ Environment 注入** - 依赖倒置，易于测试
4. **✅ 分阶段实施** - 前置依赖 → 创建 Feature → 集成 → 扩展功能

### 风险控制

1. ✅ **Git 分支隔离**: 在独立分支上开发,可随时回滚
2. ✅ **编译验证**: 每个步骤后确保编译通过
3. ✅ **功能验证**: 集成后立即测试所有导出场景
4. ✅ **增量迁移**: 先创建 ExportFeature,再集成到 LogDetailFeature
