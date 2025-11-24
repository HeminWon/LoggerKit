//
//  MockLogger.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/21.
//

import Foundation

/// 用于测试的 Mock Logger
public final class MockLogger: LoggerProtocol, @unchecked Sendable {
    public struct LogCall: Sendable {
        public let level: String
        public let message: String
        public let file: String
        public let function: String
        public let line: Int
        public let timestamp: Date
    }

    private var _calls: [LogCall] = []
    private let queue = DispatchQueue(label: "mock.logger.queue")

    /// 获取所有日志调用记录
    public var calls: [LogCall] {
        queue.sync { _calls }
    }

    public init() {}

    public func verbose(_ message: String, file: String, function: String, line: Int) {
        record(level: "VERBOSE", message: message, file: file, function: function, line: line)
    }

    public func debug(_ message: String, file: String, function: String, line: Int) {
        record(level: "DEBUG", message: message, file: file, function: function, line: line)
    }

    public func info(_ message: String, file: String, function: String, line: Int) {
        record(level: "INFO", message: message, file: file, function: function, line: line)
    }

    public func warning(_ message: String, file: String, function: String, line: Int) {
        record(level: "WARNING", message: message, file: file, function: function, line: line)
    }

    public func error(_ message: String, file: String, function: String, line: Int) {
        record(level: "ERROR", message: message, file: file, function: function, line: line)
    }

    private func record(level: String, message: String, file: String, function: String, line: Int) {
        queue.sync {
            _calls.append(LogCall(
                level: level,
                message: message,
                file: file,
                function: function,
                line: line,
                timestamp: Date()
            ))
        }
    }

    /// 验证是否记录了特定日志
    public func verify(level: String, message: String) -> Bool {
        queue.sync {
            _calls.contains { $0.level == level && $0.message == message }
        }
    }

    /// 验证是否包含特定消息（不限级别）
    public func containsMessage(_ message: String) -> Bool {
        queue.sync {
            _calls.contains { $0.message == message }
        }
    }

    /// 获取特定级别的所有日志
    public func calls(forLevel level: String) -> [LogCall] {
        queue.sync {
            _calls.filter { $0.level == level }
        }
    }

    /// 重置记录
    public func reset() {
        queue.sync {
            _calls.removeAll()
        }
    }

    /// 最后一条日志记录
    public var lastCall: LogCall? {
        queue.sync { _calls.last }
    }

    /// 日志调用次数
    public var callCount: Int {
        queue.sync { _calls.count }
    }
}
