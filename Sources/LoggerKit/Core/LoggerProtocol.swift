//
//  LoggerProtocol.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/21.
//

import Foundation
import SwiftyBeaver

/// 日志级别
public enum LogLevel: Int, Sendable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4

    /// 转换为 SwiftyBeaver 日志级别
    var swiftyBeaverLevel: SwiftyBeaver.Level {
        switch self {
        case .verbose: return .verbose
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }
}

/// 日志协议，支持依赖注入和 Mock
public protocol LoggerProtocol: Sendable {
    func verbose(_ message: String, file: String, function: String, line: Int)
    func debug(_ message: String, file: String, function: String, line: Int)
    func info(_ message: String, file: String, function: String, line: Int)
    func warning(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, file: String, function: String, line: Int)
}

/// 默认参数扩展，简化调用
public extension LoggerProtocol {
    func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        verbose(message, file: file, function: function, line: line)
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        warning(message, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message, file: file, function: function, line: line)
    }
}
