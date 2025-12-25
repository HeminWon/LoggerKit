//
//  FilterFeature.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// Create a type alias to avoid naming conflicts
typealias ReducerProtocol = Reducer

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

        /// Selected log levels (默认选中所有级别)
        public var selectedLevels: Set<LogEvent.Level> = [.verbose, .debug, .info, .warning, .error]

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

        /// Selected session IDs
        public var selectedSessionIds: Set<String> = []

        // MARK: - Session Management

        /// Available sessions for filtering
        public var availableSessions: [SessionInfo] = []

        /// Loading state for sessions
        public var isLoadingSessions: Bool = false

        /// Error message for session loading failures
        public var sessionLoadingError: String?

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
            !selectedThreads.isEmpty || !selectedMessageKeywords.isEmpty ||
            !selectedSessionIds.isEmpty
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
            if !selectedSessionIds.isEmpty { count += 1 }
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
            selectedSessionIds.removeAll()
        }

        // MARK: - Equatable

        public static func == (lhs: State, rhs: State) -> Bool {
            lhs.selectedLevels == rhs.selectedLevels &&
            lhs.selectedFunctions == rhs.selectedFunctions &&
            lhs.selectedFileNames == rhs.selectedFileNames &&
            lhs.selectedContexts == rhs.selectedContexts &&
            lhs.selectedThreads == rhs.selectedThreads &&
            lhs.selectedMessageKeywords == rhs.selectedMessageKeywords &&
            lhs.selectedSessionIds == rhs.selectedSessionIds &&
            lhs.availableSessions == rhs.availableSessions &&
            lhs.isLoadingSessions == rhs.isLoadingSessions &&
            lhs.sessionLoadingError == rhs.sessionLoadingError &&
            lhs.availableFunctions == rhs.availableFunctions &&
            lhs.availableFileNames == rhs.availableFileNames &&
            lhs.availableContexts == rhs.availableContexts &&
            lhs.availableThreads == rhs.availableThreads &&
            lhs.isLoadingOptions == rhs.isLoadingOptions &&
            lhs.error?.localizedDescription == rhs.error?.localizedDescription
        }
    }
}

// MARK: - Filter Types

extension FilterFeature {
    /// 过滤器类型
    public enum FilterType: Equatable {
        case function
        case fileName
        case context
        case thread
        case messageKeyword
        case sessionId
    }

    /// 过滤器操作类型
    public enum FilterOperation: Equatable {
        case toggle(String)    // 切换：存在则删除，不存在则添加
        case add(String)       // 添加：确保添加（幂等）
        case remove(String)    // 删除：确保删除（幂等）
        case selectAll         // 全选
        case clear             // 清空
    }
}

// MARK: - Action

extension FilterFeature {
    /// Filter Actions
    public enum Action: Equatable {
        // MARK: - Generic Filter Action (通用化过滤操作)

        /// 通用过滤器更新操作
        case updateFilter(FilterType, FilterOperation)

        // MARK: - User Actions (命令型)

        /// Toggle log level filter
        case toggleLevel(LogEvent.Level)

        /// Clear all session IDs
        case clearSessionIds

        /// Reset all filters
        case resetFilters

        /// Apply current filters (user initiates filter application)
        case applyFilters

        /// Load available options (functions, file names, etc.)
        case loadAvailableOptions

        // MARK: - Session Loading

        /// Load available sessions from database
        case loadSessions

        /// Sessions loaded successfully
        case sessionsLoaded([SessionInfo])

