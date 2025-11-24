//
//  LoggerEnvironment.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/21.
//

import SwiftUI

/// SwiftUI Environment Key for Logger
private struct LoggerKey: EnvironmentKey {
    static let defaultValue: LoggerProtocol = Logger()
}

/// SwiftUI Environment 扩展
public extension EnvironmentValues {
    /// 日志实例
    var logger: LoggerProtocol {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }
}

/// View 扩展，便于注入 Logger
public extension View {
    /// 注入自定义 Logger 实例
    func logger(_ logger: LoggerProtocol) -> some View {
        environment(\.logger, logger)
    }
}
