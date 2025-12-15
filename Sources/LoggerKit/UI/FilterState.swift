//
//  FilterState.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/12/15.
//

import SwiftUI
import Combine

/// 过滤项枚举
public enum FilterItem {
    case function(String)
    case fileName(String)
    case context(String)
    case thread(String)
    case messageKeyword(String)
}

/// 过滤状态管理器 - 统一管理所有过滤条件
@MainActor
public class FilterState: ObservableObject {

    // MARK: - Published 过滤字段

    @Published public var selectedLevels: Set<LogEvent.Level> = [.verbose, .debug, .info, .warning, .error]
    @Published public var selectedFunctions: Set<String> = []
    @Published public var selectedFileNames: Set<String> = []
    @Published public var selectedContexts: Set<String> = []
    @Published public var selectedThreads: Set<String> = []
    @Published public var selectedMessageKeywords: Set<String> = []
    @Published public var selectedSessionId: String? = nil

    // MARK: - 回调机制

    /// 过滤条件变化时的回调
    public var onFilterChanged: (() -> Void)?

    // MARK: - 私有属性

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    public init() {
        setupBindings()
    }

    // MARK: - 绑定设置

    private func setupBindings() {
        // 监听所有过滤字段的变化
        Publishers.MergeMany(
            $selectedLevels.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $selectedFunctions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $selectedFileNames.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $selectedContexts.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $selectedThreads.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $selectedMessageKeywords.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $selectedSessionId.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.onFilterChanged?()
        }
        .store(in: &cancellables)
    }

    // MARK: - 计算属性

    /// 激活的过滤器数量
    public var activeFilterCount: Int {
        var count = 0
        if !selectedFunctions.isEmpty { count += 1 }
        if !selectedFileNames.isEmpty { count += 1 }
        if !selectedContexts.isEmpty { count += 1 }
        if !selectedThreads.isEmpty { count += 1 }
        if !selectedMessageKeywords.isEmpty { count += 1 }
        if selectedSessionId != nil { count += 1 }
        return count
    }

    // MARK: - 过滤器操作方法

    /// 重置所有过滤条件
    public func resetFilters() {
        selectedLevels = [.verbose, .debug, .info, .warning, .error]
        selectedFunctions = []
        selectedFileNames = []
        selectedContexts = []
        selectedThreads = []
        selectedMessageKeywords = []
        selectedSessionId = nil
    }

    /// 检查项是否在过滤器中
    public func isInFilter(_ item: FilterItem) -> Bool {
        switch item {
        case .function(let value):
            return selectedFunctions.contains(value)
        case .fileName(let value):
            return selectedFileNames.contains(value)
        case .context(let value):
            return selectedContexts.contains(value)
        case .thread(let value):
            return selectedThreads.contains(value)
        case .messageKeyword(let value):
            return selectedMessageKeywords.contains(value)
        }
    }

    /// 添加项到过滤器
    public func addToFilter(_ item: FilterItem) {
        switch item {
        case .function(let value):
            selectedFunctions.insert(value)
        case .fileName(let value):
            selectedFileNames.insert(value)
        case .context(let value):
            selectedContexts.insert(value)
        case .thread(let value):
            selectedThreads.insert(value)
        case .messageKeyword(let value):
            selectedMessageKeywords.insert(value)
        }
    }

    /// 从过滤器中移除项
    public func removeFromFilter(_ item: FilterItem) {
        switch item {
        case .function(let value):
            selectedFunctions.remove(value)
        case .fileName(let value):
            selectedFileNames.remove(value)
        case .context(let value):
            selectedContexts.remove(value)
        case .thread(let value):
            selectedThreads.remove(value)
        case .messageKeyword(let value):
            selectedMessageKeywords.remove(value)
        }
    }

    /// 切换过滤器状态
    public func toggleFilter(_ item: FilterItem) {
        if isInFilter(item) {
            removeFromFilter(item)
        } else {
            addToFilter(item)
        }
    }

    /// 切换日志级别
    public func toggleLevel(_ level: LogEvent.Level) {
        if selectedLevels.contains(level) {
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
    }
}
