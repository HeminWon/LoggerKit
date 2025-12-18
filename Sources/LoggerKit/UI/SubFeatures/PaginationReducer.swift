//
//  PaginationReducer.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - PaginationReducer

/// Reducer for handling pagination-related actions
///
/// This reducer manages:
/// - Loading more pages
/// - Resetting pagination
/// - Tracking current page and hasMoreData
public struct PaginationReducer: Reducer {
    public typealias State = LogDetailState
    public typealias Action = LogDetailAction

    private let environment: LogDetailEnvironment

    public init(environment: LogDetailEnvironment) {
        self.environment = environment
    }

    public func reduce(_ state: inout LogDetailState, _ action: LogDetailAction) -> Effect<LogDetailAction> {
        switch action {
        case .loadMore:
            // Don't load if already loading or no more data
            guard state.loadingState != .loadingMore else {
                return .none
            }

            guard state.hasMoreData else {
                return .none
            }

            // Update loading state
            state.loadingState = .loadingMore

            // Increment page
            let nextPage = state.currentPage + 1
            let offset = nextPage * state.pageSize
            let sequenceNumber = state.querySequenceNumber + 1

            // Capture values
            let sessionIds = environment.sessionIds
            let pageSize = state.pageSize
            let totalCount = state.totalCount  // Capture totalCount
            let levels = state.selectedLevels
            let functions = state.selectedFunctions
            let fileNames = state.selectedFileNames
            let contexts = state.selectedContexts
            let threads = state.selectedThreads
            let messageKeywords = state.selectedMessageKeywords
            let sessionIdFilters = state.selectedSessionIds

            // Load more events
            return .cancellable(id: "loadMore") { [environment] in
                do {
                    let filterState = await MainActor.run {
                        let fs = FilterState()
                        fs.selectedLevels = levels
                        fs.selectedFunctions = functions
                        fs.selectedFileNames = fileNames
                        fs.selectedContexts = contexts
                        fs.selectedThreads = threads
                        fs.selectedMessageKeywords = messageKeywords
                        fs.selectedSessionIds = sessionIdFilters
                        return fs
                    }

                    let newEvents = try await environment.dataLoader.loadEvents(
                        sessionIds: sessionIds,
                        filterState: filterState,
                        offset: offset,
                        limit: pageSize
                    )

                    // Check if we've reached the end
                    let hasMore = newEvents.count >= pageSize

                    // Append events to existing ones
                    return .logsLoaded(
                        events: newEvents,
                        totalCount: totalCount, // Keep existing total
                        sequenceNumber: sequenceNumber
                    )
                } catch {
                    return .loadingFailed(error)
                }
            }

        case .nextPage:
            // Same as loadMore for now
            return reduce(&state, .loadMore)

        case .resetPagination:
            state.resetPagination()
            return .none

        case .logsLoaded(let events, let totalCount, let sequenceNumber):
            // Only process if this is the latest query
            guard sequenceNumber >= state.activeQuerySequence else {
                return .none
            }

            // Update active sequence
            state.querySequenceNumber = sequenceNumber
            state.activeQuerySequence = sequenceNumber

            // If loading more, append events
            if state.loadingState == .loadingMore {
                state.events.append(contentsOf: events)
                state.currentPage += 1
                state.hasMoreData = events.count >= state.pageSize
            } else {
                // Initial load or reload
                state.events = events
                state.currentPage = 0
                state.hasMoreData = events.count >= state.pageSize
                state.totalCount = totalCount
            }

            // Update loading state
            state.loadingState = .loaded

            // Clear error
            state.error = nil

            return .none

        default:
            return .none
        }
    }

    // MARK: - Private Helpers

}
