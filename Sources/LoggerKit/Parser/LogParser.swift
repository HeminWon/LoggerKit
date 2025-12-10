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
        if thread.isEmpty {
            return "\(formattedDate) [\(level.severity)] - (\(function) at \(fileName):\(line))"
        }
        return "\(formattedDate) [\(level.severity)] <\(context)> \(thread) - (\(function) at \(fileName):\(line))"
    }
}

public struct LogParser {

    // LogEvent to temp file 格式化后的 log
    public static func logEventToTempFile(fileName: String, events: [LogEvent]) -> URL {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        let lines = events.map { "\($0.prefix) - \($0.message)" }.joined(separator: "\n")
        try? lines.write(to: tempFile, atomically: true, encoding: .utf8)
        return tempFile
    }
}
