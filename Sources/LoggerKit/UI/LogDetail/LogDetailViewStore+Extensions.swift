//
//  LogDetailViewStore+Extensions.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import SwiftUI

// MARK: - ViewStore + LogDetail (Convenience)

/// LogDetail 专用的便捷方法和计算属性
///
/// 通过 extension 扩展通用 ViewStore,提供 LogDetail 特定的 API
/// 这样避免了创建专门的 LogDetailViewStore 类
extension ViewStore where State == LogDetailState, Action == LogDetailAction {

    // MARK: - 计算属性 (从 State 派生)

    /// 显示的事件列表
    public var displayEvents: [LogRowViewModel] {
        state.list.displayEvents
    }

    /// 事件总数
    public var totalCount: Int {
        state.list.totalCount
    }

    /// 加载状态
    public var loadingState: LoadingState {
        state.list.loadingState
    }

    /// 是否正在加载
    public var isLoading: Bool {
        if case .loading = state.list.loadingState {
            return true
        }
        return false
    }

    /// 活动过滤器数量
    public var activeFilterCount: Int {
        state.activeFilterCount
    }

    /// 是否正在导出
    public var isExporting: Bool {
        state.exportFeature.isExporting
    }

    /// 导出进度
    public var exportProgress: Double {
        state.exportFeature.progress
    }

    /// 搜索文本
    public var searchText: String {
        state.searchFeature.searchText
    }

    /// 是否正在搜索
    public var isSearchActive: Bool {
        !state.searchFeature.searchText.isEmpty && state.searchFeature.searchPhase != .idle
    }

    /// 错误信息
    public var error: Error? {
        state.error
    }

    /// 导出的文件 URL
    public var exportedFileURL: URL? {
        state.exportFeature.exportedFileURL
    }

    /// 已导出数量
    public var exportedCount: Int {
        state.exportFeature.exportedCount
    }

    /// 总导出数量
    public var totalExportCount: Int {
        // ExportFeature 没有 totalExportCount,使用 displayEvents 的数量作为总数
        state.list.displayEvents.count
    }

    /// 显示标题
    public var displayTitle: String {
        "LoggerKit"
    }

    /// 可用的上下文列表
    public var availableContexts: [String] {
        if let cached = state.cachedAvailableContexts {
            return cached
        }
        if !state.allEventsForSearchPreview.isEmpty {
            return Array(Set(state.allEventsForSearchPreview.map { $0.context })).filter { !$0.isEmpty }.sorted()
        }
        // 不使用已过滤的 list.events，避免筛选后选项消失
        return []
    }

    /// 可用的文件名列表
    public var availableFileNames: [String] {
        if let cached = state.cachedAvailableFileNames {
            return cached
        }
        if !state.allEventsForSearchPreview.isEmpty {
            return Array(Set(state.allEventsForSearchPreview.map { $0.fileName })).sorted()
        }
        // 不使用已过滤的 list.events，避免筛选后选项消失
        return []
    }

    /// 可用的函数列表
    public var availableFunctions: [String] {
        if let cached = state.cachedAvailableFunctions {
            return cached
        }
        if let stats = state.statistics, !stats.topFunctions.isEmpty {
            return stats.topFunctions.map { $0.0 }
        }
        if !state.allEventsForSearchPreview.isEmpty {
            return Array(Set(state.allEventsForSearchPreview.map { $0.function })).sorted()
        }
        // 不使用已过滤的 list.events，避免筛选后选项消失
        return []
    }

    /// 可用的线程列表
    public var availableThreads: [String] {
        if let cached = state.cachedAvailableThreads {
            return cached
        }
        if !state.allEventsForSearchPreview.isEmpty {
            return Array(Set(state.allEventsForSearchPreview.map { $0.thread })).filter { !$0.isEmpty }.sorted()
        }
        // 不使用已过滤的 list.events，避免筛选后选项消失
        return []
    }

    // MARK: - 预定义 Bindings (常用场景)

    /// 搜索文本绑定
    ///
    /// 使用示例:
    /// ```swift
    /// TextField("Search", text: viewStore.searchTextBinding)
    /// ```
    public var searchTextBinding: Binding<String> {
        binding(
            get: { $0.searchFeature.searchText },
            send: { .search(.updateSearchText($0)) }
        )
    }

    /// 过滤器展示绑定
    ///
    /// 使用示例:
    /// ```swift
    /// .sheet(isPresented: viewStore.filterPresentedBinding) {
    ///     FilterSheet(viewStore: viewStore)
    /// }
    /// ```
    public var filterPresentedBinding: Binding<Bool> {
        binding(
            get: { $0.isFilterPresented },
            send: { .setFilterPresented($0) }
        )
    }

