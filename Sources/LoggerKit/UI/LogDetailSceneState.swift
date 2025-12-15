//
//  LogDetailSceneState.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/9/12.
//

import SwiftUI
import Combine

// MARK: - 搜索字段枚举
/// 搜索字段枚举
public enum SearchField: String, CaseIterable, Identifiable {
    case message = "message"
    case fileName = "fileName"
    case function = "function"
    case context = "context"
    case thread = "thread"

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .message:
            return String(localized: "search_field_message", bundle: .module)
        case .fileName:
            return String(localized: "search_field_file", bundle: .module)
        case .function:
            return String(localized: "search_field_function", bundle: .module)
        case .context:
            return String(localized: "search_field_context", bundle: .module)
        case .thread:
            return String(localized: "search_field_thread", bundle: .module)
        }
    }

    public var icon: String {
        switch self {
        case .message: return "text.bubble"
        case .fileName: return "doc"
        case .function: return "function"
        case .context: return "square.stack.3d.up"
        case .thread: return "arrow.triangle.branch"
        }
    }
}

// MARK: - 搜索结果项
/// 搜索结果项
public struct SearchResultItem: Identifiable {
    public let id = UUID()
    public let field: SearchField
    public let value: String
    public let matchCount: Int

    public init(field: SearchField, value: String, matchCount: Int) {
        self.field = field
        self.value = value
        self.matchCount = matchCount
    }
}

// MARK: - 分类搜索结果
/// 分类搜索结果
public struct CategorizedSearchResults {
    public var message: [SearchResultItem] = []
    public var fileName: [SearchResultItem] = []
    public var function: [SearchResultItem] = []
    public var context: [SearchResultItem] = []
    public var thread: [SearchResultItem] = []

    public var totalCount: Int {
        message.count + fileName.count + function.count + context.count + thread.count
    }

    public var isEmpty: Bool {
        totalCount == 0
    }

    public init() {}
}

@MainActor
public class LogDetailSceneState: ObservableObject {

    // MARK: - FilterState 集成
    @ObservedObject public var filterState: FilterState

    // MARK: - SearchState 集成
    @ObservedObject public var searchState: SearchState

    // MARK: - DataLoader 集成
    private let dataLoader: LogDataLoaderProtocol

    @Published var events: [LogEvent] = [] {
        didSet {
            invalidateCache()
        }
    }
    @Published var displayEvents: [LogEvent] = []
    @Published var loadingState: LoadingState = .idle
    @Published var error: Error?

    // MARK: - 分页
    private var currentPage = 0
    private let pageSize = 500
    private var hasMoreData = true  // 是否还有更多数据

    // MARK: - 加载控制
    private var loadTask: Task<Void, Never>?

    // MARK: - 统计信息
    @Published var statistics: LogStatistics?

    // MARK: - 缓存管理器
    private let cache = FilterOptionsCache()

    /// 清除所有缓存
    private func invalidateCache() {
        cache.invalidateAll()
    }

    // MARK: - 可选项列表（从日志数据中提取，带缓存）
    var availableFunctions: [String] {
        if let cached = cache.functions() {
            return cached
        }
        let result = Array(Set(events.map { $0.function })).sorted()
        cache.setFunctions(result)
        return result
    }

    var availableFileNames: [String] {
        if let cached = cache.fileNames() {
            return cached
        }
        let result = Array(Set(events.map { $0.fileName })).sorted()
        cache.setFileNames(result)
        return result
    }

    var availableContexts: [String] {
        if let cached = cache.contexts() {
            return cached
        }
        let result = Array(Set(events.map { $0.context })).filter { !$0.isEmpty }.sorted()
        cache.setContexts(result)
        return result
    }

    var availableThreads: [String] {
        if let cached = cache.threads() {
            return cached
        }
        let result = Array(Set(events.map { $0.thread })).filter { !$0.isEmpty }.sorted()
        cache.setThreads(result)
        return result
    }

