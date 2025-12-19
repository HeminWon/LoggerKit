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

        /// Add session ID filter
        case addSessionId(String)

        /// Remove session ID filter
        case removeSessionId(String)

        /// Clear all session IDs
        case clearSessionIds

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
            case (.addSessionId(let l), .addSessionId(let r)),
                 (.removeSessionId(let l), .removeSessionId(let r)):
                return l == r
            case (.resetFilters, .resetFilters),
                 (.applyFilters, .applyFilters),
                 (.filtersApplied, .filtersApplied),
                 (.loadAvailableOptions, .loadAvailableOptions),
                 (.clearSessionIds, .clearSessionIds):
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
    public struct Reducer: ReducerProtocol {
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
                return .send(.filtersApplied)

            case .addFunction(let function):
                state.selectedFunctions.insert(function)
                return .send(.filtersApplied)

            case .removeFunction(let function):
                state.selectedFunctions.remove(function)
                return .send(.filtersApplied)

            case .addFileName(let fileName):
                state.selectedFileNames.insert(fileName)
                return .send(.filtersApplied)

            case .removeFileName(let fileName):
                state.selectedFileNames.remove(fileName)
                return .send(.filtersApplied)

            case .addContext(let context):
                state.selectedContexts.insert(context)
                return .send(.filtersApplied)

            case .removeContext(let context):
                state.selectedContexts.remove(context)
                return .send(.filtersApplied)

            case .addThread(let thread):
                state.selectedThreads.insert(thread)
                return .send(.filtersApplied)

            case .removeThread(let thread):
                state.selectedThreads.remove(thread)
                return .send(.filtersApplied)

            case .addMessageKeyword(let keyword):
                state.selectedMessageKeywords.insert(keyword)
                return .send(.filtersApplied)

            case .removeMessageKeyword(let keyword):
                state.selectedMessageKeywords.remove(keyword)
                return .send(.filtersApplied)

            case .addSessionId(let sessionId):
                state.selectedSessionIds.insert(sessionId)
                return .send(.filtersApplied)

            case .removeSessionId(let sessionId):
                state.selectedSessionIds.remove(sessionId)
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

        // MARK: - Initialization

        public init(dataLoader: LogDataLoaderProtocol) {
            self.dataLoader = dataLoader
        }

        // MARK: - Live Environment

        /// Create live environment with given dataLoader
        /// - Parameter dataLoader: The data loader to use
        /// - Returns: Live environment
        public static func live(dataLoader: LogDataLoaderProtocol) -> Environment {
            Environment(
                dataLoader: dataLoader
            )
        }

        // MARK: - Mock Environment (for testing)

        public static func mock(
            dataLoader: LogDataLoaderProtocol
        ) -> Environment {
            Environment(
                dataLoader: dataLoader
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
