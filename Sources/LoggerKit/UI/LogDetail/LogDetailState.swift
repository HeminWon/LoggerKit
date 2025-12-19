//
//  LogDetailState.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - ExportState

/// State for export operations
///
/// This struct contains all state related to log export:
/// - Progress tracking (isExporting, progress, counts)
/// - Result (exportedFileURL)
///
/// Kept separate from LoadingState to distinguish between:
/// - Loading: Reading logs from database
/// - Exporting: Writing logs to file
public struct ExportState: Equatable, Sendable {
    /// Whether export is currently in progress
    public var isExporting: Bool = false

    /// Export progress (0.0 to 1.0)
    public var progress: Double = 0.0

    /// Number of events exported so far
    public var exportedCount: Int = 0

    /// Total number of events to export
    public var totalCount: Int = 0

    /// URL of the exported file (set when export completes)
    public var exportedFileURL: URL?

    public init() {}

    public static func == (lhs: ExportState, rhs: ExportState) -> Bool {
        lhs.isExporting == rhs.isExporting &&
        lhs.progress == rhs.progress &&
        lhs.exportedCount == rhs.exportedCount &&
        lhs.totalCount == rhs.totalCount &&
        lhs.exportedFileURL == rhs.exportedFileURL
    }
}

// MARK: - LogDetailState

/// Immutable state for the log detail scene
///
/// This struct contains all UI state for the log detail view.
/// It is immutable (struct) following TCA principles:
/// - State changes only through Reducer
/// - Supports time-travel debugging
/// - Equatable for easy comparison
/// - Uses Copy-on-Write (COW) for performance
///
/// Example:
/// ```swift
/// var state = LogDetailState()
/// state.loadingState = .loading(progress: nil)
/// state.events = loadedEvents
/// ```
public struct LogDetailState: Equatable {
    // MARK: - List Feature (NEW TCA-based list functionality)

    /// List feature (new TCA-based list functionality)
    public var list: LogList.State = LogList.State()

    // MARK: - Data (将在清理阶段移除，使用 list.events 代替)

    /// Filtered and paginated events to display
    public var events: [LogEvent] = []

    /// All events for search preview (unfiltered)
    public var allEventsForSearchPreview: [LogEvent] = []

    /// Display view models (event + index + precomputed colors)
    public var displayEvents: [LogRowViewModel] = []

    /// Total count of events matching current filters (not limited by pagination)
    public var totalCount: Int = 0

    // MARK: - Loading State (将在清理阶段移除，使用 list.loadingState 代替)

    /// Current loading state
    public var loadingState: LoadingState = .idle

    /// Error (if any)
    public var error: Error?

    // MARK: - Export State

    /// Export feature (new TCA-based export functionality)
    public var exportFeature: ExportFeature.State = ExportFeature.State()

    /// Legacy export state (for backward compatibility, will be deprecated)
    public var exportState: ExportState = ExportState()

    // MARK: - Filter State

    /// Filter feature (new TCA-based filter functionality)
    public var filterFeature: FilterFeature.State = FilterFeature.State()

    // MARK: - Search State

    /// Search feature (new TCA-based search functionality)
    public var searchFeature: SearchFeature.State = SearchFeature.State()

    // MARK: - Delete State

    /// Delete feature (new TCA-based delete functionality)
    public var deleteFeature: DeleteFeature.State = DeleteFeature.State()

    // MARK: - Sheet Presentation State

    /// Whether share sheet is presented
    public var isSharePresented: Bool = false

    /// Whether filter sheet is presented
    public var isFilterPresented: Bool = false

    /// Whether delete management sheet is presented
    public var isDeleteManagementPresented: Bool = false

    /// Whether export error alert is shown
    public var showExportError: Bool = false

    // MARK: - Pagination

    /// Current page number
    public var currentPage: Int = 0

    /// Page size
    public var pageSize: Int = 500

    /// Whether more data is available
    public var hasMoreData: Bool = true

    // MARK: - Filter State

    /// Selected log levels
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

    // MARK: - Statistics

    /// Log statistics
    public var statistics: LogStatistics?

    // MARK: - Cache State

    /// Cached available functions
    public var cachedAvailableFunctions: [String]?

    /// Cached available file names
    public var cachedAvailableFileNames: [String]?

    /// Cached available contexts
    public var cachedAvailableContexts: [String]?

    /// Cached available threads
    public var cachedAvailableThreads: [String]?

