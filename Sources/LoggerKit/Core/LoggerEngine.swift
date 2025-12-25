//
//  LoggerEngine.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/24.
//

import Foundation
import SwiftyBeaver

/// 日志引擎配置
public struct LoggerEngineConfiguration: Sendable {
    public let level: LogLevel
    public let enableConsole: Bool
    public let enableDatabase: Bool
    public let maxDatabaseSize: Int64
    public let maxRetentionDays: Int

    // MARK: - 日志写入策略配置

    /// 批量写入大小（达到此数量立即写入）
    public let batchSize: Int

    /// 防抖延迟（秒）- 日志停止后延迟写入的时间
    public let debounceInterval: TimeInterval

    /// 立即写入的日志级别（这些级别的日志会绕过批量和防抖，立即写入）
    public let immediateFlushLevels: Set<LogEvent.Level>

    public init(
        level: LogLevel = .debug,
        enableConsole: Bool = true,
        enableDatabase: Bool = true,
        maxDatabaseSize: Int64 = 100 * 1024 * 1024, // 100MB
        maxRetentionDays: Int = 30,
        batchSize: Int = 50,
        debounceInterval: TimeInterval = 2.0,
        immediateFlushLevels: Set<LogEvent.Level> = [.error, .warning]
    ) {
        self.level = level
        self.enableConsole = enableConsole
        self.enableDatabase = enableDatabase
        self.maxDatabaseSize = maxDatabaseSize
        self.maxRetentionDays = maxRetentionDays
        self.batchSize = batchSize
        self.debounceInterval = debounceInterval
        self.immediateFlushLevels = immediateFlushLevels
    }

}

/// 日志引擎单例，管理底层资源
public final class LoggerEngine: @unchecked Sendable {

    /// 共享实例
    public static let shared = LoggerEngine()

    private let swiftyBeaver: SwiftyBeaver.Type
    private var coreDataDestination: CoreDataDestination?
    private var databaseManager: LogDatabaseManager?
    private var rotationManager: LogDatabaseRotationManager?
    private let moduleCache: ConcurrentCache<String, String>
    private var isConfigured = false
    private let lock = NSLock()

    // 会话管理
    public let sessionId: String
    public let sessionStartTime: TimeInterval

    private init() {
        self.swiftyBeaver = SwiftyBeaver.self
        self.moduleCache = ConcurrentCache()
        // 生成会话ID（UUID前8位）
        self.sessionId = String(UUID().uuidString.prefix(8))
        self.sessionStartTime = Date().timeIntervalSince1970
    }

    /// 配置日志引擎（应在 App 启动时调用一次）
    /// - Parameter configuration: 引擎配置
    public static func configure(_ configuration: LoggerEngineConfiguration = LoggerEngineConfiguration()) {
        shared.configure(configuration)
    }

    /// 配置日志引擎
    private func configure(_ configuration: LoggerEngineConfiguration) {
        lock.lock()
        defer { lock.unlock() }

        guard !isConfigured else {
            assertionFailure("LoggerEngine 已配置，不能重复配置")
            return
        }

        setupDestinations(configuration)
        isConfigured = true
    }

    /// 确保引擎已配置（延迟初始化）
    private func ensureConfigured() {
        lock.lock()
        let configured = isConfigured
        lock.unlock()

        if !configured {
            configure(LoggerEngineConfiguration())
        }
    }