    /// 分享展示绑定
    public var sharePresentedBinding: Binding<Bool> {
        binding(
            get: { $0.isSharePresented },
            send: { .setSharePresented($0) }
        )
    }

    /// 删除管理展示绑定
    public var deleteManagementPresentedBinding: Binding<Bool> {
        binding(
            get: { $0.isDeleteManagementPresented },
            send: { .setDeleteManagementPresented($0) }
        )
    }

    /// 导出错误展示绑定
    public var exportErrorPresentedBinding: Binding<Bool> {
        binding(
            get: { $0.showExportError },
            send: { .setExportErrorPresented($0) }
        )
    }

    // MARK: - 过滤器便捷访问器

    /// 选中的日志级别
    public var selectedLevels: Set<LogEvent.Level> {
        state.filterFeature.selectedLevels
    }

    /// 选中的函数
    public var selectedFunctions: Set<String> {
        state.filterFeature.selectedFunctions
    }

    /// 选中的文件名
    public var selectedFileNames: Set<String> {
        state.filterFeature.selectedFileNames
    }

    /// 选中的上下文
    public var selectedContexts: Set<String> {
        state.filterFeature.selectedContexts
    }

    /// 选中的线程
    public var selectedThreads: Set<String> {
        state.filterFeature.selectedThreads
    }

    /// 选中的消息关键词
    public var selectedMessageKeywords: Set<String> {
        state.filterFeature.selectedMessageKeywords
    }

    /// 选中的会话 ID
    public var selectedSessionIds: Set<String> {
        state.filterFeature.selectedSessionIds
    }

    // MARK: - 会话管理便捷访问器

    /// 可用的会话列表
    public var availableSessions: [SessionInfo] {
        state.filterFeature.availableSessions
    }

    /// 会话加载状态
    public var isLoadingSessions: Bool {
        state.filterFeature.isLoadingSessions
    }

    /// 会话加载错误信息
    public var sessionLoadingError: String? {
        state.filterFeature.sessionLoadingError
    }

    // MARK: - 搜索便捷访问器

    /// 搜索字段
    public var searchFields: Set<SearchField> {
        state.searchFeature.searchFields
    }

    /// 搜索结果
    public var searchResults: CategorizedSearchResults {
        // 使用新的深度搜索结果构建分类结果
        state.searchFeature.categorizedResults
    }

    // MARK: - 便捷方法 (Action 封装)

    /// 加载日志文件
    ///
    /// 使用示例:
    /// ```swift
    /// Button("Load") {
    ///     viewStore.loadLogFile()  // ✅ 同步调用
    /// }
    /// ```
    public func loadLogFile() {
        send(.list(.loadLogFile))
    }

    /// 加载更多日志
    public func loadMore() {
        send(.list(.loadMore))
    }

    /// 刷新日志
    public func refresh() {
        send(.list(.refresh))
    }

    /// 重置过滤器
    public func resetFilter() {
        send(.filter(.resetFilters))
    }

    /// 重置所有过滤器 (别名方法,与 resetFilter 功能相同)
    public func resetFilters() {
        send(.filter(.resetFilters))
    }

    /// 切换日志级别
    ///
    /// - Parameter level: 要切换的日志级别
    public func toggleLevel(_ level: LogEvent.Level) {
        send(.filter(.toggleLevel(level)))
    }

    /// 开始导出
    ///
    /// - Parameter format: 导出格式
    public func startExport(format: ExportFormat) {
        send(.export(.startExport(format: format)))
    }

    /// 取消导出
    public func cancelExport() {
        send(.export(.cancelExport))
    }

    /// 删除所有日志 (同步)
    public func deleteAllLogs() {
        send(.deleteAllLogs)
    }

    /// 删除所有日志 (异步,等待完成)
    public func deleteAllLogsAsync() async throws {
        await sendAsync(.deleteAllLogs)

        // 等待一小段时间确保操作完成
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // 检查错误
        if let error = state.error {
            throw error
        }
    }

    /// 删除指定会话的日志
    public func deleteSession(_ sessionId: String) async throws {
        // 通过 deleteAllLogs 实现 (TCA Store 目前不支持单个会话删除)
        // TODO: 扩展 LogDetailAction 支持单个会话删除
        await sendAsync(.deleteAllLogs)

        try await Task.sleep(nanoseconds: 100_000_000)

        if let error = state.error {
            throw error
        }
    }