        /// Loading sessions failed
        case loadingSessionsFailed(String)

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
            case (.updateFilter(let lt, let lo), .updateFilter(let rt, let ro)):
                return lt == rt && lo == ro
            case (.toggleLevel(let l), .toggleLevel(let r)):
                return l == r
            case (.resetFilters, .resetFilters),
                 (.applyFilters, .applyFilters),
                 (.filtersApplied, .filtersApplied),
                 (.loadAvailableOptions, .loadAvailableOptions),
                 (.clearSessionIds, .clearSessionIds),
                 (.loadSessions, .loadSessions):
                return true
            case (.sessionsLoaded(let l), .sessionsLoaded(let r)):
                return l == r
            case (.loadingSessionsFailed(let l), .loadingSessionsFailed(let r)):
                return l == r
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
    public struct Reducer: ReducerProtocol {
        public typealias State = FilterFeature.State
        public typealias Action = FilterFeature.Action

        private let environment: Environment

        public init(environment: Environment) {
            self.environment = environment
        }

        public func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            // MARK: - Generic Filter Update

            case let .updateFilter(filterType, operation):
                handleFilterUpdate(&state, filterType: filterType, operation: operation)
                return .send(.filtersApplied)

            // MARK: - Toggle Filters

            case .toggleLevel(let level):
                if state.selectedLevels.contains(level) {
                    state.selectedLevels.remove(level)
                } else {
                    state.selectedLevels.insert(level)
                }
                return .send(.filtersApplied)

            case .clearSessionIds:
                state.selectedSessionIds.removeAll()
                return .send(.filtersApplied)

            case .resetFilters:
                state.reset()
                return .send(.filtersApplied)

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

            // MARK: - Load Sessions

            case .loadSessions:
                return handleLoadSessions(&state)

            case .sessionsLoaded(let sessions):
                state.isLoadingSessions = false
                state.availableSessions = sessions
                state.sessionLoadingError = nil
                return .none

            case .loadingSessionsFailed(let errorMessage):
                state.isLoadingSessions = false
                state.sessionLoadingError = errorMessage
                return .none
            }
        }

        // MARK: - Private Handlers

        /// 处理通用过滤器更新
        private func handleFilterUpdate(_ state: inout State, filterType: FilterType, operation: FilterOperation) {
            switch (filterType, operation) {
            // MARK: - Function Filter
            case (.function, .toggle(let value)):
                if state.selectedFunctions.contains(value) {
                    state.selectedFunctions.remove(value)
                } else {
                    state.selectedFunctions.insert(value)
                }
            case (.function, .add(let value)):
                state.selectedFunctions.insert(value)  // 幂等
            case (.function, .remove(let value)):
                state.selectedFunctions.remove(value)  // 幂等
            case (.function, .selectAll):
                state.selectedFunctions = Set(state.availableFunctions)
            case (.function, .clear):
                state.selectedFunctions.removeAll()

            // MARK: - FileName Filter
            case (.fileName, .toggle(let value)):
                if state.selectedFileNames.contains(value) {
                    state.selectedFileNames.remove(value)
                } else {
                    state.selectedFileNames.insert(value)
                }
            case (.fileName, .add(let value)):
                state.selectedFileNames.insert(value)
            case (.fileName, .remove(let value)):
                state.selectedFileNames.remove(value)
            case (.fileName, .selectAll):
                state.selectedFileNames = Set(state.availableFileNames)
            case (.fileName, .clear):
                state.selectedFileNames.removeAll()

            // MARK: - Context Filter
            case (.context, .toggle(let value)):
                if state.selectedContexts.contains(value) {
                    state.selectedContexts.remove(value)
                } else {
                    state.selectedContexts.insert(value)
                }
            case (.context, .add(let value)):
                state.selectedContexts.insert(value)
            case (.context, .remove(let value)):
                state.selectedContexts.remove(value)
            case (.context, .selectAll):
                state.selectedContexts = Set(state.availableContexts)
            case (.context, .clear):
                state.selectedContexts.removeAll()

            // MARK: - Thread Filter
            case (.thread, .toggle(let value)):
                if state.selectedThreads.contains(value) {
                    state.selectedThreads.remove(value)
                } else {
                    state.selectedThreads.insert(value)
                }
            case (.thread, .add(let value)):
                state.selectedThreads.insert(value)
            case (.thread, .remove(let value)):
                state.selectedThreads.remove(value)
            case (.thread, .selectAll):
                state.selectedThreads = Set(state.availableThreads)
            case (.thread, .clear):
                state.selectedThreads.removeAll()

            // MARK: - MessageKeyword Filter
            case (.messageKeyword, .toggle(let value)):
                if state.selectedMessageKeywords.contains(value) {
                    state.selectedMessageKeywords.remove(value)
                } else {
                    state.selectedMessageKeywords.insert(value)
                }
            case (.messageKeyword, .add(let value)):
                state.selectedMessageKeywords.insert(value)
            case (.messageKeyword, .remove(let value)):
                state.selectedMessageKeywords.remove(value)
            case (.messageKeyword, .selectAll):
                // MessageKeyword 没有 available 列表，不支持 selectAll
                break
            case (.messageKeyword, .clear):
                state.selectedMessageKeywords.removeAll()

            // MARK: - SessionId Filter
            case (.sessionId, .toggle(let value)):
                if state.selectedSessionIds.contains(value) {
                    state.selectedSessionIds.remove(value)
                } else {
                    state.selectedSessionIds.insert(value)
                }
            case (.sessionId, .add(let value)):
                state.selectedSessionIds.insert(value)
            case (.sessionId, .remove(let value)):
                state.selectedSessionIds.remove(value)
            case (.sessionId, .selectAll):
                state.selectedSessionIds = Set(state.availableSessions.map { $0.id })
            case (.sessionId, .clear):
                state.selectedSessionIds.removeAll()
            }
        }

