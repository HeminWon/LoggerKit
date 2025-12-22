//
//  LogListFeature.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// Create a type alias to avoid naming conflicts
fileprivate typealias LogListReducerProtocol = Reducer

// MARK: - LogList Feature

public struct LogList {
    // 私有初始化器，防止外部实例化
    private init() {}
}

// MARK: - State

extension LogList {
    /// LogList State
    public struct State: Equatable, Sendable {
        // MARK: - List Data

        /// Current page of events
        public var events: [LogEvent] = []

        /// Total count of events (not limited by pagination)
        public var totalCount: Int = 0

        // MARK: - Filter Context

        /// Filter state (由父层同步)
        public var filterState: FilterFeature.State = .init()

        // MARK: - Loading State

        /// Current loading state
        public var loadingState: LoadingState = .idle

        /// Error (if any)
        public var error: LogListError?

        // MARK: - Pagination

        /// Current page number (0-based)
        public var currentPage: Int = 0

        /// Page size
        public var pageSize: Int = 500

        /// Whether more data is available
        public var hasMore: Bool = true

        // MARK: - Query Control

        /// Query sequence number (incremented on each new query)
        public var querySequenceNumber: UInt64 = 0

        /// Active query sequence (used to filter out stale responses)
        public var activeQuerySequence: UInt64 = 0

        // MARK: - Computed Properties

        /// Whether list is empty
        public var isEmpty: Bool {
            events.isEmpty
        }

        /// Whether list is loading (initial or more)
        public var isLoading: Bool {
            if case .loading = loadingState { return true }
            if case .loadingMore = loadingState { return true }
            return false
        }

        /// Whether can load more
        public var canLoadMore: Bool {
            if case .loadingMore = loadingState { return false }
            return hasMore
        }

        /// Display view models (computed on demand)
        public var displayEvents: [LogRowViewModel] {
            events.enumerated().map { LogRowViewModel(event: $1, index: $0 + 1) }
        }

        // MARK: - Initializer

        public init() {}

        // MARK: - State Mutations

        /// Reset pagination to initial state
        public mutating func resetPagination() {
            currentPage = 0
            hasMore = true
            querySequenceNumber += 1
        }

        /// Clear all data
        public mutating func clear() {
            events.removeAll()
            totalCount = 0
            currentPage = 0
            hasMore = true
            loadingState = .idle
            error = nil
        }

        /// Update events (同步更新数据)
        mutating func updateEvents(_ newEvents: [LogEvent]) {
            events = newEvents
        }

        // MARK: - Equatable

        public static func == (lhs: State, rhs: State) -> Bool {
            // 使用 id 数组比较，避免深度比较但保证正确性
            lhs.events.map(\.id) == rhs.events.map(\.id) &&
            lhs.totalCount == rhs.totalCount &&
            lhs.filterState == rhs.filterState &&
            lhs.loadingState == rhs.loadingState &&
            lhs.error == rhs.error &&
            lhs.currentPage == rhs.currentPage &&
            lhs.pageSize == rhs.pageSize &&
            lhs.hasMore == rhs.hasMore &&
            lhs.querySequenceNumber == rhs.querySequenceNumber &&
            lhs.activeQuerySequence == rhs.activeQuerySequence
        }
    }
}

// MARK: - Action

extension LogList {
    /// LogList Actions
    public enum Action: Equatable {
        // MARK: - User Actions (命令型)

        /// Load log file (initial load)
        case loadLogFile

        /// Load more logs (pagination)
        case loadMore

        /// Refresh logs (reload from first page)
        case refresh

        /// Reset pagination
        case resetPagination

        /// Clear all data
        case clear

        // MARK: - System Responses (事件型)

        /// Logs loaded successfully
        case loadSucceeded(events: [LogEvent], totalCount: Int, sequenceNumber: UInt64)

        /// Loading failed
        case loadFailed(LogListError)

        // MARK: - Internal Actions

        /// Internal: Append events for pagination
        case appendEvents([LogEvent], sequenceNumber: UInt64)

        // MARK: - Equatable

        public static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.loadLogFile, .loadLogFile),
                 (.loadMore, .loadMore),
                 (.refresh, .refresh),
                 (.resetPagination, .resetPagination),
                 (.clear, .clear):
                return true

            case (.loadSucceeded(let lEvents, let lTotal, let lSeq),
                  .loadSucceeded(let rEvents, let rTotal, let rSeq)):
                return lEvents.map(\.id) == rEvents.map(\.id) && lTotal == rTotal && lSeq == rSeq

            case (.loadFailed(let lError), .loadFailed(let rError)):
                return lError == rError

            case (.appendEvents(let lEvents, let lSeq), .appendEvents(let rEvents, let rSeq)):
                return lEvents.map(\.id) == rEvents.map(\.id) && lSeq == rSeq

            default:
                return false
            }
        }
    }
}

// MARK: - Reducer

extension LogList {
    /// LogList Reducer
    public struct Reducer: LogListReducerProtocol {
        public typealias State = LogList.State
        public typealias Action = LogList.Action

        private let environment: Environment

        public init(environment: Environment) {
            self.environment = environment
        }

        public func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            // MARK: - Load Actions

            case .loadLogFile:
                return handleLoadLogFile(&state)

            case .loadMore:
                return handleLoadMore(&state)