    // MARK: - 计数缓存
    private var functionCounts: [String: Int] {
        if let cached = cache.functionCounts() {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.function, default: 0] += 1
        }
        cache.setFunctionCounts(counts)
        return counts
    }

    private var fileNameCounts: [String: Int] {
        if let cached = cache.fileNameCounts() {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.fileName, default: 0] += 1
        }
        cache.setFileNameCounts(counts)
        return counts
    }

    private var contextCounts: [String: Int] {
        if let cached = cache.contextCounts() {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.context, default: 0] += 1
        }
        cache.setContextCounts(counts)
        return counts
    }

    private var threadCounts: [String: Int] {
        if let cached = cache.threadCounts() {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.thread, default: 0] += 1
        }
        cache.setThreadCounts(counts)
        return counts
    }

    // MARK: - 筛选统计
    var activeFilterCount: Int {
        var count = filterState.activeFilterCount
        if !searchState.searchText.isEmpty { count += 1 }
        return count
    }

    // MARK: - 搜索结果计算属性
    var searchResults: CategorizedSearchResults {
        return searchState.computeResults(
            from: events,
            functionCounts: functionCounts,
            fileNameCounts: fileNameCounts,
            contextCounts: contextCounts,
            threadCounts: threadCounts
        )
    }

    // MARK: - 检查项是否已在筛选中
    func isInFilter(_ item: SearchResultItem) -> Bool {
        let filterItem: FilterItem
        switch item.field {
        case .fileName:
            filterItem = .fileName(item.value)
        case .function:
            filterItem = .function(item.value)
        case .context:
            filterItem = .context(item.value)
        case .thread:
            filterItem = .thread(item.value)
        case .message:
            filterItem = .messageKeyword(item.value)
        }
        return filterState.isInFilter(filterItem)
    }

    // MARK: - 添加搜索结果到筛选
    func addToFilter(_ item: SearchResultItem) {
        let filterItem: FilterItem
        switch item.field {
        case .fileName:
            filterItem = .fileName(item.value)
        case .function:
            filterItem = .function(item.value)
        case .context:
            filterItem = .context(item.value)
        case .thread:
            filterItem = .thread(item.value)
        case .message:
            filterItem = .messageKeyword(item.value)
        }
        filterState.addToFilter(filterItem)
    }

    // MARK: - 从筛选中移除
    func removeFromFilter(_ item: SearchResultItem) {
        let filterItem: FilterItem
        switch item.field {
        case .fileName:
            filterItem = .fileName(item.value)
        case .function:
            filterItem = .function(item.value)
        case .context:
            filterItem = .context(item.value)
        case .thread:
            filterItem = .thread(item.value)
        case .message:
            filterItem = .messageKeyword(item.value)
        }
        filterState.removeFromFilter(filterItem)
    }

    // MARK: - 切换筛选状态
    func toggleFilter(_ item: SearchResultItem) {
        if isInFilter(item) {
            removeFromFilter(item)
        } else {
            addToFilter(item)
        }
    }

    // MARK: - 重置筛选
    func resetFilters() {
        searchState.searchText = ""
        searchState.searchFields = [.message, .fileName, .function] // 重置搜索范围
        filterState.resetFilters()
    }

    var exportFileName: String {
        if let logDate = logDate {
            return [prefix, identifier, logDate].joined(separator: "_")
        } else {
            let fileName = logFileURL.lastPathComponent
            if fileName.isEmpty || fileName == "/" {
                return [prefix, identifier, "all_logs"].joined(separator: "_")
            }
            return [prefix, identifier, fileName].joined(separator: "_")
        }
    }

    /// 显示标题
    var displayTitle: String {
        if let logDate = logDate {
            return logDate
        }

        let path = logFileURL.path
        if path.isEmpty || path == "/" {
            return "Logs"
        }

        return logFileURL.lastPathComponent
    }

    let logFileURL: URL
    let logDate: String?
    private(set) var prefix: String
    private(set) var identifier: String

    /// 初始化（默认方式，从数据库加载所有日志）
    public init(prefix: String? = nil, identifier: String? = nil, filterState: FilterState? = nil, searchState: SearchState? = nil, dataLoader: LogDataLoaderProtocol? = nil) {
        // 创建一个空的URL作为占位符
        self.logFileURL = URL(fileURLWithPath: "")
        self.logDate = nil

        if let prefix = prefix {
            self.prefix = prefix
        } else {
            let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
            self.prefix = bundleId
        }

        if let identifier = identifier {
            self.identifier = identifier
        } else {
            let logIdentifier: String = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.logIdentifier) ?? String(UUID().uuidString.prefix(8))
            self.identifier = logIdentifier
            UserDefaults.standard.set(logIdentifier, forKey: Constants.UserDefaultsKeys.logIdentifier)
        }

        // 初始化 FilterState
        self.filterState = filterState ?? FilterState()

        // 初始化 SearchState
        self.searchState = searchState ?? SearchState()

        // 初始化 DataLoader
        if let dataLoader = dataLoader {
            self.dataLoader = dataLoader
        } else {
            let dbManager = LoggerEngine.shared.getDatabaseManager()!
            self.dataLoader = LogDataLoader(databaseManager: dbManager)
        }

        // 设置 FilterState 和 SearchState 变化回调
        setupFilterStateBinding()
    }

    /// 设置 FilterState 和 SearchState 变化订阅
    private func setupFilterStateBinding() {
        filterState.onFilterChanged = { [weak self] in
            guard let self = self else { return }
            self.loadTask?.cancel()
            self.loadTask = Task { await self.reloadWithFilters() }
        }

        searchState.onSearchChanged = { [weak self] in
            guard let self = self else { return }
            // 搜索变化时,触发searchResults计算属性重新计算
            self.objectWillChange.send()
        }
    }

    /// 初始化（使用文件URL，兼容旧方式）
    public init(logFileURL: URL, prefix: String, identifier: String, filterState: FilterState? = nil, searchState: SearchState? = nil, dataLoader: LogDataLoaderProtocol? = nil) {
        self.logFileURL = logFileURL
        self.logDate = nil
        self.prefix = prefix
        self.identifier = identifier

        // 初始化 FilterState
        self.filterState = filterState ?? FilterState()

        // 初始化 SearchState
        self.searchState = searchState ?? SearchState()

        // 初始化 DataLoader
        if let dataLoader = dataLoader {
            self.dataLoader = dataLoader
        } else {
            let dbManager = LoggerEngine.shared.getDatabaseManager()!
            self.dataLoader = LogDataLoader(databaseManager: dbManager)
        }

        // 设置 FilterState 和 SearchState 变化回调
        setupFilterStateBinding()
    }

    /// 初始化（使用日期，从数据库查询）
    public init(logDate: String, prefix: String, identifier: String, filterState: FilterState? = nil, searchState: SearchState? = nil, dataLoader: LogDataLoaderProtocol? = nil) {
        // 创建一个空的URL作为占位符
        self.logFileURL = URL(fileURLWithPath: "")
        self.logDate = logDate
        self.prefix = prefix
        self.identifier = identifier

        // 初始化 FilterState
        self.filterState = filterState ?? FilterState()

        // 初始化 SearchState
        self.searchState = searchState ?? SearchState()

        // 初始化 DataLoader
        if let dataLoader = dataLoader {
            self.dataLoader = dataLoader
        } else {
            let dbManager = LoggerEngine.shared.getDatabaseManager()!
            self.dataLoader = LogDataLoader(databaseManager: dbManager)
        }

        // 设置 FilterState 和 SearchState 变化回调
        setupFilterStateBinding()
    }

    /// 异步加载日志文件
    func loadLogFile() async {
        // 如果有日期，使用数据库查询方式
        if let date = logDate {
            await loadLogsForDate(date)
            return
        }

        // 加载所有日志（现在统一使用数据库）
        await loadAllLogsFromDatabase()
    }

    /// 从数据库加载所有日志
    private func loadAllLogsFromDatabase() async {
        loadingState = .loading(progress: "正在加载所有日志...")

        // 使用 performBackgroundTask 确保线程安全
        await withCheckedContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { [weak self] context in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                do {
                    let dbManager = LoggerEngine.shared.getDatabaseManager()!
                    // 在后台 context 中执行查询
                    let events = try dbManager.fetchEvents(
                        in: context,
                        levels: [.verbose, .debug, .info, .warning, .error, .critical, .fault],
                        limit: 10000
                    )

                    // 切换到主线程更新 UI
                    Task { @MainActor [weak self] in
                        self?.events = events
                        self?.displayEvents = events  // 同时更新displayEvents供UI显示
                        self?.currentPage = 1
                        self?.loadingState = .loaded
                        continuation.resume()
                    }
                } catch {
                    // 错误处理
                    Task { @MainActor [weak self] in
                        print("❌ Failed to load all logs: \(error)")
                        self?.error = error
                        self?.loadingState = .failed(error)
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// 从数据库加载指定日期的日志
    private func loadLogsForDate(_ date: String) async {
        loadingState = .loading(progress: "正在加载日志...")

        do {
            let dbManager = LoggerEngine.shared.getDatabaseManager()!
            let events: [LogEvent] = try await Task.detached {
                try dbManager.fetchEvents(forDate: date)
            }.value

            self.events = events
            self.displayEvents = events  // 同时更新displayEvents供UI显示
            self.currentPage = 1
            self.loadingState = .loaded
        } catch {
            self.error = error
            self.loadingState = .failed(error)
            print("❌ Failed to load logs for date \(date): \(error)")
        }
    }

    // MARK: - 数据库查询方法

    /// 从数据库加载日志数据
    func loadLogsFromDatabase(resetPagination: Bool = true) async {
        // 检查任务是否已被取消
        if Task.isCancelled { return }

        // 根据是否重置分页来设置不同的loading状态
        if resetPagination {
            loadingState = .loading(progress: "正在查询...")
        } else {
            loadingState = .loadingMore
        }

        let page = resetPagination ? 0 : currentPage
        let offset = page * pageSize

        do {
            // 使用 DataLoader 加载数据
            let events = try await dataLoader.loadEvents(
                sessionId: filterState.selectedSessionId,
                filterState: filterState,
                searchText: searchState.searchText,
                offset: offset,
                limit: pageSize
            )

            // 更新显示数据
            if resetPagination {
                displayEvents = events
                currentPage = 1
                hasMoreData = true
            } else {
                displayEvents.append(contentsOf: events)
                currentPage += 1
            }

            // 判断是否还有更多数据
            if events.count < pageSize {
                hasMoreData = false
            }

            loadingState = .loaded
        } catch {
            print("❌ Failed to load logs from database: \(error)")
            self.error = error
            loadingState = .failed(error)
        }
    }

    /// 加载更多日志
    func loadMore() async {
        // 如果没有更多数据或正在加载中,直接返回
        guard hasMoreData, loadingState != .loadingMore else { return }

        await loadLogsFromDatabase(resetPagination: false)
    }

    /// 加载统计信息
    func loadStatistics() async {
        do {
            let stats = try await dataLoader.loadStatistics()
            self.statistics = stats
        } catch {
            print("❌ Failed to load statistics: \(error)")
        }
    }

    /// 重新查询
    func refresh() {
        Task {
            await loadLogsFromDatabase(resetPagination: true)
        }
    }

    /// 过滤条件变化时重新加载
    private func reloadWithFilters() async {
        // 重置分页并重新加载(isReloading检查在loadLogsFromDatabase中)
        await loadLogsFromDatabase(resetPagination: true)
    }

    /// 获取筛选选项
    func loadFilterOptions() async {
        do {
            let dbManager = LoggerEngine.shared.getDatabaseManager()!

            _ = try await Task.detached {
                try dbManager.fetchUniqueValues(for: "function")
            }.value

            _ = try await Task.detached {
                try dbManager.fetchUniqueValues(for: "fileName")
            }.value

            _ = try await Task.detached {
                try dbManager.fetchUniqueValues(for: "context")
            }.value

            _ = try await Task.detached {
                try dbManager.fetchUniqueValues(for: "thread")
            }.value

            // 更新可用选项
            // (可以保存到 @Published 属性中供 UI 使用)

        } catch {
            print("❌ Failed to load filter options: \(error)")
        }
    }

    func toggleLevel(_ level: LogEvent.Level) {
        filterState.toggleLevel(level)
    }
}