        private func handleLoadSessions(_ state: inout State) -> Effect<Action> {
            // 缓存机制: 避免重复加载
            guard state.availableSessions.isEmpty, !state.isLoadingSessions else {
                print("⚠️ [FilterFeature] Sessions already loaded or loading, skipping...")
                return .none
            }

            state.isLoadingSessions = true
            state.sessionLoadingError = nil

            return .task { [environment] in
                do {
                    print("🔵 [FilterFeature] Loading available sessions...")

                    let sessions = try await environment.databaseManager.fetchAllSessions()

                    print("🟢 [FilterFeature] Sessions loaded: \(sessions.count) sessions")

                    return .sessionsLoaded(sessions)
                } catch {
                    let errorMessage = error.localizedDescription
                    print("🔴 [FilterFeature] Failed to load sessions: \(errorMessage)")
                    return .loadingSessionsFailed(errorMessage)
                }
            }
        }

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

        /// Database manager for fetching sessions
        let databaseManager: LogDatabaseManagerProtocol

        // MARK: - Initialization

        public init(
            dataLoader: LogDataLoaderProtocol,
            databaseManager: LogDatabaseManagerProtocol
        ) {
            self.dataLoader = dataLoader
            self.databaseManager = databaseManager
        }

        // MARK: - Live Environment

        /// Create live environment with given dataLoader and databaseManager
        /// - Parameters:
        ///   - dataLoader: The data loader to use
        ///   - databaseManager: The database manager to use
        /// - Returns: Live environment
        public static func live(
            dataLoader: LogDataLoaderProtocol,
            databaseManager: LogDatabaseManagerProtocol
        ) -> Environment {
            Environment(
                dataLoader: dataLoader,
                databaseManager: databaseManager
            )
        }

        // MARK: - Mock Environment (for testing)

        public static func mock(
            dataLoader: LogDataLoaderProtocol,
            databaseManager: LogDatabaseManagerProtocol
        ) -> Environment {
            Environment(
                dataLoader: dataLoader,
                databaseManager: databaseManager
            )
        }
    }
}

// MARK: - Effect Extension

extension Effect where Action == FilterFeature.Action {
    /// Send an action immediately
    static func send(_ action: Action) -> Effect<Action> {
        return .task { action }
    }
}
