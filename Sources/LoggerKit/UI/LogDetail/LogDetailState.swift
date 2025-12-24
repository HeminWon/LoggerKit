//
//  LogDetailState.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

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

    // MARK: - Data (计算属性，代理到 list)

    /// Filtered and paginated events to display
    /// 代理到 list.events，保持单一数据源
    public var events: [LogEvent] {
        get { list.events }
        set { list.events = newValue }
    }

    /// All events for search preview (unfiltered)
    public var allEventsForSearchPreview: [LogEvent] = []

    /// Display view models (event + index + precomputed colors)
    public var displayEvents: [LogRowViewModel] = []

    /// Total count of events matching current filters (not limited by pagination)
    /// 代理到 list.totalCount，保持单一数据源
    public var totalCount: Int {
        get { list.totalCount }
        set { list.totalCount = newValue }
    }

    // MARK: - Loading State (计算属性，代理到 list.loadingState)

    /// Current loading state
    /// 代理到 list.loadingState，保持单一数据源
    public var loadingState: LoadingState {
        get { list.loadingState }
        set { list.loadingState = newValue }
    }

    /// Error (if any)
    public var error: Error?

    // MARK: - Export State

    /// Export feature (new TCA-based export functionality)
    public var exportFeature: ExportFeature.State = ExportFeature.State()

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

    // MARK: - Pagination (计算属性，代理到 list)

    /// Current page number
    /// 代理到 list.currentPage，保持单一数据源
    public var currentPage: Int {
        get { list.currentPage }
        set { list.currentPage = newValue }
    }

    /// Page size
    /// 代理到 list.pageSize，保持单一数据源
    public var pageSize: Int {
        get { list.pageSize }
        set { list.pageSize = newValue }
    }

    /// Whether more data is available
    /// 代理到 list.hasMore，保持单一数据源
    public var hasMoreData: Bool {
        get { list.hasMore }
        set { list.hasMore = newValue }
    }

    // MARK: - Filter State (计算属性，代理到 filterFeature)

    /// Selected log levels
    /// 代理到 filterFeature.selectedLevels，保持单一数据源
    public var selectedLevels: Set<LogEvent.Level> {
        get { filterFeature.selectedLevels }
        set { filterFeature.selectedLevels = newValue }
    }

    /// Selected functions
    /// 代理到 filterFeature.selectedFunctions，保持单一数据源
    public var selectedFunctions: Set<String> {
        get { filterFeature.selectedFunctions }
        set { filterFeature.selectedFunctions = newValue }
    }

    /// Selected file names
    /// 代理到 filterFeature.selectedFileNames，保持单一数据源
    public var selectedFileNames: Set<String> {
        get { filterFeature.selectedFileNames }
        set { filterFeature.selectedFileNames = newValue }
    }

    /// Selected contexts
    /// 代理到 filterFeature.selectedContexts，保持单一数据源
    public var selectedContexts: Set<String> {
        get { filterFeature.selectedContexts }
        set { filterFeature.selectedContexts = newValue }
    }

    /// Selected threads
    /// 代理到 filterFeature.selectedThreads，保持单一数据源
    public var selectedThreads: Set<String> {
        get { filterFeature.selectedThreads }
        set { filterFeature.selectedThreads = newValue }
    }

    /// Selected message keywords
    /// 代理到 filterFeature.selectedMessageKeywords，保持单一数据源
    public var selectedMessageKeywords: Set<String> {
        get { filterFeature.selectedMessageKeywords }
        set { filterFeature.selectedMessageKeywords = newValue }
    }

    /// Selected session IDs
    /// 代理到 filterFeature.selectedSessionIds，保持单一数据源
    public var selectedSessionIds: Set<String> {
        get { filterFeature.selectedSessionIds }
        set { filterFeature.selectedSessionIds = newValue }
    }

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
        // ✅ 优化：只比较子 Feature，不再比较重复的计算属性
        // 重复字段（events, totalCount, loadingState, currentPage, pageSize, hasMoreData,
        // selectedLevels, selectedFunctions 等）已通过子 Feature 的比较自动覆盖
        return lhs.list == rhs.list &&  // 包含: events, totalCount, loadingState, currentPage, pageSize, hasMoreData
            lhs.allEventsForSearchPreview.count == rhs.allEventsForSearchPreview.count &&
            lhs.displayEvents.count == rhs.displayEvents.count &&
            lhs.error?.localizedDescription == rhs.error?.localizedDescription &&
            lhs.exportFeature == rhs.exportFeature &&
            lhs.filterFeature == rhs.filterFeature &&  // 包含: selectedLevels, selectedFunctions, selectedFileNames, 等所有筛选字段
            lhs.searchFeature == rhs.searchFeature &&
            lhs.deleteFeature == rhs.deleteFeature &&
            lhs.isSharePresented == rhs.isSharePresented &&
            lhs.isFilterPresented == rhs.isFilterPresented &&
            lhs.isDeleteManagementPresented == rhs.isDeleteManagementPresented &&
            lhs.showExportError == rhs.showExportError &&
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
        !searchFeature.searchText.isEmpty && searchFeature.searchPhase != .idle
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
    /// 代理到 list，保持单一数据源
    public mutating func resetPagination() {
        list.currentPage = 0
        list.hasMore = true
    }

    /// Reset filters
    /// 代理到 filterFeature，保持单一数据源
    public mutating func resetFilters() {
        filterFeature.selectedLevels = [.verbose, .debug, .info, .warning, .error]
        filterFeature.selectedFunctions = []
        filterFeature.selectedFileNames = []
        filterFeature.selectedContexts = []
        filterFeature.selectedThreads = []
        filterFeature.selectedMessageKeywords = []
        filterFeature.selectedSessionIds = []
    }

    /// Reset search
    public mutating func resetSearch() {
        searchFeature = SearchFeature.State()
    }
}

// MARK: - LogDetailState + Sendable

extension LogDetailState: Sendable {}
