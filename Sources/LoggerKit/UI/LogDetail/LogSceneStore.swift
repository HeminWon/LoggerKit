//
//  LogSceneStore.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - LogSceneStore

/// Type alias for the log detail scene store
///
/// This is a specialized Store for the log detail feature.
///
/// Example usage:
/// ```swift
/// let store = LogSceneStore(
///     sessionIds: sessionIds,
///     enableActionLogging: true  // For debugging
/// )
///
/// // Load logs
/// await store.send(.loadLogFile)
///
/// // Apply filter
/// let options = FilterOptions(...)
/// await store.send(.applyFilter(options))
/// ```
public typealias LogSceneStore = Store<LogDetailState, LogDetailAction>

// MARK: - LogSceneStore + Convenience

extension LogSceneStore {
    /// Create a LogSceneStore with default configuration
    ///
    /// - Parameters:
    ///   - sessionIds: Session IDs to filter (empty for all sessions)
    ///   - enableActionLogging: Whether to enable action logging for debugging
    /// - Returns: A configured LogSceneStore
    @MainActor
    public static func create(
        sessionIds: Set<String> = [],
        enableActionLogging: Bool = false
    ) -> LogSceneStore {
        let environment = LogDetailEnvironment.live(sessionIds: sessionIds)
        let reducer = LogDetailReducer(environment: environment)

        return LogSceneStore(
            initialState: LogDetailState(),
            reducer: AnyReducer(reducer),
            enableActionLogging: enableActionLogging
        )
    }

    /// Create a LogSceneStore for testing
    ///
    /// - Parameters:
    ///   - initialState: Initial state for testing
    ///   - environment: Mock environment
    /// - Returns: A test LogSceneStore
    @MainActor
    public static func createForTesting(
        initialState: LogDetailState = LogDetailState(),
        environment: LogDetailEnvironment
    ) -> LogSceneStore {
        let reducer = LogDetailReducer(environment: environment)

        return LogSceneStore(
            initialState: initialState,
            reducer: AnyReducer(reducer),
            enableActionLogging: true
        )
    }
}
