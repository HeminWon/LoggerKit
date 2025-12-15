//
//  SearchState.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/12/15.
//

import SwiftUI
import Combine

/// 搜索状态管理器 - 统一管理搜索逻辑
@MainActor
public class SearchState: ObservableObject {

    // MARK: - Published 属性

    @Published public var searchText: String = ""
    @Published public var searchFields: Set<SearchField> = [.message, .fileName, .function]

    // MARK: - 回调机制

    /// 搜索条件变化时的回调
    public var onSearchChanged: (() -> Void)?

    // MARK: - 私有属性

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    public init() {
        setupBindings()
    }

    // MARK: - 绑定设置

    private func setupBindings() {
        // 监听搜索条件的变化
        Publishers.MergeMany(
            $searchText.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $searchFields.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.onSearchChanged?()
        }
        .store(in: &cancellables)
    }

    // MARK: - 搜索方法

    /// 切换搜索字段
    public func toggleSearchField(_ field: SearchField) {
        if searchFields.contains(field) {
            searchFields.remove(field)
        } else {
            searchFields.insert(field)
        }
    }

    /// 计算搜索结果 - 单次遍历优化版本
    /// - Parameters:
    ///   - events: 要搜索的事件列表
    ///   - functionCounts: 函数计数字典
    ///   - fileNameCounts: 文件名计数字典
    ///   - contextCounts: 上下文计数字典
    ///   - threadCounts: 线程计数字典
    /// - Returns: 分类搜索结果
    public func computeResults(
        from events: [LogEvent],
        functionCounts: [String: Int],
        fileNameCounts: [String: Int],
        contextCounts: [String: Int],
        threadCounts: [String: Int]
    ) -> CategorizedSearchResults {
        guard !searchText.isEmpty else { return CategorizedSearchResults() }

        let lowercasedSearch = searchText.lowercased()
        var results = CategorizedSearchResults()

        // 用于去重和计数
        var messageSet = Set<String>()
        var fileNameSet = Set<String>()
        var functionSet = Set<String>()
        var contextSet = Set<String>()
        var threadSet = Set<String>()

        // 单次遍历收集所有匹配项
        for event in events {
            // 消息匹配 (只取前5个)
            if searchFields.contains(.message) && results.message.count < 5 {
                if event.message.lowercased().contains(lowercasedSearch) {
                    if !messageSet.contains(event.message) {
                        messageSet.insert(event.message)
                        results.message.append(
                            SearchResultItem(field: .message, value: event.message, matchCount: 1)
                        )
                    }
                }
            }

            // 文件名匹配
            if searchFields.contains(.fileName) {
                if event.fileName.lowercased().contains(lowercasedSearch) {
                    fileNameSet.insert(event.fileName)
                }
            }

            // 函数匹配
            if searchFields.contains(.function) {
                if event.function.lowercased().contains(lowercasedSearch) {
                    functionSet.insert(event.function)
                }
            }

            // 上下文匹配
            if searchFields.contains(.context) {
                if !event.context.isEmpty && event.context.lowercased().contains(lowercasedSearch) {
                    contextSet.insert(event.context)
                }
            }

            // 线程匹配
            if searchFields.contains(.thread) {
                if !event.thread.isEmpty && event.thread.lowercased().contains(lowercasedSearch) {
                    threadSet.insert(event.thread)
                }
            }
        }

        // 构建文件名结果
        results.fileName = fileNameSet.sorted().map { fileName in
            let count = fileNameCounts[fileName] ?? 0
            return SearchResultItem(field: .fileName, value: fileName, matchCount: count)
        }

        // 构建函数结果
        results.function = functionSet.sorted().map { function in
            let count = functionCounts[function] ?? 0
            return SearchResultItem(field: .function, value: function, matchCount: count)
        }

        // 构建上下文结果
        results.context = contextSet.sorted().map { context in
            let count = contextCounts[context] ?? 0
            return SearchResultItem(field: .context, value: context, matchCount: count)
        }

        // 构建线程结果
        results.thread = threadSet.sorted().map { thread in
            let count = threadCounts[thread] ?? 0
            return SearchResultItem(field: .thread, value: thread, matchCount: count)
        }

        return results
    }
}
