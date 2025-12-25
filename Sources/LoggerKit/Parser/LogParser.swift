//
//  LogParser.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/9/10.
//

import Foundation
import SwiftUI

public extension LogEvent.Level {
    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .debug: return .primary
        case .verbose: return .gray
        case .critical: return .green
        case .fault: return .red
        }
    }
}

public struct LogEvent: Codable, Identifiable, Sendable {
    public var id = UUID()

    public enum Level: Int, Codable, Sendable {
        case verbose = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
        case critical = 5
        case fault = 6

        public var severity: String {
            switch self {
            case .verbose: return "VERBOSE"
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            case .critical: return "CRITICAL"
            case .fault: return "FAULT"
            }
        }

    }

    public let thread: String
    public let function: String
    public let line: Int
    public let file: String
    public let timestamp: TimeInterval
    public let level: Level
    public let message: String
    public let context: String
    public let sessionId: String
    public let sessionStartTime: TimeInterval

    enum CodingKeys: String, CodingKey {
        case thread, function, line, file, timestamp, level, message, context, sessionId, sessionStartTime
    }
    
    // 格式化日期显示
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: timestamp)
        return DateFormatters.displayFormatter.string(from: date)
    }

    // 会话显示文本
    var sessionDisplayText: String {
        let sessionDate = Date(timeIntervalSince1970: sessionStartTime)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "\(sessionId) (\(formatter.string(from: sessionDate)))"
    }
    
    var fileName: String {
        if let lastPart = file.components(separatedBy: "/").last,
           let fileName = lastPart.components(separatedBy: ".").first  {
            return fileName
        }
        return ""
    }
    
    // 自定义描述
    var description: String {
        return "[\(level.severity)] [\(formattedDate)] [\(thread)] \(message) (\(function) at \(fileName):\(line))"
    }
    
    var prefix: String {
        // 只显示前8位 sessionID
        let shortSessionId = String(sessionId.prefix(8))

        if thread.isEmpty {
            return "\(formattedDate) [\(shortSessionId)] [\(level.severity)] - (\(function) at \(fileName):\(line))"
        }
        return "\(formattedDate) [\(shortSessionId)] [\(level.severity)] <\(context)> \(thread) - (\(function) at \(fileName):\(line))"
    }
}

public struct LogParser {

    // MARK: - 流式导出 (推荐)

    /// 流式导出日志到临时文件 - 内存优化版本
    ///
    /// 使用分批查询和追加写入,避免全量内存加载,适用于大量日志导出场景。
    ///
    /// - Parameters:
    ///   - fileName: 导出文件名
    ///   - batchSize: 每批查询的日志数量,默认 1000 条
    ///   - progressHandler: 进度回调 (已导出条数, 总条数)
    ///   - eventFetcher: 分批获取日志的闭包 (offset, limit) -> [LogEvent]
    /// - Returns: 导出文件的 URL
    /// - Throws: 文件创建失败或查询错误
    ///
    /// 示例:
    /// ```swift
    /// let url = try await LogParser.logEventToTempFileStreaming(
    ///     fileName: "logs.txt",
    ///     progressHandler: { written, total in
    ///         print("进度: \(written)/\(total)")
    ///     },
    ///     eventFetcher: { offset, limit in
    ///         try await dataLoader.loadEvents(offset: offset, limit: limit)
    ///     }
    /// )
    /// ```
    public static func logEventToTempFileStreaming(
        fileName: String,
        batchSize: Int = 1000,
        progressHandler: @escaping (Int, Int) -> Void,
        eventFetcher: (Int, Int) async throws -> [LogEvent]
    ) async throws -> URL {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

        // 创建空文件
        guard FileManager.default.createFile(atPath: tempFile.path, contents: nil, attributes: nil) else {
            throw ExportError.fileCreationFailed
        }

        // 获取文件句柄
        guard let fileHandle = try? FileHandle(forWritingTo: tempFile) else {
            throw ExportError.fileHandleCreationFailed
        }

        // 确保资源释放
        defer {
            try? fileHandle.close()
        }

        var offset = 0
        var totalWritten = 0

        // 分批查询和写入
        while true {
            // 检查任务是否被取消
            if Task.isCancelled {
                try? FileManager.default.removeItem(at: tempFile)
                throw CancellationError()
            }

            // 获取当前批次数据
            let events = try await eventFetcher(offset, batchSize)
            if events.isEmpty { break }

            // 转换为字符串
            let lines = events.map { "\($0.prefix) - \($0.message)" }
            let text = lines.joined(separator: "\n") + "\n"

            // 追加写入文件
            if let data = text.data(using: .utf8) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                totalWritten += events.count

                // 更新进度 (在主线程回调)
                await MainActor.run {
                    progressHandler(totalWritten, -1)  // -1 表示总数未知,由调用方计算
                }
            }

            offset += batchSize
        }

        return tempFile
    }

}

// MARK: - 导出错误

public enum ExportError: Error {
    case fileCreationFailed
    case fileHandleCreationFailed
    case emptyData
}

extension ExportError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "文件创建失败"
        case .fileHandleCreationFailed:
            return "文件句柄创建失败"
        case .emptyData:
            return "没有可导出的日志数据"
        }
    }
}
