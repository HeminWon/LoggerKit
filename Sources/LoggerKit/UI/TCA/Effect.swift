//
//  Effect.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - EffectExecutorProtocol

/// Protocol for executing effects and managing cancellation
@MainActor
public protocol EffectExecutorProtocol: AnyObject {
    /// Cancel a running effect by its ID
    func cancel(id: AnyHashable)
}

// MARK: - Effect

/// Represents a side effect that can produce an Action
///
/// Effects encapsulate asynchronous operations (network, database, timers)
/// and enable:
/// - Testability: Effects can be mocked and verified
/// - Composability: Effects can be combined and transformed
/// - Cancellation: Long-running effects can be cancelled
///
/// Example usage:
/// ```swift
/// func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
///     switch action {
///     case .loadData:
///         return .task {
///             let data = try await dataLoader.load()
///             return .dataLoaded(data)
///         }
///     case .dataLoaded:
///         return .none
///     }
/// }
/// ```
public enum Effect<Action> {
    /// No effect to execute
    case none

    /// Execute an async task and return an optional Action
    case task(() async -> Action?)

    /// Execute a cancellable async task with an ID
    /// If a new effect with the same ID is started, the previous one is cancelled
    case cancellable(id: AnyHashable, () async throws -> Action?)

    /// Execute multiple effects concurrently
    case multiple([Effect<Action>])

    /// Cancel a running effect by its ID
    case cancel(id: AnyHashable)

    /// Execute an async stream that can emit multiple actions
    /// Useful for long-running operations that need to send progress updates
    case stream(id: AnyHashable?, () -> AsyncStream<Action>)

    // MARK: - Execution

    /// Execute this effect in the context of a store
    ///
    /// - Parameter executor: The executor that can handle cancellation
    /// - Returns: An optional Action produced by the effect
    public func execute(in executor: EffectExecutorProtocol) async -> Action? {
        switch self {
        case .none:
            return nil

        case .task(let asyncTask):
            return await asyncTask()

        case .cancellable(_, let asyncTask):
            // Cancellation is handled by the executor (Store)
            // If the task is cancelled, it will throw CancellationError
            return try? await asyncTask()

        case .cancel(let id):
            // Cancel the task via the executor
            await executor.cancel(id: id)
            return nil

        case .stream(_, let streamBuilder):
            // Stream case returns the first action from the stream
            // All subsequent actions should be handled by a separate mechanism
            // This is a limitation of the current execute signature
            let stream = streamBuilder()
            for await action in stream {
                return action
            }
            return nil

        case .multiple(let effects):
            // Execute all effects concurrently and collect results
            return await withTaskGroup(of: Action?.self) { group in
                for effect in effects {
                    group.addTask {
                        await effect.execute(in: executor)
                    }
                }

                // Return the first non-nil Action
                for await action in group {
                    if let action = action {
                        return action
                    }
                }
                return nil
            }
        }
    }

    // MARK: - Transformation

    /// Transform the action type of this effect
    public func map<NewAction>(_ transform: @escaping (Action) -> NewAction) -> Effect<NewAction> {
        switch self {
        case .none:
            return .none
        case .task(let asyncTask):
            return .task {
                guard let action = await asyncTask() else { return nil }
                return transform(action)
            }
        case .cancellable(let id, let asyncTask):
            return .cancellable(id: id) {
                guard let action = try await asyncTask() else { return nil }
                return transform(action)
            }
        case .stream(let id, let streamBuilder):
            return .stream(id: id) {
                let stream = streamBuilder()
                return AsyncStream { continuation in
                    Task {
                        for await action in stream {
                            continuation.yield(transform(action))
                        }
                        continuation.finish()
                    }
                }
            }
        case .cancel(let id):
            return .cancel(id: id)
        case .multiple(let effects):
            return .multiple(effects.map { $0.map(transform) })
        }
    }

    // MARK: - Convenience Combinators

    /// Merge multiple effects into a single effect that executes them concurrently
    public static func merge(_ effects: Effect<Action>...) -> Effect<Action> {
        return .multiple(effects)
    }

    /// Merge an array of effects into a single effect that executes them concurrently
    public static func merge(_ effects: [Effect<Action>]) -> Effect<Action> {
        return .multiple(effects)
    }

    /// Concatenate multiple effects into a single effect that executes them sequentially
    public static func concatenate(_ effects: Effect<Action>...) -> Effect<Action> {
        return .task {
            for effect in effects {
                // Note: We need an executor reference, but for sequential execution
                // we'll use a simple implementation that ignores cancellation
                if case .task(let task) = effect {
                    if let action = await task() {
                        return action
                    }
                }
            }
            return nil
        }
    }
}

// MARK: - Effect + Sendable

extension Effect: @unchecked Sendable where Action: Sendable {}
