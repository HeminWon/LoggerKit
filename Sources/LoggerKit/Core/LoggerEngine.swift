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
    public let enableFile: Bool
    public let logDirectory: URL?
    public let fileGenerationPolicy: FileGenerationPolicy
    public let rotationPolicy: RotationPolicy
    public let maxLogFiles: Int

    public init(
        level: LogLevel = .debug,
        enableConsole: Bool = true,
        enableFile: Bool = true,
        logDirectory: URL? = nil,
        fileGenerationPolicy: FileGenerationPolicy = .daily,
        rotationPolicy: RotationPolicy = .size(10 * 1024 * 1024),
        maxLogFiles: Int = 10
    ) {
        self.level = level
        self.enableConsole = enableConsole
        self.enableFile = enableFile
        self.logDirectory = logDirectory
        self.fileGenerationPolicy = fileGenerationPolicy
        self.rotationPolicy = rotationPolicy
        self.maxLogFiles = maxLogFiles
    }
}

/// 日志引擎单例，管理底层资源
public final class LoggerEngine: @unchecked Sendable {

    /// 共享实例
    public static let shared = LoggerEngine()

    private let swiftyBeaver: SwiftyBeaver.Type
    private var logFileManager: LogFileManager?
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

        // 配置文件输出
        guard configuration.enableFile else { return }

        // 确定日志目录
        let loggerKitDirectory: URL
        if let customDirectory = configuration.logDirectory {
            loggerKitDirectory = customDirectory
        } else {
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            loggerKitDirectory = documentsURL.appendingPathComponent(Constants.logDirectoryName, isDirectory: true)
        }

        // 使用 LogFileManager 管理日志文件
        let fileManager = LogFileManager(
            directory: loggerKitDirectory,
            generationPolicy: configuration.fileGenerationPolicy,
            rotationPolicy: configuration.rotationPolicy,
            maxFiles: configuration.maxLogFiles
        )
        self.logFileManager = fileManager

        // 获取当前应使用的日志文件
        let jFileURL = fileManager.currentLogFileURL()

        let jFile = FileDestination()
        jFile.format = "$J"
        jFile.minLevel = configuration.level.swiftyBeaverLevel
        jFile.logFileURL = jFileURL

        swiftyBeaver.addDestination(jFile)
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

    /// 手动触发日志轮转检查
    public func checkRotation() {
        logFileManager?.performRotationIfNeeded()
    }

    /// 清理旧日志文件
    public func cleanupOldLogs() {
        logFileManager?.cleanupOldFiles()
    }

    /// 刷新日志缓冲
    public func flush() {
        // SwiftyBeaver 没有直接的 flush 方法
        // 这里预留接口
    }
}
