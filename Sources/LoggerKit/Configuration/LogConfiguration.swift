//
//  LogConfiguration.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/21.
//

import Foundation

/// 日志配置
public struct LogConfiguration: Sendable {
    public let destinations: [LogDestination]
    public let moduleNameExtractor: @Sendable (String) -> String
    public let fileGenerationPolicy: FileGenerationPolicy
    public let rotationPolicy: RotationPolicy
    public let maxLogFiles: Int

    // 便捷初始化器使用的控制属性
    public let level: LogLevel
    public let enableConsole: Bool
    public let enableFile: Bool
    public let logDirectory: URL?

    public init(
        destinations: [LogDestination],
        moduleNameExtractor: @escaping @Sendable (String) -> String = defaultModuleExtractor,
        fileGenerationPolicy: FileGenerationPolicy = .daily,
        rotationPolicy: RotationPolicy = .size(10 * 1024 * 1024), // 默认 10MB
        maxLogFiles: Int = 10,
        level: LogLevel = .debug,
        enableConsole: Bool = true,
        enableFile: Bool = true,
        logDirectory: URL? = nil
    ) {
        self.destinations = destinations
        self.moduleNameExtractor = moduleNameExtractor
        self.fileGenerationPolicy = fileGenerationPolicy
        self.rotationPolicy = rotationPolicy
        self.maxLogFiles = maxLogFiles
        self.level = level
        self.enableConsole = enableConsole
        self.enableFile = enableFile
        self.logDirectory = logDirectory
    }

    /// 默认模块名提取器
    public static func defaultModuleExtractor(_ file: String) -> String {
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
}
