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
public enum SearchField: String, CaseIterable, Identifiable, Sendable {
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
    /// 全量数据,用于搜索预览 (不受任何过滤条件影响)
    @Published var allEventsForSearchPreview: [LogEvent] = [] {
        didSet {
            invalidateAllEventsCache()
        }
    }
    /// 显示用的 ViewModel 数组,封装了 event、index 和预计算的颜色
    @Published var displayEvents: [LogRowViewModel] = []
    /// 符合当前筛选条件的日志总数(不受分页限制)
    @Published var totalCount: Int = 0
    @Published var loadingState: LoadingState = .idle
    @Published var error: Error?

    // MARK: - 分页
    private var currentPage = 0
    private let pageSize = 500
    private var hasMoreData = true  // 是否还有更多数据

    // MARK: - 加载控制
    private var loadTask: Task<Void, Never>?

    /// 查询序列号 - 用于识别最新的查询请求
    private var querySequenceNumber: UInt64 = 0

    /// 当前生效的查询序列号 - 只接受不小于此序列号的查询结果
    private var activeQuerySequence: UInt64 = 0

    // MARK: - 统计信息
    @Published var statistics: LogStatistics?

    // MARK: - 缓存管理器
    private let cache = FilterOptionsCache()
    private let allEventsCache = FilterOptionsCache()

    /// 清除所有缓存
    private func invalidateCache() {
        cache.invalidateAll()
    }

    /// 清除全量数据缓存
    private func invalidateAllEventsCache() {
        allEventsCache.invalidateAll()
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

    private var messageCounts: [String: Int] {
        if let cached = cache.messageCounts() {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.message, default: 0] += 1
        }
        cache.setMessageCounts(counts)
        return counts
    }

