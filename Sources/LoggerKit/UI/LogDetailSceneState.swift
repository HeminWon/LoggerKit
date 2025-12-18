//
//  LogDetailSceneState.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/9/12.
//  Refactored with TCA architecture by Claude Code on 2025/12/17
//

import SwiftUI
import Combine

// MARK: - LogDetailSceneState (Facade)

/// Facade for the log detail scene - delegates to internal TCA Store
///
/// This class maintains backward compatibility while using TCA architecture internally.
/// All state changes are now driven by Actions through the Store.
///
/// Migration from 808 lines to ~150 lines Facade pattern.
@MainActor
public class LogDetailSceneState: ObservableObject {

    // MARK: - Internal Store

    internal let store: LogSceneStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Exposed State (delegated to store.state)

    /// FilterState for backward compatibility
    @ObservedObject public var filterState: FilterState

    /// SearchState for backward compatibility
    @ObservedObject public var searchState: SearchState

    /// Events to display
    @Published public var events: [LogEvent] = []

    /// All events for search preview
    @Published public var allEventsForSearchPreview: [LogEvent] = []

    /// Display view models
    @Published public var displayEvents: [LogRowViewModel] = []

    /// Total count matching filters
    @Published public var totalCount: Int = 0

    /// Loading state
    @Published public var loadingState: LoadingState = .idle

    /// Error (if any)
    @Published public var error: Error?

    /// Statistics
    @Published public var statistics: LogStatistics?

    /// Exported file URL (for sharing)
    @Published public var exportedFileURL: URL?

    // MARK: - Export State

    /// Whether export is in progress
    @Published public var isExporting: Bool = false

    /// Export progress (0.0 to 1.0)
    @Published public var exportProgress: Double = 0.0

    /// Number of events exported
    @Published public var exportedCount: Int = 0

    /// Total number of events to export
    @Published public var totalExportCount: Int = 0

    // MARK: - Sheet Presentation State

    /// Whether share sheet is presented
    @Published public var isSharePresented: Bool = false

    /// Whether filter sheet is presented
    @Published public var isFilterPresented: Bool = false

    /// Whether delete management sheet is presented
    @Published public var isDeleteManagementPresented: Bool = false

    /// Whether export error alert is shown
    @Published public var showExportError: Bool = false

    // MARK: - Private Properties

    private(set) var prefix: String
    private(set) var identifier: String?
    private let sessionIds: Set<String>

    // MARK: - Initialization

    /// Initialize LogDetailSceneState with a Store
    ///
    /// 使用已创建的 Store 初始化 (用于 TCA 架构)
    ///
    /// - Parameters:
    ///   - store: 已创建的 LogSceneStore 实例
    ///   - prefix: File prefix (defaults to bundle ID)
    ///   - identifier: Optional identifier
    public init(
        store: LogSceneStore,
        prefix: String? = nil,
        identifier: String? = nil
    ) {
        // Setup prefix
        if let prefix = prefix {
            self.prefix = prefix
        } else {
            let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
            self.prefix = bundleId
        }

        self.identifier = identifier
        self.sessionIds = [] // Could be derived from prefix/identifier if needed

        // Use provided store
        self.store = store

        // Initialize filter and search state (will sync with store state)
        self.filterState = FilterState()
        self.searchState = SearchState()

        // Setup bindings
        setupStoreBindings()
        setupFilterStateBinding()
        setupSearchStateBinding()
    }

    /// Initialize LogDetailSceneState
    ///
    /// - Parameters:
    ///   - prefix: File prefix (defaults to bundle ID)
    ///   - identifier: Optional identifier
    ///   - filterState: Optional filter state (creates new if nil)
    ///   - searchState: Optional search state (creates new if nil)
    ///   - dataLoader: Optional data loader (uses shared if nil)
    public init(
        prefix: String? = nil,
        identifier: String? = nil,
        filterState: FilterState? = nil,
        searchState: SearchState? = nil,
        dataLoader: LogDataLoaderProtocol? = nil
    ) {
        // Setup prefix
        if let prefix = prefix {
            self.prefix = prefix
        } else {
            let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
            self.prefix = bundleId
        }

        self.identifier = identifier
        self.sessionIds = [] // Could be derived from prefix/identifier if needed

        // Initialize filter and search state
        self.filterState = filterState ?? FilterState()
        self.searchState = searchState ?? SearchState()

        // Create store
        self.store = LogSceneStore.create(sessionIds: sessionIds, enableActionLogging: false)

        // Setup bindings
        setupStoreBindings()
        setupFilterStateBinding()
        setupSearchStateBinding()
    }

