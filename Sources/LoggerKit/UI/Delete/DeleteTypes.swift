//
//  DeleteTypes.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - Session Info Extension

/// SessionInfo 扩展 (复用现有定义，避免类型冲突)
///
/// 现有定义位于 LogDatabaseManager.swift:
/// ```
/// public struct SessionInfo: Identifiable, Hashable {
///     public let id: String
///     public let startTime: TimeInterval
///     public let logCount: Int
/// }
/// ```
extension SessionInfo: @unchecked Sendable {
    // SessionInfo 已实现 Identifiable, Hashable
    // 通过此扩展补充 Sendable 支持
    // 使用 @unchecked 因为这是在不同源文件中的追溯遵循
}

extension SessionInfo {
    /// Session creation date (从 startTime 计算)
    public var createdAt: Date {
        Date(timeIntervalSince1970: startTime)
    }

    /// Number of events (别名，兼容 DeleteFeature 命名)
    public var eventCount: Int {
        logCount
    }

    /// Formatted event count (e.g., "1,234 events")
    public var formattedEventCount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let countStr = formatter.string(from: NSNumber(value: logCount)) ?? "\(logCount)"
        return "\(countStr) events"
    }

    /// Formatted creation date
    public var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Estimated session size in bytes (可选功能)
    /// 注意: 需要额外实现大小计算，默认返回 0
    public var estimatedSize: Int64 {
        // TODO: 实现异步大小计算
        // 可在 UI 层异步查询每个 session 的大小
        return 0
    }

    /// Formatted session size (e.g., "1.2 MB")
    public var formattedSize: String {
        guard estimatedSize > 0 else {
            return "Unknown"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: estimatedSize)
    }
}

// MARK: - Delete Error

/// Delete-related errors
public enum DeleteError: Error, LocalizedError, Equatable {
    case loadingSessionsFailed
    case noSessionsSelected
    case deletionFailed
    case sessionNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .loadingSessionsFailed:
            return String(localized: "delete_load_sessions_failed", bundle: .module)
        case .noSessionsSelected:
            return String(localized: "delete_no_sessions_selected", bundle: .module)
        case .deletionFailed:
            return String(localized: "delete_operation_failed", bundle: .module)
        case .sessionNotFound(let sessionId):
            return String(localized: "delete_session_not_found", bundle: .module).replacingOccurrences(of: "%@", with: sessionId)
        }
    }
}

// MARK: - Delete Statistics

/// Delete statistics (用于 UI 展示)
public struct DeleteStatistics: Equatable, Sendable {
    /// Total number of sessions before deletion
    public let totalSessions: Int

    /// Number of sessions selected for deletion
    public let selectedSessions: Int

    /// Total size of selected sessions (in bytes)
    public let totalSize: Int64

    /// Formatted total size
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    public init(totalSessions: Int, selectedSessions: Int, totalSize: Int64) {
        self.totalSessions = totalSessions
        self.selectedSessions = selectedSessions
        self.totalSize = totalSize
    }
}