    // MARK: - 全量数据计数 (用于搜索预览)
    private var allFunctionCounts: [String: Int] {
        if let cached = allEventsCache.functionCounts() {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in allEventsForSearchPreview {
            counts[event.function, default: 0] += 1
        }
        allEventsCache.setFunctionCounts(counts)
        return counts
    }

    private var allFileNameCounts: [String: Int] {
        if let cached = allEventsCache.fileNameCounts() {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in allEventsForSearchPreview {
            counts[event.fileName, default: 0] += 1
        }
        allEventsCache.setFileNameCounts(counts)
        return counts
    }

    private var allContextCounts: [String: Int] {
        if let cached = allEventsCache.contextCounts() {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in allEventsForSearchPreview {
            counts[event.context, default: 0] += 1
        }
        allEventsCache.setContextCounts(counts)
        return counts
    }

    private var allThreadCounts: [String: Int] {
        if let cached = allEventsCache.threadCounts() {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in allEventsForSearchPreview {
            counts[event.thread, default: 0] += 1
        }
        allEventsCache.setThreadCounts(counts)
        return counts
    }

    private var allMessageCounts: [String: Int] {
        if let cached = allEventsCache.messageCounts() {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in allEventsForSearchPreview {
            counts[event.message, default: 0] += 1
        }
        allEventsCache.setMessageCounts(counts)
        return counts
    }

    // MARK: - 筛选统计
    var activeFilterCount: Int {
        var count = filterState.activeFilterCount
        if !searchState.searchText.isEmpty { count += 1 }
        return count
    }

    // MARK: - 搜索结果计算属性
    /// 直接返回缓存的搜索结果,避免主线程计算
    var searchResults: CategorizedSearchResults {
        return searchState.cachedResults
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
            // 添加当前搜索的关键词,而非完整的 message 文本
            let keyword = searchState.searchText.trimmingCharacters(in: .whitespaces)
            filterItem = .messageKeyword(keyword.isEmpty ? item.value : keyword)
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
        searchState.searchFields = [.message, .fileName, .function, .context, .thread] // 重置搜索范围为全部
        filterState.resetFilters()
    }

    /// 生成导出文件名
    /// - Parameter firstLogTimestamp: 第一条日志的时间戳
    /// - Returns: 格式为 `{bundleId}_{identifier}_{YYYY-MM-DD}_{HHmmss}.log` 的文件名
    func generateExportFileName(firstLogTimestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: firstLogTimestamp)

        // 日期格式化器 - YYYY-MM-DD
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = dateFormatter.string(from: date)

        // 时间格式化器 - HHmmss
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmmss"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        let timeString = timeFormatter.string(from: date)

        // 组装文件名: {bundleId}_{identifier}_{date}_{time}.log
        return "\(prefix)_\(identifier)_\(dateString)_\(timeString).log"
    }

    /// 显示标题
    var displayTitle: String {
        return "Logs"
    }

    private(set) var prefix: String
    private(set) var identifier: String

    /// 初始化（从数据库加载所有日志）
    public init(prefix: String? = nil, identifier: String? = nil, filterState: FilterState? = nil, searchState: SearchState? = nil, dataLoader: LogDataLoaderProtocol? = nil) {
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
            // 搜索变化时,重新从数据库查询（和筛选条件变化一样的处理）
            // 这样可以搜索整个数据库,而不仅仅是已加载的分页数据
            print("🔍 搜索文本变化: '\(self.searchState.searchText)', 触发数据库查询")
            self.loadTask?.cancel()
            self.loadTask = Task { await self.reloadWithFilters() }
        }
    }

    /// 异步加载日志文件
    func loadLogFile() async {
        loadingState = .loading(progress: "正在加载日志...")
        await loadLogsFromDatabase(resetPagination: true)
    }

    // MARK: - 数据库查询方法

    /// 从数据库加载日志数据
    func loadLogsFromDatabase(resetPagination: Bool = true) async {
        // 检查任务是否已被取消
        if Task.isCancelled { return }

        // 生成新的查询序列号
        querySequenceNumber += 1
        let currentSequence = querySequenceNumber

        // 如果是重置分页(新查询),更新生效序列号
        if resetPagination {
            activeQuerySequence = currentSequence
            print("📊 开始查询: seq=\(currentSequence)")
        }

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
                sessionIds: filterState.selectedSessionIds,
                filterState: filterState,
                offset: offset,
                limit: pageSize
            )

            // 【关键】验证查询序列号 - 只接受最新的查询结果
            guard currentSequence >= activeQuerySequence else {
                print("⚠️ 丢弃过期查询结果: seq=\(currentSequence), active=\(activeQuerySequence), events.count=\(events.count)")
                return
            }

            print("✅ 查询完成: seq=\(currentSequence), events.count=\(events.count)")

            // 再次检查任务是否被取消
            if Task.isCancelled { return }

            // 更新显示数据
            if resetPagination {
                // 重置分页:更新 events 数组(用于搜索结果计算)
                self.events = events

                // 转换为 ViewModel,从 1 开始编号
                let viewModels = events.enumerated().map { index, event in
                    LogRowViewModel(event: event, index: index + 1)
                }
                displayEvents = viewModels
                currentPage = 1
                hasMoreData = true

                // 查询总数
                totalCount = await fetchTotalCount(sequence: currentSequence)

                // 加载全量数据用于搜索预览
                await loadAllEventsForSearchPreview()
            } else {
                // 追加分页:追加到 events 数组
                self.events.append(contentsOf: events)

                // 计算起始 index 保持连续
                let startIndex = displayEvents.count + 1
                let viewModels = events.enumerated().map { offset, event in
                    LogRowViewModel(event: event, index: startIndex + offset)
                }
                displayEvents.append(contentsOf: viewModels)
                currentPage += 1
            }

            // 判断是否还有更多数据
            if events.count < pageSize {
                hasMoreData = false
            }

            loadingState = .loaded

            // 数据加载完成后,触发异步搜索更新
            performAsyncSearch()
        } catch {
            // 验证查询序列号 - 只处理最新查询的错误
            guard currentSequence >= activeQuerySequence else {
                print("⚠️ 丢弃过期查询错误: seq=\(currentSequence)")
                return
            }

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

    /// 加载全量数据用于搜索预览
    private func loadAllEventsForSearchPreview() async {
        do {
            let events = try await dataLoader.loadAllEventsForSearchPreview(
                sessionIds: filterState.selectedSessionIds,
                limit: 10000
            )
            self.allEventsForSearchPreview = events
            print("📊 已加载全量数据用于搜索预览: count=\(events.count)")
        } catch {
            print("❌ Failed to load all events for search preview: \(error)")
        }
    }

    /// 执行异步搜索 - 在后台线程计算搜索结果 (基于全量数据)
    private func performAsyncSearch() {
        print("🔎 执行搜索预览计算: allEvents.count=\(allEventsForSearchPreview.count), searchText='\(searchState.searchText)', searchFields=\(searchState.searchFields)")
        searchState.computeResultsAsync(
            from: allEventsForSearchPreview,
            functionCounts: allFunctionCounts,
            fileNameCounts: allFileNameCounts,
            contextCounts: allContextCounts,
            threadCounts: allThreadCounts,
            messageCounts: allMessageCounts
        )
    }

    /// 刷新搜索结果 - 公共接口，供 UI 组件调用
    public func refreshSearch() {
        performAsyncSearch()
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

    /// 查询符合当前筛选条件的日志总数
    /// - Parameters:
    ///   - sequence: 查询序列号,用于验证结果有效性
    private func fetchTotalCount(
        sequence: UInt64
    ) async -> Int {
        do {
            let count = try await dataLoader.countEvents(
                sessionIds: filterState.selectedSessionIds,
                filterState: filterState
            )

            // 验证序列号 - 只接受最新查询的总数
            guard sequence >= activeQuerySequence else {
                print("⚠️ 丢弃过期总数查询: seq=\(sequence), active=\(activeQuerySequence)")
                return totalCount  // 返回当前值,不更新
            }

            return count
        } catch {
            print("❌ Failed to fetch total count: \(error)")
            return 0
        }
    }

    /// 流式导出所有符合条件的日志到临时文件
    ///
    /// 使用分批查询和追加写入,避免全量内存加载,内存峰值 < 10MB。
    /// 文件名格式: `{bundleId}_{identifier}_{YYYY-MM-DD}_{HHmmss}.log`
    ///
    /// - Parameters:
    ///   - progressHandler: 进度回调 (已导出条数, 总条数)
    /// - Returns: 导出文件的 URL
    /// - Throws: 导出过程中的错误（包括数据为空的错误）
    func exportAllEventsStreaming(
        progressHandler: @escaping (Int, Int) -> Void
    ) async throws -> URL {
        // 首先查询总数
        let totalCount = try await dataLoader.countEvents(
            sessionIds: filterState.selectedSessionIds,
            filterState: filterState
        )

        // 检查数据是否为空
        guard totalCount > 0 else {
            throw ExportError.emptyData
        }

        // 获取第一条日志以获取时间戳
        let firstBatch = try await dataLoader.loadEvents(
            sessionIds: filterState.selectedSessionIds,
            filterState: filterState,
            offset: 0,
            limit: 1
        )

        guard let firstEvent = firstBatch.first else {
            throw ExportError.emptyData
        }

        // 使用第一条日志的时间戳生成文件名
        let fileName = generateExportFileName(firstLogTimestamp: firstEvent.timestamp)

        // 初始化进度
        progressHandler(0, totalCount)

        // 使用流式导出
        return try await LogParser.logEventToTempFileStreaming(
            fileName: fileName,
            batchSize: 1000,
            progressHandler: { written, _ in
                // 更新进度(传入准确的总数)
                progressHandler(written, totalCount)
            },
            eventFetcher: { [weak self] offset, limit in
                guard let self = self else { return [] }

                // 分批查询日志
                return try await self.dataLoader.loadEvents(
                    sessionIds: self.filterState.selectedSessionIds,
                    filterState: self.filterState,
                    offset: offset,
                    limit: limit
                )
            }
        )
    }


    func toggleLevel(_ level: LogEvent.Level) {
        filterState.toggleLevel(level)
    }
}
