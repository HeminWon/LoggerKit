//
//  LogDatabaseManagerProtocol.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/12/15.
//

import Foundation
import CoreData

/// 日志数据库管理器协议
public protocol LogDatabaseManagerProtocol {
    /// 在指定的 context 中获取日志事件
    func fetchEvents(
        in context: NSManagedObjectContext?,
        levels: Set<LogEvent.Level>,
        functions: Set<String>,
        fileNames: Set<String>,
        contexts: Set<String>,
        threads: Set<String>,
        sessionId: String?,
        searchText: String,
        searchFields: Set<SearchField>,
        messageKeywords: Set<String>,
        sortDescriptors: [NSSortDescriptor],
        limit: Int,
        offset: Int
    ) throws -> [LogEvent]

    /// 获取指定日期的日志事件
    func fetchEvents(
        forDate date: String,
        levels: Set<LogEvent.Level>,
        sortDescriptors: [NSSortDescriptor],
        limit: Int,
        offset: Int
    ) throws -> [LogEvent]

    /// 获取统计信息
    func fetchStatistics() throws -> LogStatistics

    /// 统计符合条件的日志总数
    func countEvents(
        in context: NSManagedObjectContext?,
        levels: Set<LogEvent.Level>,
        functions: Set<String>,
        fileNames: Set<String>,
        contexts: Set<String>,
        threads: Set<String>,
        sessionId: String?,
        searchText: String,
        searchFields: Set<SearchField>,
        messageKeywords: Set<String>
    ) throws -> Int

    /// 获取指定字段的唯一值
    func fetchUniqueValues(for field: String) throws -> [String]

    /// 获取所有会话信息
    func fetchAllSessions() throws -> [SessionInfo]
}
