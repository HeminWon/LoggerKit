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
enum SearchField: String, CaseIterable, Identifiable {
    case message = "message"
    case fileName = "fileName"
    case function = "function"
    case context = "context"
    case thread = "thread"

    var id: String { rawValue }

    var localizedName: String {
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

    var icon: String {
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
struct SearchResultItem: Identifiable {
    let id = UUID()
    let field: SearchField
    let value: String
    let matchCount: Int
}

// MARK: - 分类搜索结果
/// 分类搜索结果
struct CategorizedSearchResults {
    var message: [SearchResultItem] = []
    var fileName: [SearchResultItem] = []
    var function: [SearchResultItem] = []
    var context: [SearchResultItem] = []
    var thread: [SearchResultItem] = []

    var totalCount: Int {
        message.count + fileName.count + function.count + context.count + thread.count
    }

    var isEmpty: Bool {
        totalCount == 0
    }
}

@MainActor
public class LogDetailSceneState: ObservableObject {

    @Published var logContent: String?
    @Published var selectedLevels: Set<LogEvent.Level> = [.verbose, .debug, .info, .warning, .error]
    @Published var events: [LogEvent] = [] {
        didSet {
            invalidateCache()
        }
    }
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // MARK: - 多条件筛选状态
    @Published var searchText: String = ""
    @Published var selectedFunctions: Set<String> = []
    @Published var selectedFileNames: Set<String> = []
    @Published var selectedContexts: Set<String> = []
    @Published var selectedThreads: Set<String> = []
    @Published var selectedMessageKeywords: Set<String> = []

    // MARK: - 搜索配置
    @Published var searchFields: Set<SearchField> = [.message, .fileName, .function]

    // MARK: - 缓存属性
    private var _cachedFunctions: [String]?
    private var _cachedFileNames: [String]?
    private var _cachedContexts: [String]?
    private var _cachedThreads: [String]?
    private var _cachedFunctionCounts: [String: Int]?
    private var _cachedFileNameCounts: [String: Int]?
    private var _cachedContextCounts: [String: Int]?
    private var _cachedThreadCounts: [String: Int]?

    /// 清除所有缓存
    private func invalidateCache() {
        _cachedFunctions = nil
        _cachedFileNames = nil
        _cachedContexts = nil
        _cachedThreads = nil
        _cachedFunctionCounts = nil
        _cachedFileNameCounts = nil
        _cachedContextCounts = nil
        _cachedThreadCounts = nil
    }

    // MARK: - 可选项列表（从日志数据中提取，带缓存）
    var availableFunctions: [String] {
        if let cached = _cachedFunctions {
            return cached
        }
        let result = Array(Set(events.map { $0.function })).sorted()
        _cachedFunctions = result
        return result
    }

    var availableFileNames: [String] {
        if let cached = _cachedFileNames {
            return cached
        }
        let result = Array(Set(events.map { $0.fileName })).sorted()
        _cachedFileNames = result
        return result
    }

    var availableContexts: [String] {
        if let cached = _cachedContexts {
            return cached
        }
        let result = Array(Set(events.map { $0.context })).filter { !$0.isEmpty }.sorted()
        _cachedContexts = result
        return result
    }

    var availableThreads: [String] {
        if let cached = _cachedThreads {
            return cached
        }
        let result = Array(Set(events.map { $0.thread })).filter { !$0.isEmpty }.sorted()
        _cachedThreads = result
        return result
    }

    // MARK: - 计数缓存
    private var functionCounts: [String: Int] {
        if let cached = _cachedFunctionCounts {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.function, default: 0] += 1
        }
        _cachedFunctionCounts = counts
        return counts
    }

    private var fileNameCounts: [String: Int] {
        if let cached = _cachedFileNameCounts {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.fileName, default: 0] += 1
        }
        _cachedFileNameCounts = counts
        return counts
    }

    private var contextCounts: [String: Int] {
        if let cached = _cachedContextCounts {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.context, default: 0] += 1
        }
        _cachedContextCounts = counts
        return counts
    }

