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

    public init(
        level: LogLevel = .debug,
        enableConsole: Bool = true,
        enableDatabase: Bool = true,
        maxDatabaseSize: Int64 = 100 * 1024 * 1024, // 100MB
        maxRetentionDays: Int = 30
    ) {
        self.level = level
        self.enableConsole = enableConsole
        self.enableDatabase = enableDatabase
        self.maxDatabaseSize = maxDatabaseSize
        self.maxRetentionDays = maxRetentionDays
    }

    // MARK: - 向后兼容 (已废弃)

    @available(*, deprecated, renamed: "enableDatabase", message: "使用 enableDatabase 替代")
    public var enableFile: Bool { enableDatabase }

    @available(*, deprecated, message: "CoreData 不再使用此参数")
    public var logDirectory: URL? { nil }

    @available(*, deprecated, message: "CoreData 不再使用此参数")
    public var fileGenerationPolicy: FileGenerationPolicy { .daily }

    @available(*, deprecated, message: "CoreData 不再使用此参数")
    public var rotationPolicy: RotationPolicy { .size(10 * 1024 * 1024) }

    @available(*, deprecated, message: "CoreData 不再使用此参数")
    public var maxLogFiles: Int { 10 }
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

    private init() {
        self.swiftyBeaver = SwiftyBeaver.self
        self.moduleCache = ConcurrentCache()
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

        let coreDataDest = CoreDataDestination()
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
        let module = LogConfiguration.defaultModuleExtractor(file)
        moduleCache.setValue(module, for: file)
        return module
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
}
