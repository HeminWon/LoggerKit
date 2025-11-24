//
//  LogRotation.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/21.
//

import Foundation

/// 日志轮转策略
public enum RotationPolicy: Sendable {
    case size(Int)           // 基于文件大小（字节）
    case time(TimeInterval)  // 基于时间（秒）
    case daily               // 每日轮转
    case never               // 不轮转
}

/// 日志轮转管理器
public final class LogRotationManager: Sendable {
    private let fileURL: URL
    private let policy: RotationPolicy
    private let maxFiles: Int

    public init(fileURL: URL, policy: RotationPolicy, maxFiles: Int = 10) {
        self.fileURL = fileURL
        self.policy = policy
        self.maxFiles = maxFiles
    }

    /// 检查是否需要轮转
    public func shouldRotate() -> Bool {
        switch policy {
        case .size(let maxSize):
            return checkSizeRotation(maxSize: maxSize)
        case .time(let interval):
            return checkTimeRotation(interval: interval)
        case .daily:
            return checkDailyRotation()
        case .never:
            return false
        }
    }

    /// 执行轮转
    public func rotate() throws {
        let fileManager = FileManager.default

        // 生成新文件名（添加时间戳）
        let rotatedURL = generateRotatedFileName()

        // 移动当前文件
        try fileManager.moveItem(at: fileURL, to: rotatedURL)

        // 清理旧文件
        try cleanupOldLogs()
    }

    private func checkSizeRotation(maxSize: Int) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? Int else {
            return false
        }
        return fileSize >= maxSize
    }

    private func checkTimeRotation(interval: TimeInterval) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(modificationDate) >= interval
    }

    private func checkDailyRotation() -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return false
        }
        let calendar = Calendar.current
        return !calendar.isDateInToday(modificationDate)
    }

    private func generateRotatedFileName() -> URL {
        let directory = fileURL.deletingLastPathComponent()
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let ext = fileURL.pathExtension
        let timestamp = DateFormatters.fileNameFormatter.string(from: Date())
        return directory.appendingPathComponent("\(baseName)_\(timestamp).\(ext)")
    }

    private func cleanupOldLogs() throws {
        let directory = fileURL.deletingLastPathComponent()
        let fileManager = FileManager.default

        // 获取所有日志文件
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.pathExtension == "log" }

        // 按创建日期排序（新 → 旧）
        let sortedFiles = try files.sorted {
            let date1 = try $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            let date2 = try $1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            return date1 > date2
        }

        // 删除超出限制的旧文件
        if sortedFiles.count > maxFiles {
            for file in sortedFiles[maxFiles...] {
                try fileManager.removeItem(at: file)
            }
        }
    }
}