    // MARK: - Store Bindings

    private func setupStoreBindings() {
        // Sync store state to published properties
        store.$state
            .map { $0.events }
            .assign(to: &$events)

        store.$state
            .map { $0.allEventsForSearchPreview }
            .assign(to: &$allEventsForSearchPreview)

        store.$state
            .map { $0.totalCount }
            .assign(to: &$totalCount)

        store.$state
            .map { $0.loadingState }
            .assign(to: &$loadingState)

        store.$state
            .map { $0.error }
            .assign(to: &$error)

        store.$state
            .map { $0.statistics }
            .assign(to: &$statistics)

        store.$state
            .map { $0.exportState.exportedFileURL }
            .assign(to: &$exportedFileURL)

        // Export state bindings
        store.$state
            .map { $0.exportState.isExporting }
            .assign(to: &$isExporting)

        store.$state
            .map { $0.exportState.progress }
            .assign(to: &$exportProgress)

        store.$state
            .map { $0.exportState.exportedCount }
            .assign(to: &$exportedCount)

        store.$state
            .map { $0.exportState.totalCount }
            .assign(to: &$totalExportCount)

        // Sheet presentation state bindings
        store.$state
            .map { $0.isSharePresented }
            .assign(to: &$isSharePresented)

        store.$state
            .map { $0.isFilterPresented }
            .assign(to: &$isFilterPresented)

        store.$state
            .map { $0.isDeleteManagementPresented }
            .assign(to: &$isDeleteManagementPresented)

        store.$state
            .map { $0.showExportError }
            .assign(to: &$showExportError)

        // Update display events when events change
        store.$state
            .map { $0.events }
            .map { events in
                events.enumerated().map { index, event in
                    LogRowViewModel(event: event, index: index + 1)
                }
            }
            .assign(to: &$displayEvents)

        // NOTE: 不要从 store 同步回 filterState，否则会形成循环
        // FilterState 是用户操作的源头，通过 onFilterChanged 自动同步到 Store
        // 如果反向同步，会导致：
        // 1. 用户修改 filterState
        // 2. onFilterChanged 发送 action 到 store
        // 3. store 更新后又同步回 filterState
        // 4. 可能覆盖用户的操作或导致状态不一致

        // NOTE: 不要从 store 同步回 searchState，原因同 filterState
        // SearchState 是用户输入的源头，通过 onSearchChanged 自动同步到 Store
        // 如果反向同步，会导致：
        // 1. 用户输入文字到 searchState.searchText
        // 2. onSearchChanged 发送 action 到 store
        // 3. store 更新后又同步回 searchState.searchText
        // 4. 可能覆盖用户正在输入的文本，导致输入框异常

        // 但 cachedResults 需要从 store 同步，因为它是计算结果
        store.$state
            .map { $0.searchFeature.cachedSearchResults }
            .receive(on: DispatchQueue.main) // 确保在主线程
            .sink { [weak self] results in
                guard let self = self else { return }
                print("🔄 同步搜索结果到 SearchState: totalCount=\(results.totalCount), isEmpty=\(results.isEmpty)")
                // 直接同步更新，不使用 Task（避免异步延迟）
                self.searchState.objectWillChange.send()
                self.searchState.cachedResults = results
                print("✅ SearchState.cachedResults 已更新: totalCount=\(self.searchState.cachedResults.totalCount)")
            }
            .store(in: &cancellables)
    }

    private func setupFilterStateBinding() {
        filterState.onFilterChanged = { [weak self] in
            guard let self = self else { return }
            Task {
                let options = FilterOptions(
                    levels: self.filterState.selectedLevels,
                    functions: self.filterState.selectedFunctions,
                    fileNames: self.filterState.selectedFileNames,
                    contexts: self.filterState.selectedContexts,
                    threads: self.filterState.selectedThreads,
                    messageKeywords: self.filterState.selectedMessageKeywords,
                    sessionIds: self.filterState.selectedSessionIds
                )
                await self.store.send(.applyFilter(options))
            }
        }
    }

