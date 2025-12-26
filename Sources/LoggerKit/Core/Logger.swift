//
//  Logger.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/9/5.
//

import Foundation

/// 轻量级日志接口
///
/// Logger 是一个轻量级的值类型，可以随意创建多个实例。
/// 所有实例共享同一个底层 `LoggerEngine`，写入同一个日志文件。
///
/// 使用示例：
/// ```swift
/// // App 启动时配置引擎
/// LoggerEngine.configure(LoggerEngineConfiguration(
///     level: .debug,
///     enableConsole: true,
///     enableFile: true
/// ))
///
/// // 创建带 context 的 logger
/// let networkLogger = Logger(context: "Network")
/// networkLogger.info("Request sent")  // [Network] Request sent
///
/// // 创建默认 logger（context 自动从文件路径提取）
/// let logger = Logger()
/// logger.debug("Hello")  // [ModuleName] Hello
/// ```
public struct Logger: LoggerProtocol, Sendable {

    /// 日志上下文标识（如模块名）
    /// 如果为 nil，则从调用处的文件路径自动提取
    private let context: String?

    /// 创建 Logger 实例
    /// - Parameter context: 日志上下文标识。如果不传，则自动从文件路径提取模块名
    public init(context: String? = nil) {
        self.context = context
        #if DEBUG
        // 如果未配置日志引擎，则直接 crash
        assert(LoggerEngine.isConfigured, "Logger initialized without configuring LoggerEngine")
        #endif
    }

    // MARK: - LoggerProtocol

    public func verbose(_ message: String,  file: String = #file, function: String = #function, line: Int = #line) {
        LoggerEngine.shared.verbose(message, file: file, function: function, line: line, context: context)
    }

    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        LoggerEngine.shared.debug(message, file: file, function: function, line: line, context: context)
    }

    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        LoggerEngine.shared.info(message, file: file, function: function, line: line, context: context)
    }

    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        LoggerEngine.shared.warning(message, file: file, function: function, line: line, context: context)
    }

    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        LoggerEngine.shared.error(message, file: file, function: function, line: line, context: context)
    }
}

// MARK: - 便捷方法

public extension Logger {
    /// 执行数据库轮转检查
    static func performDatabaseRotation() {
        LoggerEngine.shared.performDatabaseRotation()
    }

    /// 清理过期日志
    static func cleanupExpiredLogs() {
        LoggerEngine.shared.cleanupExpiredLogs()
    }

    /// 刷新日志缓冲
    static func flush() {
        LoggerEngine.shared.flush()
    }

    /// 获取数据库管理器
    static func getDatabaseManager() -> LogDatabaseManager? {
        return LoggerEngine.shared.getDatabaseManager()
    }
}
