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
    ///   - searchText: 搜索文本
    ///   - offset: 分页偏移量
    ///   - limit: 每页数量
    /// - Returns: 日志事件数组
    func loadEvents(
        sessionId: String?,
        filterState: FilterState,
        searchText: String,
        offset: Int,
        limit: Int
    ) async throws -> [LogEvent]

    /// 加载统计信息
    /// - Returns: 日志统计信息
    func loadStatistics() async throws -> LogStatistics

    /// 取消当前加载任务
    func cancelCurrentTask()
}
