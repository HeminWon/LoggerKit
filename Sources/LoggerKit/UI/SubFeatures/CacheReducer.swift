//
//  CacheReducer.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - CacheReducer

/// Reducer for handling cache-related actions
///
/// This reducer manages:
/// - Cache invalidation
/// - Cache updates when data changes
public struct CacheReducer: Reducer {
    public typealias State = LogDetailState
    public typealias Action = LogDetailAction

    public init() {}

    public func reduce(_ state: inout LogDetailState, _ action: LogDetailAction) -> Effect<LogDetailAction> {
        switch action {
        case .invalidateCache:
            state.invalidateAllCaches()
            return .none

        case .invalidateAllEventsCache:
            // Clear all events cache specifically
            state.allEventsForSearchPreview = []
            return .none

        case .list(.loadSucceeded):
            // When new logs are loaded, invalidate caches
            state.invalidateAllCaches()
            return .none

        default:
            return .none
        }
    }
}