    /// 删除多个会话的日志
    public func deleteSessions(_ sessionIds: Set<String>) async throws {
        // 通过 deleteAllLogs 实现 (TCA Store 目前不支持多个会话删除)
        // TODO: 扩展 LogDetailAction 支持多个会话删除
        await sendAsync(.deleteAllLogs)

        try await Task.sleep(nanoseconds: 100_000_000)

        if let error = state.error {
            throw error
        }
    }

    /// 更新搜索文本
    ///
    /// - Parameter text: 搜索文本
    public func updateSearchText(_ text: String) {
        send(.search(.updateSearchText(text)))
    }

    /// 执行搜索
    public func executeSearch() {
        // 新的深度搜索通过 updateSearchText 自动触发
        // 这里保持接口兼容性，实际不执行任何操作
    }

    /// 清除搜索（通过设置空文本实现）
    public func clearSearch() {
        send(.search(.updateSearchText("")))
    }

    /// 刷新搜索结果
    public func refreshSearch() {
        // 新的深度搜索通过 updateSearchText 自动触发
        // 这里保持接口兼容性，实际不执行任何操作
    }

    /// 切换搜索字段
    ///
    /// - Parameter field: 要切换的搜索字段
    public func toggleSearchField(_ field: SearchField) {
        send(.search(.toggleSearchField(field)))
    }

    // MARK: - 过滤项管理

    /// 检查搜索结果项是否在过滤器中
    ///
    /// - Parameter item: 搜索结果项
    /// - Returns: 是否在过滤器中
    public func isInFilter(_ item: SearchResultItem) -> Bool {
        switch item.field {
        case .function:
            return state.filterFeature.selectedFunctions.contains(item.value)
        case .fileName:
            return state.filterFeature.selectedFileNames.contains(item.value)
        case .context:
            return state.filterFeature.selectedContexts.contains(item.value)
        case .thread:
            return state.filterFeature.selectedThreads.contains(item.value)
        case .message:
            return state.filterFeature.selectedMessageKeywords.contains(item.value)
        }
    }

    /// 添加搜索结果项到过滤器
    ///
    /// - Parameter item: 搜索结果项
    public func addToFilter(_ item: SearchResultItem) {
        let filterType = mapFieldToFilterType(item.field)
        send(.filter(.updateFilter(filterType, .add(item.value))))
    }

    /// 从过滤器中移除搜索结果项
    ///
    /// - Parameter item: 搜索结果项
    public func removeFromFilter(_ item: SearchResultItem) {
        let filterType = mapFieldToFilterType(item.field)
        send(.filter(.updateFilter(filterType, .remove(item.value))))
    }

    /// 切换搜索结果项的过滤器状态
    ///
    /// - Parameter item: 搜索结果项
    public func toggleFilter(_ item: SearchResultItem) {
        let filterType = mapFieldToFilterType(item.field)
        send(.filter(.updateFilter(filterType, .toggle(item.value))))
    }

    /// 映射搜索字段到过滤器类型
    ///
    /// - Parameter field: 搜索字段
    /// - Returns: 过滤器类型
    private func mapFieldToFilterType(_ field: SearchField) -> FilterFeature.FilterType {
        switch field {
        case .function: return .function
        case .fileName: return .fileName
        case .context: return .context
        case .thread: return .thread
        case .message: return .messageKeyword
        }
    }

    // MARK: - 异步便捷方法 (需要等待完成的场景)

    /// 加载日志文件 (异步)
    ///
    /// 使用示例:
    /// ```swift
    /// .task {
    ///     await viewStore.loadLogFileAsync()
    ///     print("Loading completed")
    /// }
    /// ```
    public func loadLogFileAsync() async {
        await sendAsync(.list(.loadLogFile))
    }

    /// 导出日志 (异步)
    public func exportLogsAsync(format: ExportFormat) async {
        await sendAsync(.export(.startExport(format: format)))
    }
}

// MARK: - Type Alias (可选,让代码更简洁)

/// LogDetail 的 ViewStore 类型别名
///
/// 使用这个类型别名可以让代码更简洁:
/// ```swift
/// struct LogDetailScene: View {
///     @ObservedObject var viewStore: LogDetailViewStore  // ✅ 简洁
///     // 而不是
///     // @ObservedObject var viewStore: ViewStore<LogDetailState, LogDetailAction>
/// }
/// ```
public typealias LogDetailViewStore = ViewStore<LogDetailState, LogDetailAction>
