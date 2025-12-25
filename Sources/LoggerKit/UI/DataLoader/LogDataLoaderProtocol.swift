//
//  LogDataLoaderProtocol.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/12/15.
//

import Foundation

/// 日志数据加载器协议
@MainActor
public protocol LogDataLoaderProtocol {
    /// 加载日志事件
    /// - Parameters:
    ///   - sessionIds: 会话ID集合过滤
    ///   - filterState: 过滤状态
    ///   - offset: 分页偏移量
    ///   - limit: 每页数量
    /// - Returns: 日志事件数组
    func loadEvents(
        sessionIds: Set<String>,
        filterState: FilterFeature.State,
        offset: Int,
        limit: Int
    ) async throws -> [LogEvent]

    /// 加载统计信息
    /// - Returns: 日志统计信息
    func loadStatistics() async throws -> LogStatistics

    /// 统计符合条件的日志总数
    /// - Parameters:
    ///   - sessionIds: 会话ID集合过滤
    ///   - filterState: 过滤状态
    /// - Returns: 日志总数
    func countEvents(
        sessionIds: Set<String>,
        filterState: FilterFeature.State
    ) async throws -> Int

    /// 加载所有符合条件的日志事件(用于导出)
    /// - Parameters:
    ///   - sessionIds: 会话ID集合过滤
    ///   - filterState: 过滤状态
    /// - Returns: 所有符合条件的日志事件数组
    func loadAllEvents(
        sessionIds: Set<String>,
        filterState: FilterFeature.State
    ) async throws -> [LogEvent]

    /// 加载所有日志事件用于搜索预览(不应用任何过滤条件)
    /// - Parameters:
    ///   - sessionIds: 会话ID集合过滤
    ///   - limit: 查询数量限制
    /// - Returns: 日志事件数组
    func loadAllEventsForSearchPreview(
        sessionIds: Set<String>,
        limit: Int
    ) async throws -> [LogEvent]

    /// 取消当前加载任务
    func cancelCurrentTask()

    // MARK: - 筛选选项查询方法

    /// 获取所有可用的函数名
    func getAvailableFunctions() async throws -> [String]

    /// 获取所有可用的文件名
    func getAvailableFileNames() async throws -> [String]

    /// 获取所有可用的上下文
    func getAvailableContexts() async throws -> [String]

    /// 获取所有可用的线程名
    func getAvailableThreads() async throws -> [String]

    // MARK: - Deep Search Support

    /// 获取指定的 sessions（按时间排序）
    /// - Parameters:
    ///   - sessionIds: 要获取的 session IDs（如果为空，返回所有）
    ///   - sortOrder: 排序顺序
    /// - Returns: SessionInfo 数组
    func getSessions(
        sessionIds: Set<String>,
        sortOrder: LogDatabaseManager.SessionSortOrder
    ) async throws -> [SessionInfo]

    /// 在数据库层搜索日志事件
    /// - Parameters:
    ///   - sessionIds: 要搜索的 session IDs
    ///   - searchText: 搜索关键词
    ///   - searchFields: 搜索字段
    ///   - limit: 结果数量限制
    /// - Returns: 匹配的 LogEvent 数组（按时间倒序）
    func searchEvents(
        sessionIds: Set<String>,
        searchText: String,
        searchFields: Set<SearchField>,
        limit: Int
    ) async throws -> [LogEvent]
}
