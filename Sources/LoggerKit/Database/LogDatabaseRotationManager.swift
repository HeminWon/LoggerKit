//
//  LogDatabaseRotationManager.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025/11/25.
//

import Foundation
import CoreData

public final class LogDatabaseRotationManager {

    private let databaseManager: LogDatabaseManager
    private let maxDatabaseSize: Int64
    private let maxRetentionDays: Int

    public init(
        databaseManager: LogDatabaseManager,
        maxDatabaseSize: Int64 = 100 * 1024 * 1024, // 100MB
        maxRetentionDays: Int = 30
    ) {
        self.databaseManager = databaseManager
        self.maxDatabaseSize = maxDatabaseSize
        self.maxRetentionDays = maxRetentionDays
    }

    /// 执行轮转检查
    public func performRotationIfNeeded() {
        let currentSize = databaseManager.databaseSize()

        if currentSize > maxDatabaseSize {
            // 删除旧数据
            let cutoffDate = Calendar.current.date(
                byAdding: .day,
                value: -maxRetentionDays,
                to: Date()
            )!

            do {
                try databaseManager.deleteLogs(before: cutoffDate)
                print("✅ Database rotation completed. Size: \(currentSize / 1024)KB -> \(databaseManager.databaseSize() / 1024)KB")
            } catch {
                print("❌ Database rotation failed: \(error)")
            }
        }
    }

    /// 清理过期日志
    public func cleanupExpiredLogs() {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -maxRetentionDays,
            to: Date()
        )!

        do {
            try databaseManager.deleteLogs(before: cutoffDate)
            print("✅ Expired logs cleaned up (before \(cutoffDate))")
        } catch {
            print("❌ Cleanup failed: \(error)")
        }
    }
}