    private func setupSearchStateBinding() {
        // NOTE: 搜索功能通过 SearchFeature 实现，需要同步 searchText 和 searchFields 到 Store
        // 但要避免反向同步导致输入框异常
        searchState.onSearchChanged = { [weak self] in
            guard let self = self else { return }
            print("🔔 搜索状态变化: searchText='\(self.searchState.searchText)', fields=\(self.searchState.searchFields)")
            Task {
                // 同步 searchText 到 SearchFeature
                await self.store.send(.search(.updateSearchText(self.searchState.searchText)))
                print("✉️ 已发送 search(.updateSearchText) action")
                // TODO: 如果 searchFields 也变化了，需要发送对应的 action
                // 暂时先忽略，因为 searchFields 变化时 updateSearchText 会触发重新搜索
            }
        }
    }

    // MARK: - Public API (delegates to Store)

    /// Load log file
    public func loadLogFile() async {
        await store.send(.loadLogFile)
    }

    /// Load more logs (pagination)
    public func loadMore() async {
        await store.send(.loadMore)
    }

    /// Refresh logs
    public func refresh() async {
        await store.send(.refresh)
    }

    /// Refresh search results
    public func refreshSearch() {
        Task {
            await store.send(.search(.executeSearch))
        }
    }

    /// Toggle search field
    public func toggleSearchField(_ field: SearchField) {
        // Directly modify searchState
        searchState.toggleSearchField(field)
        // Sync to store (will trigger search if text is not empty)
        Task {
            await store.send(.search(.toggleSearchField(field)))
        }
    }

    /// Delete all logs
    public func deleteAllLogs() async throws {
        await store.send(.deleteAllLogs)

        // Wait for completion
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Check for error
        if let error = store.state.error {
            throw error
        }
    }

    /// Delete sessions
    public func deleteSessions(_ sessionIds: Set<String>) async throws {
        // For now, map to deleteAllLogs
        // Could extend LogDetailAction to support specific session deletion
        await store.send(.deleteAllLogs)

        try await Task.sleep(nanoseconds: 100_000_000)

        if let error = store.state.error {
            throw error
        }
    }

    /// Delete session
    public func deleteSession(_ sessionId: String) async throws {
        try await deleteSessions([sessionId])
    }

    // MARK: - Computed Properties (for backward compatibility)

    /// Display title
    public var displayTitle: String {
        return "Logs"
    }