    private var threadCounts: [String: Int] {
        if let cached = _cachedThreadCounts {
            return cached
        }
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.thread, default: 0] += 1
        }
        _cachedThreadCounts = counts
        return counts
    }

    // MARK: - 筛选后的事件
    var filteredEvents: [LogEvent] {
        // 预计算搜索文本，避免在循环中重复计算
        let lowercasedSearch = searchText.lowercased()
        let lowercasedKeywords = selectedMessageKeywords.map { $0.lowercased() }

        return events.filter { event in
            // 日志等级筛选
            guard selectedLevels.contains(event.level) else { return false }

            // 函数名筛选（空集合表示不限制）
            if !selectedFunctions.isEmpty && !selectedFunctions.contains(event.function) {
                return false
            }

            // 文件名筛选
            if !selectedFileNames.isEmpty && !selectedFileNames.contains(event.fileName) {
                return false
            }

            // 模块筛选
            if !selectedContexts.isEmpty && !selectedContexts.contains(event.context) {
                return false
            }

            // 线程筛选
            if !selectedThreads.isEmpty && !selectedThreads.contains(event.thread) {
                return false
            }

            // 关键词搜索
            if !searchText.isEmpty {
                let lowercasedMessage = event.message.lowercased()
                let lowercasedFunction = event.function.lowercased()
                let lowercasedFile = event.fileName.lowercased()
                let matchesMessage = lowercasedMessage.contains(lowercasedSearch)
                let matchesFunction = lowercasedFunction.contains(lowercasedSearch)
                let matchesFile = lowercasedFile.contains(lowercasedSearch)
                if !matchesMessage && !matchesFunction && !matchesFile {
                    return false
                }
            }

            // 消息关键词筛选
            if !lowercasedKeywords.isEmpty {
                let lowercasedMessage = event.message.lowercased()
                let matchesAnyKeyword = lowercasedKeywords.contains { keyword in
                    lowercasedMessage.contains(keyword)
                }
                if !matchesAnyKeyword {
                    return false
                }
            }

            return true
        }
    }

    // MARK: - 筛选统计
    var activeFilterCount: Int {
        var count = 0
        if !searchText.isEmpty { count += 1 }
        if !selectedFunctions.isEmpty { count += 1 }
        if !selectedFileNames.isEmpty { count += 1 }
        if !selectedContexts.isEmpty { count += 1 }
        if !selectedThreads.isEmpty { count += 1 }
        if !selectedMessageKeywords.isEmpty { count += 1 }
        return count
    }

    // MARK: - 搜索结果计算属性
    var searchResults: CategorizedSearchResults {
        guard !searchText.isEmpty else { return CategorizedSearchResults() }

        let lowercasedSearch = searchText.lowercased()
        var results = CategorizedSearchResults()

        // 消息匹配
        if searchFields.contains(.message) {
            let matchedMessages = events
                .filter { $0.message.lowercased().contains(lowercasedSearch) }
                .prefix(5)
                .map { SearchResultItem(field: .message, value: $0.message, matchCount: 1) }
            results.message = Array(matchedMessages)
        }

        // 文件匹配 - 使用预计算的计数
        if searchFields.contains(.fileName) {
            let counts = fileNameCounts
            let matchedFiles = availableFileNames
                .filter { $0.lowercased().contains(lowercasedSearch) }
                .map { fileName in
                    let count = counts[fileName] ?? 0
                    return SearchResultItem(field: .fileName, value: fileName, matchCount: count)
                }
            results.fileName = matchedFiles
        }

        // 函数匹配 - 使用预计算的计数
        if searchFields.contains(.function) {
            let counts = functionCounts
            let matchedFunctions = availableFunctions
                .filter { $0.lowercased().contains(lowercasedSearch) }
                .map { function in
                    let count = counts[function] ?? 0
                    return SearchResultItem(field: .function, value: function, matchCount: count)
                }
            results.function = matchedFunctions
        }

        // 模块匹配 - 使用预计算的计数
        if searchFields.contains(.context) {
            let counts = contextCounts
            let matchedContexts = availableContexts
                .filter { $0.lowercased().contains(lowercasedSearch) }
                .map { context in
                    let count = counts[context] ?? 0
                    return SearchResultItem(field: .context, value: context, matchCount: count)
                }
            results.context = matchedContexts
        }

        // 线程匹配 - 使用预计算的计数
        if searchFields.contains(.thread) {
            let counts = threadCounts
            let matchedThreads = availableThreads
                .filter { $0.lowercased().contains(lowercasedSearch) }
                .map { thread in
                    let count = counts[thread] ?? 0
                    return SearchResultItem(field: .thread, value: thread, matchCount: count)
                }
            results.thread = matchedThreads
        }

        return results
    }

    // MARK: - 检查项是否已在筛选中
    func isInFilter(_ item: SearchResultItem) -> Bool {
        switch item.field {
        case .fileName:
            return selectedFileNames.contains(item.value)
        case .function:
            return selectedFunctions.contains(item.value)
        case .context:
            return selectedContexts.contains(item.value)
        case .thread:
            return selectedThreads.contains(item.value)
        case .message:
            return selectedMessageKeywords.contains(item.value)
        }
    }

    // MARK: - 添加搜索结果到筛选
    func addToFilter(_ item: SearchResultItem) {
        switch item.field {
        case .fileName:
            selectedFileNames.insert(item.value)
        case .function:
            selectedFunctions.insert(item.value)
        case .context:
            selectedContexts.insert(item.value)
        case .thread:
            selectedThreads.insert(item.value)
        case .message:
            selectedMessageKeywords.insert(item.value)
        }
    }

    // MARK: - 从筛选中移除
    func removeFromFilter(_ item: SearchResultItem) {
        switch item.field {
        case .fileName:
            selectedFileNames.remove(item.value)
        case .function:
            selectedFunctions.remove(item.value)
        case .context:
            selectedContexts.remove(item.value)
        case .thread:
            selectedThreads.remove(item.value)
        case .message:
            selectedMessageKeywords.remove(item.value)
        }
    }

    // MARK: - 切换筛选状态
    func toggleFilter(_ item: SearchResultItem) {
        if isInFilter(item) {
            removeFromFilter(item)
        } else {
            addToFilter(item)
        }
    }

    // MARK: - 切换搜索字段
    func toggleSearchField(_ field: SearchField) {
        if searchFields.contains(field) {
            searchFields.remove(field)
        } else {
            searchFields.insert(field)
        }
    }

    // MARK: - 重置筛选
    func resetFilters() {
        searchText = ""
        selectedLevels = [.verbose, .debug, .info, .warning, .error]
        selectedFunctions = []
        selectedFileNames = []
        selectedContexts = []
        selectedThreads = []
        selectedMessageKeywords = []
        searchFields = [.message, .fileName, .function] // 重置搜索范围
    }

    var exportFileName: String {
        return [prefix, identifier, logFileURL.lastPathComponent].joined(separator: "_")
    }

    let logFileURL: URL
    private(set) var prefix: String
    private(set) var identifier: String

    public init(logFileURL: URL, prefix: String, identifier: String) {
        self.logFileURL = logFileURL
        self.prefix = prefix
        self.identifier = identifier
    }

    /// 异步加载日志文件
    func loadLogFile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 在后台线程读取文件
            let content = try await Task.detached {
                try String(contentsOf: self.logFileURL, encoding: .utf8)
            }.value

            self.logContent = content

            // 在后台线程解析
            let parsedEvents = await Task.detached {
                LogParser.parseJsonLinesToEvents(content)
            }.value

            self.events = parsedEvents
        } catch {
            self.error = error
            print("❌ Failed to load log file: \(error)")
        }
    }

    func toggleLevel(_ level: LogEvent.Level) {
        if selectedLevels.contains(level) {
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
    }
}
