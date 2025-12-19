//
//  LoggerKit.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/9/5.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// Re-export all public APIs
@_exported import SwiftyBeaver

/// LoggerKit 命名空间
public enum LoggerKit {
    /// UI 配置
    public struct Configuration: Sendable {
        /// 会话 ID 过滤
        public let sessionIds: Set<String>

        /// 是否启用 Action 日志记录（用于调试）
        public let enableActionLogging: Bool

        /// 初始化配置
        /// - Parameters:
        ///   - sessionIds: 需要过滤的会话 ID 集合，默认为空（显示所有会话）
        ///   - enableActionLogging: 是否启用 TCA Action 日志，默认为 false
        public init(
            sessionIds: Set<String> = [],
            enableActionLogging: Bool = false
        ) {
            self.sessionIds = sessionIds
            self.enableActionLogging = enableActionLogging
        }

        /// 默认配置
        public static let `default` = Configuration()
    }
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

    // MARK: - UI 方法

    /// 创建日志查看 Store
    ///
    /// 使用示例：
    /// ```swift
    /// let store = LoggerKit.makeStore(
    ///     configuration: .init(
    ///         sessionIds: ["session-123"],
    ///         enableActionLogging: true
    ///     )
    /// )
    /// ```
    ///
    /// - Parameter configuration: UI 配置，默认为 `.default`
    /// - Returns: 日志场景的 Store 实例
    @MainActor
    public static func makeStore(
        configuration: Configuration = .default
    ) -> LogSceneStore {
        return LogSceneStore.create(
            sessionIds: configuration.sessionIds,
            enableActionLogging: configuration.enableActionLogging
        )
    }

    /// 创建日志查看 ViewStore（推荐）
    ///
    /// ViewStore 提供了更好的 SwiftUI 集成体验:
    /// - ✅ 同步的 send 方法 (不需要 Task { await })
    /// - ✅ 便捷的 Binding 创建
    /// - ✅ 预定义的常用 bindings
    ///
    /// 使用示例：
    /// ```swift
    /// let viewStore = LoggerKit.makeViewStore(
    ///     configuration: .init(sessionIds: ["session-123"])
    /// )
    ///
    /// // 在 SwiftUI View 中:
    /// struct MyView: View {
    ///     @ObservedObject var viewStore: LogDetailViewStore
    ///
    ///     var body: some View {
    ///         TextField("Search", text: viewStore.searchTextBinding)
    ///         Button("Load") { viewStore.loadLogFile() }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter configuration: UI 配置，默认为 `.default`
    /// - Returns: LogDetail 的 ViewStore 实例
    @MainActor
    public static func makeViewStore(
        configuration: Configuration = .default
    ) -> LogDetailViewStore {
        let store = makeStore(configuration: configuration)
        return store.viewStore()
    }

    /// 用 Store 构造日志查看 View
    ///
    /// 使用示例：
    /// ```swift
    /// let store = LoggerKit.makeStore()
    /// let view = LoggerKit.makeView(store: store)
    /// ```
    ///
    /// - Parameter store: 日志场景的 Store 实例
    /// - Returns: 日志详情视图
    @MainActor
    public static func makeView(
        store: LogSceneStore
    ) -> some View {
        let sceneState = LogDetailSceneState(store: store)
        return LogDetailScene(sceneState: sceneState)
    }

    /// 便捷方法：直接创建日志查看 View（使用 SceneState，保持向后兼容）
    ///
    /// 使用示例：
    /// ```swift
    /// let view = LoggerKit.makeView(
    ///     configuration: .init(sessionIds: ["session-123"])
    /// )
    /// ```
    ///
    /// - Parameter configuration: UI 配置，默认为 `.default`
    /// - Returns: 日志详情视图
    @MainActor
    public static func makeView(
        configuration: Configuration = .default
    ) -> some View {
        let store = makeStore(configuration: configuration)
        return makeView(store: store)
    }

    /// 用 ViewStore 构造日志查看 View（推荐）
    ///
    /// 使用 ViewStore 的新 API,提供更好的性能和更简洁的代码:
    /// ```swift
    /// let viewStore = LoggerKit.makeViewStore()
    /// let view = LoggerKit.makeView(viewStore: viewStore)
    /// ```
    ///
    /// - Parameter viewStore: 日志场景的 ViewStore 实例
    /// - Returns: 日志详情视图
    @MainActor
    public static func makeView(
        viewStore: LogDetailViewStore
    ) -> some View {
        LogDetailScene(viewStore: viewStore)
    }

    /// 便捷方法：直接创建日志查看 View（使用 ViewStore）
    ///
    /// 这是使用 ViewStore 的最简单方式:
    /// ```swift
    /// let view = LoggerKit.makeViewWithViewStore(
    ///     configuration: .init(sessionIds: ["session-123"])
    /// )
    /// ```
    ///
    /// - Parameter configuration: UI 配置，默认为 `.default`
    /// - Returns: 日志详情视图
    @MainActor
    public static func makeViewWithViewStore(
        configuration: Configuration = .default
    ) -> some View {
        let viewStore = makeViewStore(configuration: configuration)
        return makeView(viewStore: viewStore)
    }

    #if canImport(UIKit)
    /// 创建日志查看 UIViewController（UIKit 应用使用）
    ///
    /// 使用示例：
    /// ```swift
    /// // 基础使用
    /// let viewController = LoggerKit.makeViewController()
    /// navigationController?.pushViewController(viewController, animated: true)
    ///
    /// // 使用自定义配置
    /// let viewController = LoggerKit.makeViewController(
    ///     configuration: .init(
    ///         sessionIds: ["session-123"],
    ///         enableActionLogging: true
    ///     )
    /// )
    /// present(viewController, animated: true)
    /// ```
    ///
    /// - Parameter configuration: UI 配置，默认为 `.default`
    /// - Returns: 包装了日志详情视图的 UIViewController
    @MainActor
    public static func makeViewController(
        configuration: Configuration = .default
    ) -> UIViewController {
        let view = makeView(configuration: configuration)
        let hostingController = UIHostingController(rootView: view)
        hostingController.title = NSLocalizedString("log_viewer_title",
                                                    bundle: .module,
                                                    comment: "Log Viewer")
        return hostingController
    }

    /// 创建日志查看 UIViewController（使用已有 Store）
    ///
    /// 使用示例：
    /// ```swift
    /// let store = LoggerKit.makeStore()
    /// // 可以在创建 ViewController 前对 store 进行操作
    /// let viewController = LoggerKit.makeViewController(store: store)
    /// navigationController?.pushViewController(viewController, animated: true)
    /// ```
    ///
    /// - Parameter store: 日志场景的 Store 实例
    /// - Returns: 包装了日志详情视图的 UIViewController
    @MainActor
    public static func makeViewController(
        store: LogSceneStore
    ) -> UIViewController {
        let view = makeView(store: store)
        let hostingController = UIHostingController(rootView: view)
        hostingController.title = NSLocalizedString("log_viewer_title",
                                                    bundle: .module,
                                                    comment: "Log Viewer")
        return hostingController
    }
    #endif
}