    private func setupDestinations(_ configuration: LoggerEngineConfiguration) {
        // 配置控制台输出
        if configuration.enableConsole {
            let console = ConsoleDestination()
            #if targetEnvironment(simulator)
            console.logPrintWay = .logger(subsystem: "Hemin", category: "APP")
            #endif
            console.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d [$L] <$X> $T [$N.$F:$l] - $M"
            console.minLevel = configuration.level.swiftyBeaverLevel
            swiftyBeaver.addDestination(console)
        }

        // 配置 CoreData 数据库输出
        guard configuration.enableDatabase else { return }

        let coreDataDest = CoreDataDestination(
            sessionId: sessionId,
            sessionStartTime: sessionStartTime,
            batchSize: configuration.batchSize,
            debounceInterval: configuration.debounceInterval,
            immediateFlushLevels: configuration.immediateFlushLevels
        )
        coreDataDest.minLevel = configuration.level.swiftyBeaverLevel
        swiftyBeaver.addDestination(coreDataDest)

        self.coreDataDestination = coreDataDest

        // 创建数据库管理器
        let dbManager = LogDatabaseManager()
        self.databaseManager = dbManager

        // 创建轮转管理器
        self.rotationManager = LogDatabaseRotationManager(
            databaseManager: dbManager,
            maxDatabaseSize: configuration.maxDatabaseSize,
            maxRetentionDays: configuration.maxRetentionDays
        )

        // 启动时执行一次清理
        rotationManager?.performRotationIfNeeded()
    }

    // MARK: - 日志方法

    func verbose(_ message: String, file: String, function: String, line: Int, context: String?) {
        ensureConfigured()
        let ctx = context ?? moduleName(for: file)
        swiftyBeaver.verbose(message, file: file, function: function, line: line, context: ctx)
    }

    func debug(_ message: String, file: String, function: String, line: Int, context: String?) {
        ensureConfigured()
        let ctx = context ?? moduleName(for: file)
        swiftyBeaver.debug(message, file: file, function: function, line: line, context: ctx)
    }

    func info(_ message: String, file: String, function: String, line: Int, context: String?) {
        ensureConfigured()
        let ctx = context ?? moduleName(for: file)
        swiftyBeaver.info(message, file: file, function: function, line: line, context: ctx)
    }

    func warning(_ message: String, file: String, function: String, line: Int, context: String?) {
        ensureConfigured()
        let ctx = context ?? moduleName(for: file)
        swiftyBeaver.warning(message, file: file, function: function, line: line, context: ctx)
    }

    func error(_ message: String, file: String, function: String, line: Int, context: String?) {
        ensureConfigured()
        let ctx = context ?? moduleName(for: file)
        swiftyBeaver.error(message, file: file, function: function, line: line, context: ctx)
    }

    // MARK: - 辅助方法

    private func moduleName(for file: String) -> String {
        if let cached = moduleCache.value(for: file) {
            return cached
        }
        let module = defaultModuleExtractor(file)
        moduleCache.setValue(module, for: file)
        return module
    }

    /// 默认模块名提取器
    private func defaultModuleExtractor(_ file: String) -> String {
        let components = file.split(separator: "/")

        // CocoaPods
        if let podsIndex = components.firstIndex(of: "Pods"), podsIndex + 1 < components.count {
            return String(components[podsIndex + 1])
        }

        // SPM
        if let checkoutIndex = components.firstIndex(of: "checkouts"), checkoutIndex + 1 < components.count {
            return String(components[checkoutIndex + 1])
        }

        // Xcode project
        if let appIndex = components.firstIndex(where: { $0.hasSuffix(".xcodeproj") }) {
            return String(components[appIndex])
        }

        // 回退：使用父目录名
        if components.count > 1 {
            return String(components[components.count - 2])
        }

        return "Unknown"
    }

    // MARK: - 公共方法

    /// 刷新日志缓冲
    public func flush() {
        coreDataDestination?.flush()
    }

    /// 获取数据库管理器
    public func getDatabaseManager() -> LogDatabaseManager? {
        return databaseManager
    }

    /// 执行数据库轮转
    public func performDatabaseRotation() {
        rotationManager?.performRotationIfNeeded()
    }

    /// 清理过期日志
    public func cleanupExpiredLogs() {
        rotationManager?.cleanupExpiredLogs()
    }

    /// 获取会话信息
    public func getSessionInfo() -> (sessionId: String, sessionStartTime: TimeInterval) {
        return (sessionId, sessionStartTime)
    }
}
