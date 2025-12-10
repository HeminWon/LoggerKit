//
//  LoggerKit.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/9/5.
//

import Foundation

// Re-export all public APIs
@_exported import SwiftyBeaver

/// LoggerKit 命名空间
public enum LoggerKit {
    /// 配置日志引擎（应在 App 启动时调用一次）
    ///
    /// 使用示例：
    /// ```swift
    /// LoggerKit.configure(
    ///     level: .debug,
    ///     enableConsole: true,
    ///     enableDatabase: true,
    ///     maxDatabaseSize: 100 * 1024 * 1024, // 100MB
    ///     maxRetentionDays: 30
    /// )
    /// ```
    public static func configure(
        level: LogLevel = .debug,
        enableConsole: Bool = true,
        enableDatabase: Bool = true,
        maxDatabaseSize: Int64 = 100 * 1024 * 1024,
        maxRetentionDays: Int = 30
    ) {
        let configuration = LoggerEngineConfiguration(
            level: level,
            enableConsole: enableConsole,
            enableDatabase: enableDatabase,
            maxDatabaseSize: maxDatabaseSize,
            maxRetentionDays: maxRetentionDays
        )
        LoggerEngine.configure(configuration)
    }

}