    /// Cached function counts
    public var cachedFunctionCounts: [String: Int]?

    /// Cached file name counts
    public var cachedFileNameCounts: [String: Int]?

    /// Cached context counts
    public var cachedContextCounts: [String: Int]?

    /// Cached thread counts
    public var cachedThreadCounts: [String: Int]?

    // MARK: - Query Control

    /// Query sequence number (for tracking latest request)
    public var querySequenceNumber: UInt64 = 0

    /// Active query sequence number
    public var activeQuerySequence: UInt64 = 0

    // MARK: - Initialization

    public init() {}

    // MARK: - Equatable

    public static func == (lhs: LogDetailState, rhs: LogDetailState) -> Bool {
        // Compare all fields (including cachedSearchResults - critical for search UI updates!)
        return lhs.list == rhs.list &&  // ✅ 新增：LogList Feature 比较
            lhs.events.count == rhs.events.count &&
            lhs.allEventsForSearchPreview.count == rhs.allEventsForSearchPreview.count &&
            lhs.displayEvents.count == rhs.displayEvents.count &&
            lhs.totalCount == rhs.totalCount &&
            lhs.loadingState == rhs.loadingState &&
            lhs.error?.localizedDescription == rhs.error?.localizedDescription &&
            lhs.exportFeature == rhs.exportFeature &&  // ✅ 新增：ExportFeature 比较
            lhs.exportState == rhs.exportState &&  // ✅ 保留：向后兼容
            lhs.filterFeature == rhs.filterFeature &&  // ✅ 新增：FilterFeature 比较
            lhs.searchFeature == rhs.searchFeature &&  // ✅ 新增：SearchFeature 比较
            lhs.deleteFeature == rhs.deleteFeature &&  // ✅ 新增：DeleteFeature 比较
            lhs.isSharePresented == rhs.isSharePresented &&
            lhs.isFilterPresented == rhs.isFilterPresented &&
            lhs.isDeleteManagementPresented == rhs.isDeleteManagementPresented &&
            lhs.showExportError == rhs.showExportError &&
            lhs.currentPage == rhs.currentPage &&
            lhs.pageSize == rhs.pageSize &&
            lhs.hasMoreData == rhs.hasMoreData &&
            lhs.selectedLevels == rhs.selectedLevels &&
            lhs.selectedFunctions == rhs.selectedFunctions &&
            lhs.selectedFileNames == rhs.selectedFileNames &&
            lhs.selectedContexts == rhs.selectedContexts &&
            lhs.selectedThreads == rhs.selectedThreads &&
            lhs.selectedMessageKeywords == rhs.selectedMessageKeywords &&
            lhs.selectedSessionIds == rhs.selectedSessionIds &&
            lhs.querySequenceNumber == rhs.querySequenceNumber &&
            lhs.activeQuerySequence == rhs.activeQuerySequence
    }

    // MARK: - Computed Properties

    /// Active filter count
    public var activeFilterCount: Int {
        var count = 0
        if !selectedFunctions.isEmpty { count += 1 }
        if !selectedFileNames.isEmpty { count += 1 }
        if !selectedContexts.isEmpty { count += 1 }
        if !selectedThreads.isEmpty { count += 1 }
        if !selectedMessageKeywords.isEmpty { count += 1 }
        if !selectedSessionIds.isEmpty { count += 1 }
        return count
    }

    /// Whether search is active
    public var isSearchActive: Bool {
        searchFeature.isSearchActive
    }

    // MARK: - Helper Methods

    /// Invalidate all caches
    public mutating func invalidateAllCaches() {
        cachedAvailableFunctions = nil
        cachedAvailableFileNames = nil
        cachedAvailableContexts = nil
        cachedAvailableThreads = nil
        cachedFunctionCounts = nil
        cachedFileNameCounts = nil
        cachedContextCounts = nil
        cachedThreadCounts = nil
    }

    /// Reset pagination
    public mutating func resetPagination() {
        currentPage = 0
        hasMoreData = true
    }

    /// Reset filters
    public mutating func resetFilters() {
        selectedLevels = [.verbose, .debug, .info, .warning, .error]
        selectedFunctions = []
        selectedFileNames = []
        selectedContexts = []
        selectedThreads = []
        selectedMessageKeywords = []
        selectedSessionIds = []
    }

    /// Reset search
    public mutating func resetSearch() {
        searchFeature = SearchFeature.State()
    }
}

// MARK: - LogDetailState + Sendable

extension LogDetailState: Sendable {}
