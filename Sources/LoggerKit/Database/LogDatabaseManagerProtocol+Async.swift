//
//  LogDatabaseManagerProtocol+Async.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - Async Adapter Extension

/// 异步适配器扩展 (为现有同步方法提供异步接口)
///
/// 此扩展为 LogDatabaseManagerProtocol 的同步方法提供异步包装器,
/// 使得 DeleteFeature 等 TCA Feature 可以使用现代的 async/await 语法,
/// 而无需修改现有的协议定义和实现。
///
/// 优势:
/// - ✅ 无需修改现有 Protocol 定义
/// - ✅ 通过扩展提供异步接口
/// - ✅ 向后兼容现有代码
/// - ✅ DeleteFeature 可直接使用异步方法
extension LogDatabaseManagerProtocol {
    /// 异步获取所有可用的会话信息 (适配器)
    ///
    /// 此方法包装了同步的 `fetchAllSessions()` 方法,在后台线程执行以避免阻塞主线程。
    ///
    /// - Returns: 会话信息数组
    /// - Throws: 数据库访问错误
    func getAvailableSessions() async throws -> [SessionInfo] {
        try await Task.detached(priority: .userInitiated) {
            try self.fetchAllSessions()
        }.value
    }

    /// 异步删除指定会话的所有日志 (适配器)
    ///
    /// 此方法包装了同步的 `deleteLogs(forSession:)` 方法,在后台线程执行以避免阻塞主线程。
    ///
    /// - Parameter sessionId: 要删除的会话 ID
    /// - Throws: 数据库访问错误或会话不存在错误
    func deleteSession(_ sessionId: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            try self.deleteLogs(forSession: sessionId)
        }.value
    }

    /// 异步批量删除多个会话 (适配器)
    ///
    /// 此方法包装了同步的 `deleteLogs(forSessions:)` 方法,在后台线程执行以避免阻塞主线程。
    ///
    /// - Parameter sessionIds: 要删除的会话 ID 数组
    /// - Throws: 数据库访问错误
    func deleteSessions(_ sessionIds: [String]) async throws {
        try await Task.detached(priority: .userInitiated) {
            try self.deleteLogs(forSessions: Set(sessionIds))
        }.value
    }
}
