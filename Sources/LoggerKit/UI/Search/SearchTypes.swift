//
//  SearchTypes.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - Search Field

/// Fields that can be searched
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
            return String(localized: "search_field_message", bundle: .loggerKit)
        case .fileName:
            return String(localized: "search_field_file", bundle: .loggerKit)
        case .function:
            return String(localized: "search_field_function", bundle: .loggerKit)
        case .context:
            return String(localized: "search_field_context", bundle: .loggerKit)
        case .thread:
            return String(localized: "search_field_thread", bundle: .loggerKit)
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

// MARK: - Search Result Item

/// Single search result item (suggestion)
public struct SearchResultItem: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let field: SearchField
    public let value: String
    public let matchCount: Int

    public init(field: SearchField, value: String, matchCount: Int) {
        self.field = field
        self.value = value
        self.matchCount = matchCount
    }

    // Equatable: 比较时忽略 id
    public static func == (lhs: SearchResultItem, rhs: SearchResultItem) -> Bool {
        return lhs.field == rhs.field &&
            lhs.value == rhs.value &&
            lhs.matchCount == rhs.matchCount
    }
}

// MARK: - Categorized Search Results

/// Categorized search results (suggestions grouped by field)
public struct CategorizedSearchResults: Equatable, Sendable {
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

// MARK: - Search Snapshot

/// 搜索快照 - 保证整个搜索过程的数据一致性
public struct SearchSnapshot: Equatable, Sendable {
    /// 快照时的搜索关键词
    let searchText: String

    /// 快照时的搜索字段
    let searchFields: Set<SearchField>

    /// 快照时选中的 session IDs
    let selectedSessionIds: Set<String>

    /// 快照时所有可用的 session IDs
    let allAvailableSessionIds: Set<String>

    /// 所有需要搜索的 sessions（按时间倒序）
    let allSessions: [SessionInfo]

    /// Preview 的 sessions（前 N 个）
    let previewSessions: [SessionInfo]

    /// Full Search 的 sessions（剩余的）
    let fullSearchSessions: [SessionInfo]

    /// 快照创建时间
    let createdAt: Date

    /// 预估总日志数（用于进度计算）
    let estimatedTotalEvents: Int

    public init(
        searchText: String,
        searchFields: Set<SearchField>,
        selectedSessionIds: Set<String>,
        allAvailableSessionIds: Set<String>,
        allSessions: [SessionInfo],
        previewSessions: [SessionInfo],
        fullSearchSessions: [SessionInfo],
        createdAt: Date
    ) {
        self.searchText = searchText
        self.searchFields = searchFields
        self.selectedSessionIds = selectedSessionIds
        self.allAvailableSessionIds = allAvailableSessionIds
        self.allSessions = allSessions
        self.previewSessions = previewSessions
        self.fullSearchSessions = fullSearchSessions
        self.createdAt = createdAt

        // 计算预估总日志数
        self.estimatedTotalEvents = fullSearchSessions.reduce(0) { $0 + $1.eventCount }
    }
}

// MARK: - Search Phase

/// 搜索状态机
public enum SearchPhase: Equatable, Sendable {
    /// 空闲 - 未搜索
    case idle

    /// 正在输入 - 等待用户停止输入（不执行查询）
    case typing

    /// 输入预览 - 搜索最新的 N 个 session
    /// - sessionCount: 预览的 session 数量
    case previewSearching(sessionCount: Int)

    /// 预览完成 - 等待用户决定是否搜索更多
    /// - matchCount: 预览找到的匹配数
    /// - searchedSessions: 已搜索的 session 数
    /// - hasMoreSessions: 是否还有更多 session 可搜索
    case previewCompleted(matchCount: Int, searchedSessions: Int, hasMoreSessions: Bool)

    /// 完整搜索中 - 批量扫描日志
    /// - scannedEvents: 已扫描的日志事件数量
    /// - totalEstimatedEvents: 预估总日志事件数量
    /// - matchCount: 已找到的匹配数量
    case fullSearching(
        scannedEvents: Int,
        totalEstimatedEvents: Int,
        matchCount: Int
    )

    /// 搜索完成
    /// - totalMatches: 总匹配数
    /// - searchedSessions: 搜索的 session 数量
    case completed(totalMatches: Int, searchedSessions: Int)

    /// 搜索取消
    case cancelled

    /// 搜索失败
    /// - message: 错误信息
    case failed(message: String)

    /// 结果过多，需要优化关键词
    /// - currentCount: 当前结果数
    /// - limit: 限制数量
    case tooManyResults(currentCount: Int, limit: Int)
}
