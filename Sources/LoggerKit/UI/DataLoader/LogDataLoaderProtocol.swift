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
    ///   - sessionId: 会话ID过滤
    ///   - filterState: 过滤状态
    ///   - offset: 分页偏移量
    ///   - limit: 每页数量
    /// - Returns: 日志事件数组
    func loadEvents(
        sessionId: String?,
        filterState: FilterState,
        offset: Int,
        limit: Int
    ) async throws -> [LogEvent]

    /// 加载统计信息
    /// - Returns: 日志统计信息
    func loadStatistics() async throws -> LogStatistics

    /// 统计符合条件的日志总数
    /// - Parameters:
    ///   - sessionId: 会话ID过滤
    ///   - filterState: 过滤状态
    /// - Returns: 日志总数
    func countEvents(
        sessionId: String?,
        filterState: FilterState
    ) async throws -> Int

    /// 加载所有符合条件的日志事件(用于导出)
    /// - Parameters:
    ///   - sessionId: 会话ID过滤
    ///   - filterState: 过滤状态
    /// - Returns: 所有符合条件的日志事件数组
    func loadAllEvents(
        sessionId: String?,
        filterState: FilterState
    ) async throws -> [LogEvent]

    /// 加载所有日志事件用于搜索预览(不应用任何过滤条件)
    /// - Parameters:
    ///   - sessionId: 会话ID过滤
    ///   - limit: 查询数量限制
    /// - Returns: 日志事件数组
    func loadAllEventsForSearchPreview(
        sessionId: String?,
        limit: Int
    ) async throws -> [LogEvent]

    /// 取消当前加载任务
    func cancelCurrentTask()
}
