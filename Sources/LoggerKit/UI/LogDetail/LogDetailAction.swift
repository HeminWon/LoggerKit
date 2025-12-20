//
//  LogDetailAction.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - LogDetailAction

/// All possible actions in the log detail scene
///
/// Actions represent all user interactions and system responses in the TCA architecture.
/// Every state change must be triggered by an Action.
///
/// Actions are categorized into:
/// 1. User interactions (loadLogFile, loadMore, refresh, etc.)
/// 2. System responses (logsLoaded, loadingFailed, etc.)
/// 3. Sub-feature actions (filter, pagination, search, cache)
///
/// Example:
/// ```swift
/// // User taps "Load Logs"
/// await store.send(.list(.loadLogFile))
///
/// // System loads data and returns (handled by LogList Feature)
/// // .list(.loadSucceeded(events, totalCount, sequenceNumber))
/// ```
public enum LogDetailAction: Equatable {
    // MARK: - Sub-Feature Actions

    /// List feature actions (new TCA-based list)
    case list(LogList.Action)

    /// Export feature actions (new TCA-based export)
    case export(ExportFeature.Action)

    /// Filter feature actions (new TCA-based filter)
    case filter(FilterFeature.Action)

    /// Search feature actions (new TCA-based search)
    case search(SearchFeature.Action)

    /// Delete feature actions (new TCA-based delete)
    case delete(DeleteFeature.Action)

    /// Delete all logs
    case deleteAllLogs

    // MARK: - System Responses

    /// All events loaded for search preview
    case allEventsLoaded([LogEvent])

    /// Loading failed
    case loadingFailed(Error)

    /// Deletion completed
    case deletionCompleted

    /// Deletion failed
    case deletionFailed(Error)

    /// Statistics loaded
    case statisticsLoaded(LogStatistics)

    // MARK: - Filter Actions (Legacy - 待迁移到 .filter(FilterFeature.Action))
    // ✅ Removed: applyFilter, resetFilter, toggleLevel (已迁移到 FilterFeature)


    // MARK: - Pagination Actions (Legacy - 已合并到 LogList Feature)
    // ✅ Removed: nextPage, resetPagination (未使用，已迁移到 LogList Feature)

    // MARK: - Cache Actions

    /// Invalidate cache
    case invalidateCache

    /// Invalidate all events cache
    case invalidateAllEventsCache

    // MARK: - Sheet Presentation Actions

    /// Set share sheet presented
    case setSharePresented(Bool)

    /// Set filter sheet presented
    case setFilterPresented(Bool)

    /// Set delete management sheet presented
    case setDeleteManagementPresented(Bool)

    /// Set export error alert presented
    case setExportErrorPresented(Bool)

    // MARK: - Equatable

    public static func == (lhs: LogDetailAction, rhs: LogDetailAction) -> Bool {
        switch (lhs, rhs) {
        case (.deleteAllLogs, .deleteAllLogs):
            return true
        case (.allEventsLoaded(let lEvents), .allEventsLoaded(let rEvents)):
            return lEvents.count == rEvents.count
        case (.loadingFailed(let lError), .loadingFailed(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        case (.deletionCompleted, .deletionCompleted):
            return true
        case (.deletionFailed(let lError), .deletionFailed(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        case (.statisticsLoaded(let lStats), .statisticsLoaded(let rStats)):
            return lStats.totalCount == rStats.totalCount
        case (.search(let lAction), .search(let rAction)):
            return lAction == rAction
        case (.invalidateCache, .invalidateCache):
            return true
        case (.invalidateAllEventsCache, .invalidateAllEventsCache):
            return true
        case (.setSharePresented(let lValue), .setSharePresented(let rValue)):
            return lValue == rValue
        case (.setFilterPresented(let lValue), .setFilterPresented(let rValue)):
            return lValue == rValue
        case (.setDeleteManagementPresented(let lValue), .setDeleteManagementPresented(let rValue)):
            return lValue == rValue
        case (.setExportErrorPresented(let lValue), .setExportErrorPresented(let rValue)):
            return lValue == rValue
        case (.export(let lAction), .export(let rAction)):
            return lAction == rAction
        case (.filter(let lAction), .filter(let rAction)):
            return lAction == rAction
        case (.delete(let lAction), .delete(let rAction)):
            return lAction == rAction
        default:
            return false
        }
    }
}

// MARK: - Supporting Types

/// Legacy filter options (for backward compatibility)
public typealias FilterOptionsLegacy = FilterOptions

/// Filter options
public struct FilterOptions: Equatable, Sendable {
    public var levels: Set<LogEvent.Level>
    public var functions: Set<String>
    public var fileNames: Set<String>
    public var contexts: Set<String>
    public var threads: Set<String>
    public var messageKeywords: Set<String>
    public var sessionIds: Set<String>

    public init(
        levels: Set<LogEvent.Level> = [.verbose, .debug, .info, .warning, .error],
        functions: Set<String> = [],
        fileNames: Set<String> = [],
        contexts: Set<String> = [],
        threads: Set<String> = [],
        messageKeywords: Set<String> = [],
        sessionIds: Set<String> = []
    ) {
        self.levels = levels
        self.functions = functions
        self.fileNames = fileNames
        self.contexts = contexts
        self.threads = threads
        self.messageKeywords = messageKeywords
        self.sessionIds = sessionIds
    }
}

// MARK: - LogDetailAction + Sendable

extension LogDetailAction: Sendable {}