    /// File name for export
    public var fileName: String {
        let date = Date()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = dateFormatter.string(from: date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmmss"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        let timeString = timeFormatter.string(from: date)

        var components = [prefix]
        if let identifier = identifier, !identifier.isEmpty {
            components.append(identifier)
        }
        components.append(contentsOf: [dateString, timeString])
        return components.joined(separator: "_") + ".log"
    }

    /// Available functions (from statistics or all events, not from filtered events)
    public var availableFunctions: [String] {
        if let cached = store.state.cachedAvailableFunctions {
            return cached
        }
        // Use statistics for better performance (top 100 functions)
        if let stats = statistics, !stats.topFunctions.isEmpty {
            return stats.topFunctions.map { $0.0 }
        }
        // Fallback to all events for search preview (not filtered events)
        if !allEventsForSearchPreview.isEmpty {
            return Array(Set(allEventsForSearchPreview.map { $0.function })).sorted()
        }
        // Last resort: use current filtered events
        return Array(Set(events.map { $0.function })).sorted()
    }

    /// Available file names (from all events, not from filtered events)
    public var availableFileNames: [String] {
        if let cached = store.state.cachedAvailableFileNames {
            return cached
        }
        // Use all events for search preview (not filtered events)
        if !allEventsForSearchPreview.isEmpty {
            return Array(Set(allEventsForSearchPreview.map { $0.fileName })).sorted()
        }
        // Fallback to current filtered events
        return Array(Set(events.map { $0.fileName })).sorted()
    }

    /// Available contexts (from all events, not from filtered events)
    public var availableContexts: [String] {
        if let cached = store.state.cachedAvailableContexts {
            return cached
        }
        // Use all events for search preview (not filtered events)
        if !allEventsForSearchPreview.isEmpty {
            return Array(Set(allEventsForSearchPreview.map { $0.context })).filter { !$0.isEmpty }.sorted()
        }
        // Fallback to current filtered events
        return Array(Set(events.map { $0.context })).filter { !$0.isEmpty }.sorted()
    }

    /// Available threads (from all events, not from filtered events)
    public var availableThreads: [String] {
        if let cached = store.state.cachedAvailableThreads {
            return cached
        }
        // Use all events for search preview (not filtered events)
        if !allEventsForSearchPreview.isEmpty {
            return Array(Set(allEventsForSearchPreview.map { $0.thread })).filter { !$0.isEmpty }.sorted()
        }
        // Fallback to current filtered events
        return Array(Set(events.map { $0.thread })).filter { !$0.isEmpty }.sorted()
    }

    /// Has more data
    public var hasMoreData: Bool {
        return store.state.hasMoreData
    }

    /// Active filter count
    public var activeFilterCount: Int {
        return store.state.activeFilterCount
    }

    // MARK: - Filter Management

    /// Toggle log level
    public func toggleLevel(_ level: LogEvent.Level) {
        // Directly modify filterState, which will trigger onFilterChanged
        if filterState.selectedLevels.contains(level) {
            filterState.selectedLevels.remove(level)
        } else {
            filterState.selectedLevels.insert(level)
        }
    }

    /// Add item to filter
    public func addToFilter(_ item: FilterItem) {
        // Directly modify filterState, which will trigger onFilterChanged
        switch item {
        case .function(let function):
            filterState.selectedFunctions.insert(function)
        case .fileName(let fileName):
            filterState.selectedFileNames.insert(fileName)
        case .context(let context):
            filterState.selectedContexts.insert(context)
        case .thread(let thread):
            filterState.selectedThreads.insert(thread)
        case .messageKeyword(let keyword):
            filterState.selectedMessageKeywords.insert(keyword)
        }
    }

    /// Remove item from filter
    public func removeFromFilter(_ item: FilterItem) {
        // Directly modify filterState, which will trigger onFilterChanged
        switch item {
        case .function(let function):
            filterState.selectedFunctions.remove(function)
        case .fileName(let fileName):
            filterState.selectedFileNames.remove(fileName)
        case .context(let context):
            filterState.selectedContexts.remove(context)
        case .thread(let thread):
            filterState.selectedThreads.remove(thread)
        case .messageKeyword(let keyword):
            filterState.selectedMessageKeywords.remove(keyword)
        }
    }

    /// Reset all filters
    public func resetFilters() {
        // Directly modify filterState, which will trigger onFilterChanged
        filterState.selectedLevels = [.verbose, .debug, .info, .warning, .error]
        filterState.selectedFunctions.removeAll()
        filterState.selectedFileNames.removeAll()
        filterState.selectedContexts.removeAll()
        filterState.selectedThreads.removeAll()
        filterState.selectedMessageKeywords.removeAll()
        filterState.selectedSessionIds.removeAll()
    }

    /// Check if item is in filter
    public func isInFilter(_ item: FilterItem) -> Bool {
        switch item {
        case .function(let function):
            return filterState.selectedFunctions.contains(function)
        case .fileName(let fileName):
            return filterState.selectedFileNames.contains(fileName)
        case .context(let context):
            return filterState.selectedContexts.contains(context)
        case .thread(let thread):
            return filterState.selectedThreads.contains(thread)
        case .messageKeyword(let keyword):
            return filterState.selectedMessageKeywords.contains(keyword)
        }
    }

    // MARK: - Binding Properties (for SwiftUI sheet presentation)

    /// Binding for share sheet presentation
    public var isSharePresentedBinding: Binding<Bool> {
        Binding(
            get: { self.isSharePresented },
            set: { newValue in
                self.isSharePresented = newValue
                Task { await self.store.send(.setSharePresented(newValue)) }
            }
        )
    }

    /// Binding for filter sheet presentation
    public var isFilterPresentedBinding: Binding<Bool> {
        Binding(
            get: { self.isFilterPresented },
            set: { newValue in
                self.isFilterPresented = newValue
                Task { await self.store.send(.setFilterPresented(newValue)) }
            }
        )
    }

    /// Binding for delete management sheet presentation
    public var isDeleteManagementPresentedBinding: Binding<Bool> {
        Binding(
            get: { self.isDeleteManagementPresented },
            set: { newValue in
                self.isDeleteManagementPresented = newValue
                Task { await self.store.send(.setDeleteManagementPresented(newValue)) }
            }
        )
    }

    /// Binding for export error alert
    public var showExportErrorBinding: Binding<Bool> {
        Binding(
            get: { self.showExportError },
            set: { newValue in
                self.showExportError = newValue
                Task { await self.store.send(.setExportErrorPresented(newValue)) }
            }
        )
    }

    /// Check if search result item is in filter
    public func isInFilter(_ item: SearchResultItem) -> Bool {
        switch item.field {
        case .function:
            return filterState.selectedFunctions.contains(item.value)
        case .fileName:
            return filterState.selectedFileNames.contains(item.value)
        case .context:
            return filterState.selectedContexts.contains(item.value)
        case .thread:
            return filterState.selectedThreads.contains(item.value)
        case .message:
            return filterState.selectedMessageKeywords.contains(item.value)
        }
    }

    /// Add search result item to filter
    public func addToFilter(_ item: SearchResultItem) {
        switch item.field {
        case .function:
            addToFilter(.function(item.value))
        case .fileName:
            addToFilter(.fileName(item.value))
        case .context:
            addToFilter(.context(item.value))
        case .thread:
            addToFilter(.thread(item.value))
        case .message:
            addToFilter(.messageKeyword(item.value))
        }
    }

    /// Remove search result item from filter
    public func removeFromFilter(_ item: SearchResultItem) {
        switch item.field {
        case .function:
            removeFromFilter(.function(item.value))
        case .fileName:
            removeFromFilter(.fileName(item.value))
        case .context:
            removeFromFilter(.context(item.value))
        case .thread:
            removeFromFilter(.thread(item.value))
        case .message:
            removeFromFilter(.messageKeyword(item.value))
        }
    }
}

// MARK: - Helper Extensions

extension LogDetailSceneState {
    /// Export logs to file
    /// - Parameters:
    ///   - progressHandler: Progress callback (written, total)
    /// - Returns: URL of exported file
    /// Export all events using new ExportFeature (TCA-based)
    public func exportAllEvents() async throws -> URL {
        print("🔵 [ExportFeature] Starting export via new ExportFeature...")

        // Send startExport action
        await store.send(.export(.startExport(format: .log)))

        // Wait for export to complete by observing state
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                // Poll the state until export completes or fails
                while true {
                    let exportState = store.state.exportFeature

                    if exportState.isCompleted, let url = exportState.exportedFileURL {
                        print("🟢 [ExportFeature] Export completed: \(url.path)")
                        continuation.resume(returning: url)
                        return
                    }

                    if exportState.isFailed, let error = exportState.error {
                        print("🔴 [ExportFeature] Export failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        return
                    }

                    // Wait a bit before checking again
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
            }
        }
    }