            case .refresh:
                return handleRefresh(&state)

            // MARK: - System Responses

            case .loadSucceeded(let events, let totalCount, let sequenceNumber):
                return handleLoadSucceeded(&state, events: events, totalCount: totalCount, sequenceNumber: sequenceNumber)

            case .loadFailed(let error):
                return handleLoadFailed(&state, error: error)

            case .appendEvents(let events, let sequenceNumber):
                return handleAppendEvents(&state, events: events, sequenceNumber: sequenceNumber)

            // MARK: - State Mutations

            case .resetPagination:
                state.resetPagination()
                return .none

            case .clear:
                state.clear()
                return .none
            }
        }

        // MARK: - Private Handlers

        private func handleLoadLogFile(_ state: inout State) -> Effect<Action> {
            // Reset state
            state.loadingState = .loading(progress: nil)
            state.events = []
            state.error = nil
            state.resetPagination()

            let sequenceNumber = state.querySequenceNumber
            state.activeQuerySequence = sequenceNumber

            return loadEvents(state: state, offset: 0, sequenceNumber: sequenceNumber)
        }

        private func handleLoadMore(_ state: inout State) -> Effect<Action> {
            // Don't load if already loading or no more data
            guard state.canLoadMore else {
                return .none
            }

            // Update loading state
            state.loadingState = .loadingMore

            let nextPage = state.currentPage + 1
            let offset = nextPage * state.pageSize
            let sequenceNumber = state.querySequenceNumber

            return loadEvents(state: state, offset: offset, sequenceNumber: sequenceNumber)
        }

        private func handleRefresh(_ state: inout State) -> Effect<Action> {
            // Same as loadLogFile
            return handleLoadLogFile(&state)
        }

        private func handleLoadSucceeded(_ state: inout State, events: [LogEvent], totalCount: Int, sequenceNumber: UInt64) -> Effect<Action> {
            // Filter out stale responses
            guard sequenceNumber >= state.activeQuerySequence else {
                return .none
            }

            // Update active sequence
            state.activeQuerySequence = sequenceNumber

            // Check if loading more
            let isLoadingMore: Bool
            if case .loadingMore = state.loadingState {
                isLoadingMore = true
            } else {
                isLoadingMore = false
            }

            if isLoadingMore {
                // Append events
                return .send(.appendEvents(events, sequenceNumber: sequenceNumber))
            } else {
                // Initial load or reload
                state.updateEvents(events)
                state.totalCount = totalCount
                state.currentPage = 0
                state.hasMore = events.count < totalCount
            }

            // Update loading state
            state.loadingState = .loaded
            state.error = nil

            return .none
        }

        private func handleLoadFailed(_ state: inout State, error: LogListError) -> Effect<Action> {
            state.loadingState = .failed(error)
            state.error = error
            return .none
        }

        private func handleAppendEvents(_ state: inout State, events: [LogEvent], sequenceNumber: UInt64) -> Effect<Action> {
            // Filter out stale responses
            guard sequenceNumber >= state.activeQuerySequence else {
                return .none
            }

            // Append events
            state.events.append(contentsOf: events)
            state.currentPage += 1
            state.hasMore = state.events.count < state.totalCount

            // Update loading state
            state.loadingState = .loaded
            state.error = nil

            return .none
        }

        // MARK: - Effect Helpers

        private func loadEvents(state: State, offset: Int, sequenceNumber: UInt64) -> Effect<Action> {
            let sessionIds = environment.sessionIds
            let pageSize = state.pageSize
            let filterState = state.filterState

            return .cancellable(id: "loadLogs") { [environment] in
                do {
                    let events = try await environment.dataLoader.loadEvents(
                        sessionIds: sessionIds,
                        filterState: filterState,
                        offset: offset,
                        limit: pageSize
                    )

                    let totalCount = try await environment.dataLoader.countEvents(
                        sessionIds: sessionIds,
                        filterState: filterState
                    )

                    return .loadSucceeded(
                        events: events,
                        totalCount: totalCount,
                        sequenceNumber: sequenceNumber
                    )
                } catch {
                    // 将通用错误转换为 LogListError
                    let logError = LogListError.loadFailed(error.localizedDescription)
                    return .loadFailed(logError)
                }
            }
        }
    }
}

// MARK: - Environment

extension LogList {
    /// LogList Environment (依赖注入)
    public struct Environment {
        /// Data loader for fetching events
        let dataLoader: LogDataLoaderProtocol

        /// Session IDs to load logs for
        let sessionIds: Set<String>

        // MARK: - Live Environment

        public static func live(
            dataLoader: LogDataLoaderProtocol,
            sessionIds: Set<String>
        ) -> Environment {
            Environment(
                dataLoader: dataLoader,
                sessionIds: sessionIds
            )
        }

        // MARK: - Mock Environment (for testing)

        public static func mock(
            dataLoader: LogDataLoaderProtocol,
            sessionIds: Set<String> = ["test-session"]
        ) -> Environment {
            Environment(
                dataLoader: dataLoader,
                sessionIds: sessionIds
            )
        }
    }
}

// MARK: - Effect Extension

extension Effect where Action == LogList.Action {
    /// Send an action immediately
    static func send(_ action: Action) -> Effect<Action> {
        return .task { action }
    }
}
