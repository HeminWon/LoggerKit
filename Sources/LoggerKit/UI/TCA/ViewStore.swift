//
//  ViewStore.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - ViewStore

/// A ViewStore wraps a Store and provides a view-friendly interface
///
/// ViewStore 解决的核心问题:
/// 1. ✅ 提供同步的 send 方法 (避免 UI binding 中的 Task { await })
/// 2. ✅ 提供便捷的 Binding 创建方法
/// 3. ✅ 订阅 Store 的变化并通知 SwiftUI
///
/// 使用示例:
/// ```swift
/// struct MyView: View {
///     @ObservedObject var viewStore: ViewStore<MyState, MyAction>
///
///     var body: some View {
///         TextField(
///             "Search",
///             text: viewStore.binding(
///                 get: { $0.searchText },
///                 send: { .updateSearchText($0) }
///             )
///         )
///         .task {
///             await viewStore.sendAsync(.loadData)  // 等待完成
///         }
///         Button("Refresh") {
///             viewStore.send(.refresh)  // 同步调用,不阻塞
///         }
///     }
/// }
/// ```
///
/// 设计参考:
/// - 受 PointFree TCA ViewStore 启发
/// - 但更轻量,无外部依赖
@MainActor
public final class ViewStore<State: Equatable, Action>: ObservableObject {
    // MARK: - Properties

    /// 底层 Store
    private let store: Store<State, Action>

    /// Cancellables
    private var cancellables = Set<AnyCancellable>()

    /// 当前状态 (只读)
    public var state: State {
        store.state
    }

    /// 底层 Store (只读，用于高级场景)
    ///
    /// 通常不需要直接访问 Store，但在某些场景下可能需要：
    /// - 传递给其他需要 Store 的组件
    /// - 创建子 Store (scoped store)
    ///
    /// Example:
    /// ```swift
    /// let childStore = viewStore.underlyingStore.scope(...)
    /// ```
    public var underlyingStore: Store<State, Action> {
        store
    }

    // MARK: - Initialization

    /// 创建 ViewStore
    ///
    /// - Parameter store: 底层的 TCA Store
    public init(store: Store<State, Action>) {
        self.store = store

        // 订阅 Store 的状态变化,通知 SwiftUI
        store.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Action Sending

    /// 同步发送 Action (立即返回,异步执行)
    ///
    /// 这个方法用于 UI 交互,不会阻塞主线程:
    /// ```swift
    /// Button("Load") {
    ///     viewStore.send(.loadData)  // ✅ 同步,不需要 Task
    /// }
    /// ```
    ///
    /// 实现原理:
    /// - 创建 Task { } 异步执行
    /// - 立即返回,不等待完成
    /// - Store.send() 在后台异步执行
    /// - State 更新时通过 objectWillChange 触发 UI 刷新
    ///
    /// - Parameter action: 要发送的 Action
    public func send(_ action: Action) {
        print("📤 [ViewStore] send() 被调用 - Thread: \(Thread.isMainThread ? "Main" : "Background")")
        Task {
            await store.send(action)
        }
    }

    /// 异步发送 Action (等待完成)
    ///
    /// 这个方法用于需要等待结果的场景:
    /// ```swift
    /// .task {
    ///     await viewStore.sendAsync(.loadData)
    ///     print("Loading completed")
    /// }
    /// ```
    ///
    /// - Parameter action: 要发送的 Action
    public func sendAsync(_ action: Action) async {
        await store.send(action)
    }

    // MARK: - Binding Helpers

    /// 创建双向绑定
    ///
    /// 用于 TextField, Toggle, Slider 等需要双向绑定的控件:
    /// ```swift
    /// TextField(
    ///     "Search",
    ///     text: viewStore.binding(
    ///         get: { $0.searchText },
    ///         send: { .updateSearchText($0) }
    ///     )
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - get: 从 State 获取值的闭包
    ///   - send: 将新值转换为 Action 的闭包
    /// - Returns: SwiftUI Binding
    public func binding<Value: Equatable>(
        get: @escaping (State) -> Value,
        send toAction: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: {
                let value = get(self.state)
                return value
            },
            set: { newValue in
                print("📝 [ViewStore] Binding.set 被调用 - 新值: \(newValue)")
                // 去重：只有值真正变化时才发送 action
                let currentValue = get(self.state)
                print("📝 [ViewStore] 当前值: \(currentValue), 新值: \(newValue)")
                guard newValue != currentValue else {
                    print("📝 [ViewStore] Binding 值未变化，跳过发送 action")
                    return
                }
                print("📝 [ViewStore] Binding 值变化，发送 action")
                self.send(toAction(newValue))  // ✅ 同步 send,不阻塞
            }
        )
    }

    /// 创建可选值绑定
    ///
    /// 用于可选类型的绑定:
    /// ```swift
    /// TextField(
    ///     "Optional",
    ///     text: viewStore.binding(
    ///         get: { $0.optionalText },
    ///         send: { .updateOptionalText($0) }
    ///     )
    /// )
    /// ```
    public func binding<Value>(
        get: @escaping (State) -> Value?,
        send toAction: @escaping (Value?) -> Action
    ) -> Binding<Value?> {
        Binding(
            get: { get(self.state) },
            set: { newValue in
                self.send(toAction(newValue))
            }
        )
    }

    /// 创建布尔值绑定 (常用于 sheet/alert)
    ///
    /// 用于控制 sheet, alert, fullScreenCover 等:
    /// ```swift
    /// .sheet(
    ///     isPresented: viewStore.binding(
    ///         get: { $0.isFilterPresented },
    ///         send: { .setFilterPresented($0) }
    ///     )
    /// ) {
    ///     FilterSheet(viewStore: viewStore)
    /// }
    /// ```
    public func binding(
        get: @escaping (State) -> Bool,
        send toAction: @escaping (Bool) -> Action
    ) -> Binding<Bool> {
        Binding(
            get: { get(self.state) },
            set: { newValue in
                self.send(toAction(newValue))
            }
        )
    }
}

// MARK: - ViewStore + Convenience Initializers

extension ViewStore {
    /// 从 Store 创建 ViewStore (便捷方法)
    public static func from(_ store: Store<State, Action>) -> ViewStore {
        ViewStore(store: store)
    }
}

// MARK: - Store + ViewStore Extension

extension Store {
    /// 创建 ViewStore
    ///
    /// 便捷方法:
    /// ```swift
    /// let store = LogSceneStore.create()
    /// let viewStore = store.viewStore()
    /// ```
    public func viewStore() -> ViewStore<State, Action> {
        ViewStore(store: self)
    }
}