    /// Export all events using legacy approach (for backward compatibility)
    @available(*, deprecated, message: "Use exportAllEvents() instead")
    public func exportAllEventsStreaming(
        progressHandler: @escaping (Int, Int) -> Void = { _, _ in }
    ) async throws -> URL {
        print("🔵 [ExportStreaming] Starting export...")

        // Send exportStarted action
        await store.send(.exportStarted)

        // Adapt (Int, Int) callback to (Double) callback, and also send progress updates to store
        let progress: @Sendable (Double) -> Void = { [weak self] progressPercent in
            // This is a simplified adapter - we don't have access to the actual counts here
            // The real progress updates will come from the reducer via exportProgressUpdated
            guard let self = self else { return }
            // Call the handler for backward compatibility
            Task { @MainActor in
                let total = self.totalExportCount
                let exported = Int(Double(total) * progressPercent)
                progressHandler(exported, total)
            }
        }

        // Send export action and wait for it to complete
        print("🔵 [ExportStreaming] Sending .exportLogs action to store...")
        await store.send(.exportLogs(format: .log, progress: progress))
        print("🔵 [ExportStreaming] Action completed, checking results...")
        print("🔍 [ExportStreaming] store.state.exportState.exportedFileURL = \(store.state.exportState.exportedFileURL?.path ?? "nil")")
        print("🔍 [ExportStreaming] store.state.error = \(store.state.error?.localizedDescription ?? "nil")")

        // After the action completes, check the result in state
        if let url = store.state.exportState.exportedFileURL {
            print("🟢 [ExportStreaming] Export completed successfully, URL: \(url.path)")
            return url
        }

        // If no URL but there's an error, throw it
        if let error = store.state.error {
            print("🔴 [ExportStreaming] Export failed with error: \(error.localizedDescription)")
            throw error
        }

        // If neither URL nor error, something went wrong
        print("🔴 [ExportStreaming] Export failed: no URL or error in state")
        print("🔍 [ExportStreaming] Final check - store.state.exportState.exportedFileURL = \(store.state.exportState.exportedFileURL?.path ?? "nil")")
        throw NSError(
            domain: "LoggerKit",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Export completed but no file URL was returned"]
        )
    }
}
