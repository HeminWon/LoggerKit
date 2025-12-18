//
//  FilterReducer.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - FilterReducer

/// Reducer for handling filter-related actions
///
/// This reducer manages all filter state changes including:
/// - Applying/resetting filters
/// - Toggling log levels
/// - Adding/removing filter criteria
///
/// When filters change, it triggers a data reload with cancellation
/// of any pending queries.
public struct FilterReducer: Reducer {
    public typealias State = LogDetailState
    public typealias Action = LogDetailAction

    private let environment: LogDetailEnvironment

    public init(environment: LogDetailEnvironment) {
        self.environment = environment
    }

    public func reduce(_ state: inout LogDetailState, _ action: LogDetailAction) -> Effect<LogDetailAction> {
        switch action {
        case .applyFilter(let options):
            // Apply all filter options
            state.selectedLevels = options.levels
            state.selectedFunctions = options.functions
            state.selectedFileNames = options.fileNames
            state.selectedContexts = options.contexts
            state.selectedThreads = options.threads
            state.selectedMessageKeywords = options.messageKeywords
            state.selectedSessionIds = options.sessionIds

            // Reset pagination and trigger reload
            state.resetPagination()
            state.invalidateAllCaches()

            return reloadData(state: state)

        case .resetFilter:
            // Reset all filters to default
            state.resetFilters()
            state.resetPagination()
            state.invalidateAllCaches()

            return reloadData(state: state)

        case .toggleLevel(let level):
            // Toggle log level
            if state.selectedLevels.contains(level) {
                state.selectedLevels.remove(level)
            } else {
                state.selectedLevels.insert(level)
            }

            state.resetPagination()
            state.invalidateAllCaches()

            return reloadData(state: state)

        case .addFunctionFilter(let function):
            state.selectedFunctions.insert(function)
            state.resetPagination()
            state.invalidateAllCaches()
            return reloadData(state: state)

        case .removeFunctionFilter(let function):
            state.selectedFunctions.remove(function)
            state.resetPagination()
            state.invalidateAllCaches()
            return reloadData(state: state)

        case .addFileNameFilter(let fileName):
            state.selectedFileNames.insert(fileName)
            state.resetPagination()
            state.invalidateAllCaches()
            return reloadData(state: state)

        case .removeFileNameFilter(let fileName):
            state.selectedFileNames.remove(fileName)
            state.resetPagination()
            state.invalidateAllCaches()
            return reloadData(state: state)

        case .addContextFilter(let context):
            state.selectedContexts.insert(context)
            state.resetPagination()
            state.invalidateAllCaches()
            return reloadData(state: state)

        case .removeContextFilter(let context):
            state.selectedContexts.remove(context)
            state.resetPagination()
            state.invalidateAllCaches()
            return reloadData(state: state)

        case .addThreadFilter(let thread):
            state.selectedThreads.insert(thread)
            state.resetPagination()
            state.invalidateAllCaches()
            return reloadData(state: state)

        case .removeThreadFilter(let thread):
            state.selectedThreads.remove(thread)
            state.resetPagination()
            state.invalidateAllCaches()
            return reloadData(state: state)

        case .addMessageKeywordFilter(let keyword):
            state.selectedMessageKeywords.insert(keyword)
            state.resetPagination()
            state.invalidateAllCaches()
            return reloadData(state: state)

        case .removeMessageKeywordFilter(let keyword):
            state.selectedMessageKeywords.remove(keyword)
            state.resetPagination()
            state.invalidateAllCaches()
            return reloadData(state: state)

        default:
            // Not handled by this reducer
            return .none
        }
    }

    // MARK: - Private Helpers

    private func reloadData(state: LogDetailState) -> Effect<LogDetailAction> {
        let sequenceNumber = state.querySequenceNumber + 1

        // Capture filter values to avoid main actor issues
        let sessionIds = environment.sessionIds
        let levels = state.selectedLevels
        let functions = state.selectedFunctions
        let fileNames = state.selectedFileNames
        let contexts = state.selectedContexts
        let threads = state.selectedThreads
        let messageKeywords = state.selectedMessageKeywords
        let sessionIdFilters = state.selectedSessionIds

        let pageSize = state.pageSize

        // Use cancellable effect to cancel previous queries
        return .cancellable(id: "loadLogs") { [environment] in
            do {
                // Create filter state on main actor
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

                // Load events
                let events = try await environment.dataLoader.loadEvents(
                    sessionIds: sessionIds,
                    filterState: filterState,
                    offset: 0,
                    limit: pageSize
                )

                // Count total
                let totalCount = try await environment.dataLoader.countEvents(
                    sessionIds: sessionIds,
                    filterState: filterState
                )

                return .logsLoaded(events: events, totalCount: totalCount, sequenceNumber: sequenceNumber)
            } catch {
                return .loadingFailed(error)
            }
        }
    }

}
