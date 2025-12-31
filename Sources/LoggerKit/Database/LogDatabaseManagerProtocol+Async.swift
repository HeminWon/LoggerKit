//
//  LogDatabaseManagerProtocol+Async.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - Async Convenience Extension

/// 便捷异步方法扩展
///
/// 此扩展为 LogDatabaseManagerProtocol 提供便捷的异步方法,
/// 使得 DeleteFeature 等 TCA Feature 可以使用语义化的方法名。
extension LogDatabaseManagerProtocol {
    /// 异步获取所有可用的会话信息
    ///
    /// - Returns: 会话信息数组
    /// - Throws: 数据库访问错误
    func getAvailableSessions() async throws -> [SessionInfo] {
        try await Task.detached(priority: .userInitiated) {
            try self.fetchAllSessions()
        }.value
    }

    /// 异步删除指定会话的所有日志
    ///
    /// - Parameter sessionId: 要删除的会话 ID
    /// - Throws: 数据库访问错误或会话不存在错误
    func deleteSession(_ sessionId: String) async throws {
        try await self.deleteLogs(forSession: sessionId)
    }

    /// 异步批量删除多个会话
    ///
    /// - Parameter sessionIds: 要删除的会话 ID 数组
    /// - Throws: 数据库访问错误
    func deleteSessions(_ sessionIds: [String]) async throws {
        try await self.deleteLogs(forSessions: Set(sessionIds))
    }
}
