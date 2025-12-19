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
/// await store.send(.loadLogFile)
///
/// // System loads data and returns
/// await store.send(.logsLoaded(events))
/// ```
public enum LogDetailAction: Equatable {
    // MARK: - User Interactions (Legacy Actions - 待迁移到新 Feature)

    /// Load log file (initial load)
    /// ⚠️ TODO: 迁移到 .list(.loadLogFile)
    case loadLogFile

    /// Load more logs (pagination)
    /// ⚠️ TODO: 迁移到 .list(.loadMore)
    case loadMore

    /// Refresh logs
    /// ⚠️ TODO: 迁移到 .list(.refresh)
    case refresh

    /// Export logs (legacy, for backward compatibility)
    /// ⚠️ TODO: 迁移到 .export(.export)
    case exportLogs(format: ExportFormat, progress: @Sendable (Double) -> Void)

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

    // MARK: - System Responses (Legacy Actions - 待迁移到新 Feature)

    /// Logs loaded successfully
    /// ⚠️ TODO: 迁移到 .list(.loadSucceeded)
    case logsLoaded(events: [LogEvent], totalCount: Int, sequenceNumber: UInt64)

    // MARK: - Export Progress Actions

    /// Export started
    case exportStarted

    /// Export progress updated
    case exportProgressUpdated(exported: Int, total: Int)

    /// All events loaded for search preview
    case allEventsLoaded([LogEvent])

    /// Loading failed
    case loadingFailed(Error)

    /// Export completed
    case exportCompleted(URL)

    /// Export failed
    case exportFailed(Error)

    /// Deletion completed
    case deletionCompleted

    /// Deletion failed
    case deletionFailed(Error)

    /// Statistics loaded
    case statisticsLoaded(LogStatistics)

    // MARK: - Filter Actions (Legacy - 待迁移到 .filter(FilterFeature.Action))

    /// Apply filter
    /// ⚠️ TODO: 迁移到 .filter(.applyFilters)
    case applyFilter(FilterOptionsLegacy)

    /// Reset filter
    /// ⚠️ TODO: 迁移到 .filter(.resetFilters)
    case resetFilter

    /// Toggle log level
    /// ⚠️ TODO: 迁移到 .filter(.toggleLevel)
    case toggleLevel(LogEvent.Level)

    /// Add function filter
    /// ⚠️ TODO: 迁移到 .filter(.toggleFunction)
    case addFunctionFilter(String)

    /// Remove function filter
    /// ⚠️ TODO: 迁移到 .filter(.toggleFunction)
    case removeFunctionFilter(String)

    /// Add file name filter
    /// ⚠️ TODO: 迁移到 .filter(.toggleFileName)
    case addFileNameFilter(String)

    /// Remove file name filter
    /// ⚠️ TODO: 迁移到 .filter(.toggleFileName)
    case removeFileNameFilter(String)

    /// Add context filter
    /// ⚠️ TODO: 迁移到 .filter(.toggleContext)
    case addContextFilter(String)

    /// Remove context filter
    /// ⚠️ TODO: 迁移到 .filter(.toggleContext)
    case removeContextFilter(String)

    /// Add thread filter
    /// ⚠️ TODO: 迁移到 .filter(.toggleThread)
    case addThreadFilter(String)

    /// Remove thread filter
    /// ⚠️ TODO: 迁移到 .filter(.toggleThread)
    case removeThreadFilter(String)

    /// Add message keyword filter
    /// ⚠️ TODO: 迁移到 .filter(.toggleMessageKeyword)
    case addMessageKeywordFilter(String)

    /// Remove message keyword filter
    /// ⚠️ TODO: 迁移到 .filter(.toggleMessageKeyword)
    case removeMessageKeywordFilter(String)

    // MARK: - Pagination Actions (Legacy - 已合并到 LogList Feature)

    /// Next page
    /// ⚠️ TODO: 迁移到 .list(.loadMore)
    case nextPage

    /// Reset pagination
    /// ⚠️ TODO: 使用 state.list.resetPagination() 或 .list(.reset)
    case resetPagination

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
        case (.loadLogFile, .loadLogFile):
            return true
        case (.loadMore, .loadMore):
            return true
        case (.refresh, .refresh):
            return true
        case (.deleteAllLogs, .deleteAllLogs):
            return true
        case (.logsLoaded(let lEvents, let lTotal, let lSeq), .logsLoaded(let rEvents, let rTotal, let rSeq)):
            return lEvents.count == rEvents.count && lTotal == rTotal && lSeq == rSeq
        case (.exportStarted, .exportStarted):
            return true
        case (.exportProgressUpdated(let lExported, let lTotal), .exportProgressUpdated(let rExported, let rTotal)):
            return lExported == rExported && lTotal == rTotal
        case (.allEventsLoaded(let lEvents), .allEventsLoaded(let rEvents)):
            return lEvents.count == rEvents.count
        case (.loadingFailed(let lError), .loadingFailed(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        case (.exportCompleted(let lURL), .exportCompleted(let rURL)):
            return lURL == rURL
        case (.exportFailed(let lError), .exportFailed(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        case (.deletionCompleted, .deletionCompleted):
            return true
        case (.deletionFailed(let lError), .deletionFailed(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        case (.statisticsLoaded(let lStats), .statisticsLoaded(let rStats)):
            return lStats.totalCount == rStats.totalCount
        case (.applyFilter(let lOptions), .applyFilter(let rOptions)):
            return lOptions == rOptions
        case (.resetFilter, .resetFilter):
            return true
        case (.toggleLevel(let lLevel), .toggleLevel(let rLevel)):
            return lLevel == rLevel
        case (.addFunctionFilter(let lFunc), .addFunctionFilter(let rFunc)):
            return lFunc == rFunc
        case (.removeFunctionFilter(let lFunc), .removeFunctionFilter(let rFunc)):
            return lFunc == rFunc
        case (.addFileNameFilter(let lFile), .addFileNameFilter(let rFile)):
            return lFile == rFile
        case (.removeFileNameFilter(let lFile), .removeFileNameFilter(let rFile)):
            return lFile == rFile
        case (.addContextFilter(let lCtx), .addContextFilter(let rCtx)):
            return lCtx == rCtx
        case (.removeContextFilter(let lCtx), .removeContextFilter(let rCtx)):
            return lCtx == rCtx
        case (.addThreadFilter(let lThread), .addThreadFilter(let rThread)):
            return lThread == rThread
        case (.removeThreadFilter(let lThread), .removeThreadFilter(let rThread)):
            return lThread == rThread
        case (.addMessageKeywordFilter(let lKeyword), .addMessageKeywordFilter(let rKeyword)):
            return lKeyword == rKeyword
        case (.removeMessageKeywordFilter(let lKeyword), .removeMessageKeywordFilter(let rKeyword)):
            return lKeyword == rKeyword
        case (.search(let lAction), .search(let rAction)):
            return lAction == rAction
        case (.nextPage, .nextPage):
            return true
        case (.resetPagination, .resetPagination):
            return true
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
        case (.exportLogs, .exportLogs):
            // Progress closures can't be compared
            return true
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
