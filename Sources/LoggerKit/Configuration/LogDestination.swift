//
//  LogDestination.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/21.
//

import Foundation

/// 日志写入事件（用于 LogDestination 写入）
public struct LogWriteEvent: Sendable {
    public let timestamp: TimeInterval
    public let level: LogLevel
    public let message: String
    public let file: String
    public let function: String
    public let line: Int
    public let context: String
    public let thread: String

    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        level: LogLevel,
        message: String,
        file: String,
        function: String,
        line: Int,
        context: String,
        thread: String = Thread.current.name ?? "unknown"
    ) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.file = file
        self.function = function
        self.line = line
        self.context = context
        self.thread = thread
    }
}

/// 日志输出目标抽象
public protocol LogDestination: Sendable {
    func write(_ event: LogWriteEvent)
    func flush()
}

/// 日志格式化器
public struct LogFormatter: Sendable {
    public let format: @Sendable (LogWriteEvent) -> String

    public init(format: @escaping @Sendable (LogWriteEvent) -> String) {
        self.format = format
    }

    /// 默认格式化器
    public static let `default` = LogFormatter { event in
        let date = DateFormatters.displayFormatter.string(from: Date(timeIntervalSince1970: event.timestamp))
        let levelStr = levelString(event.level)
        let fileName = (event.file as NSString).lastPathComponent
        return "\(date) [\(levelStr)] <\(event.context)> \(event.thread) [\(fileName).\(event.function):\(event.line)] - \(event.message)"
    }

    /// JSON 格式化器
    public static let json = LogFormatter { event in
        let dict: [String: Any] = [
            "timestamp": event.timestamp,
            "level": event.level.rawValue,
            "message": event.message,
            "file": event.file,
            "function": event.function,
            "line": event.line,
            "context": event.context,
            "thread": event.thread
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    private static func levelString(_ level: LogLevel) -> String {
        switch level {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}

/// 控制台输出
public final class ConsoleLogDestination: LogDestination, @unchecked Sendable {
    private let formatter: LogFormatter
    private let minLevel: LogLevel

    public init(formatter: LogFormatter = .default, minLevel: LogLevel = .debug) {
        self.formatter = formatter
        self.minLevel = minLevel
    }

    public func write(_ event: LogWriteEvent) {
        guard event.level.rawValue >= minLevel.rawValue else { return }
        print(formatter.format(event))
    }

    public func flush() {
        // Console auto-flushes
    }
}

/// 文件输出（支持轮转）
public final class FileLogDestination: LogDestination, @unchecked Sendable {
    private let fileURL: URL
    private let formatter: LogFormatter
    private let minLevel: LogLevel
    private let rotationPolicy: RotationPolicy
    private let queue = DispatchQueue(label: "com.loggerkit.file", qos: .background)
    private var fileHandle: FileHandle?

    public init(
        fileURL: URL,
        formatter: LogFormatter = .json,
        minLevel: LogLevel = .debug,
        rotationPolicy: RotationPolicy = .size(10 * 1024 * 1024) // 10MB
    ) {
        self.fileURL = fileURL
        self.formatter = formatter
        self.minLevel = minLevel
        self.rotationPolicy = rotationPolicy

        // 确保文件存在
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    public func write(_ event: LogWriteEvent) {
        guard event.level.rawValue >= minLevel.rawValue else { return }

        queue.async { [weak self] in
            self?.writeSync(event)
        }
    }

    private func writeSync(_ event: LogWriteEvent) {
        let line = formatter.format(event) + "\n"
        guard let data = line.data(using: .utf8) else { return }

        do {
            if fileHandle == nil {
                fileHandle = try FileHandle(forWritingTo: fileURL)
            }
            fileHandle?.seekToEndOfFile()
            fileHandle?.write(data)
        } catch {
            // 尝试重新创建文件
            FileManager.default.createFile(atPath: fileURL.path, contents: data)
        }
    }

    public func flush() {
        queue.sync {
            try? fileHandle?.synchronize()
        }
    }

    deinit {
        try? fileHandle?.close()
    }
}
