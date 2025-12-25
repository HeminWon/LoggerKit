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
/// await store.send(.list(.loadLogFile))
///
/// // Apply filter
/// await store.send(.filter(.applyFilters))
/// ```
public typealias LogSceneStore = Store<LogDetailState, LogDetailAction>

// MARK: - LogSceneStore + Convenience

extension LogSceneStore {
    /// Create a LogSceneStore with default configuration
    ///
    /// - Parameters:
    ///   - sessionIds: Session IDs to filter (empty for all sessions)
    ///   - enableActionLogging: Whether to enable action logging for debugging
    ///   - bundleId: Bundle ID for export file naming (optional)
    ///   - exportIdentifier: Custom identifier for export file naming (optional)
    /// - Returns: A configured LogSceneStore
    @MainActor
    public static func create(
        sessionIds: Set<String> = [],
        enableActionLogging: Bool = false,
        bundleId: String? = nil,
        exportIdentifier: String? = nil
    ) -> LogSceneStore {
        let environment = LogDetailEnvironment.live(sessionIds: sessionIds)
        let reducer = LogDetailReducer(environment: environment)

        var initialState = LogDetailState()
        initialState.exportFeature.bundleId = bundleId
        initialState.exportFeature.exportIdentifier = exportIdentifier

        return LogSceneStore(
            initialState: initialState,
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
