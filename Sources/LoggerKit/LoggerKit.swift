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
    ///     enableFile: true
    /// )
    /// ```
    public static func configure(
        level: LogLevel = .debug,
        enableConsole: Bool = true,
        enableFile: Bool = true,
        logDirectory: URL? = nil,
        fileGenerationPolicy: FileGenerationPolicy = .daily,
        rotationPolicy: RotationPolicy = .size(10 * 1024 * 1024),
        maxLogFiles: Int = 10
    ) {
        let configuration = LoggerEngineConfiguration(
            level: level,
            enableConsole: enableConsole,
            enableFile: enableFile,
            logDirectory: logDirectory,
            fileGenerationPolicy: fileGenerationPolicy,
            rotationPolicy: rotationPolicy,
            maxLogFiles: maxLogFiles
        )
        LoggerEngine.configure(configuration)
    }
}
