//
//  LogDatabaseError.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025-12-17.
//

import Foundation

/// 日志数据库操作错误类型
public enum LogDatabaseError: LocalizedError {
    /// 数据库不可用
    case databaseNotAvailable

    /// 删除操作失败
    case deleteFailed(underlying: Error)

    /// 会话未找到
    case sessionNotFound(String)

    /// 参数无效
    case invalidParameter(String)

    public var errorDescription: String? {
        switch self {
        case .databaseNotAvailable:
            return "数据库不可用"
        case .deleteFailed(let error):
            return "删除失败: \(error.localizedDescription)"
        case .sessionNotFound(let sessionId):
            return "会话 \(sessionId) 不存在"
        case .invalidParameter(let message):
            return "参数错误: \(message)"
        }
    }
}
