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
        sessionIds: Set<String>,
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

    /// 查询所有日志事件用于搜索预览
    func fetchAllEventsForSearchPreview(
        in context: NSManagedObjectContext?,
        sessionIds: Set<String>,
        limit: Int
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
        sessionIds: Set<String>,
        messageKeywords: Set<String>
    ) throws -> Int

    /// 获取指定字段的唯一值
    func fetchUniqueValues(for field: String) throws -> [String]

    /// 获取所有会话信息
    func fetchAllSessions() throws -> [SessionInfo]

    // MARK: - 筛选选项查询接口

    /// 获取所有可用的函数名
    func fetchAvailableFunctions() throws -> [String]

    /// 获取所有可用的文件名
    func fetchAvailableFileNames() throws -> [String]

    /// 获取所有可用的上下文
    func fetchAvailableContexts() throws -> [String]

    /// 获取所有可用的线程名
    func fetchAvailableThreads() throws -> [String]

    // MARK: - 删除接口

    /// 删除所有日志
    func deleteAllLogs() async throws

    /// 删除指定日期的日志
    func deleteLogs(forDate date: String) async throws

    /// 删除指定时间之前的日志
    func deleteLogs(before date: Date) async throws

    /// 删除指定会话的所有日志
    func deleteLogs(forSession sessionId: String) async throws

    /// 删除多个会话的日志
    func deleteLogs(forSessions sessionIds: Set<String>) async throws

    // MARK: - 辅助接口

    /// 获取数据库文件大小
    func databaseSize() -> Int64

    // MARK: - Deep Search Support

    /// 获取指定的 sessions（按时间排序）
    func getSessions(
        in context: NSManagedObjectContext?,
        sessionIds: Set<String>,
        sortOrder: LogDatabaseManager.SessionSortOrder
    ) throws -> [SessionInfo]

    /// 在数据库层搜索日志事件
    func searchEvents(
        in context: NSManagedObjectContext?,
        sessionIds: Set<String>,
        searchText: String,
        searchFields: [String],
        limit: Int
    ) throws -> [LogEvent]
}
