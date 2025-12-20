//
//  Reducer.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - Reducer Protocol

/// A reducer defines how to update state in response to actions
///
/// Reducers are pure functions that take the current state and an action,
/// and return a new state along with any effects to execute.
///
/// Key principles:
/// - Pure function: Same input always produces same output
/// - No side effects: Side effects are returned as Effects
/// - Composable: Multiple reducers can be combined
///
/// Example usage:
/// ```swift
/// struct CounterReducer: Reducer {
///     func reduce(_ state: inout CounterState, _ action: CounterAction) -> Effect<CounterAction> {
///         switch action {
///         case .increment:
///             state.count += 1
///             return .none
///         case .decrement:
///             state.count -= 1
///             return .none
///         case .loadData:
///             return .task {
///                 let data = await dataLoader.load()
///                 return .dataLoaded(data)
///             }
///         }
///     }
/// }
/// ```
public protocol Reducer<State, Action> {
    associatedtype State
    associatedtype Action

    /// Reduce the state with an action and return any effects
    ///
    /// - Parameters:
    ///   - state: The current state (passed as inout for mutation)
    ///   - action: The action to handle
    /// - Returns: An effect to execute (or .none)
    func reduce(_ state: inout State, _ action: Action) -> Effect<Action>
}

// MARK: - Reducer Composition

/// Combines multiple reducers into a single reducer
///
/// All reducers will be called in sequence with the same state and action.
/// Their effects will be merged and executed concurrently.
///
/// Example:
/// ```swift
/// let combined = CombinedReducer(reducers: [
///     AnyReducer(CounterReducer()),
///     AnyReducer(LoggingReducer()),
///     AnyReducer(AnalyticsReducer())
/// ])
/// ```
public struct CombinedReducer<State, Action>: Reducer {
    private let reducers: [AnyReducer<State, Action>]

    public init(reducers: [AnyReducer<State, Action>]) {
        self.reducers = reducers
    }

    public func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
        let effects = reducers.map { reducer in
            reducer.reduce(&state, action)
        }

        guard !effects.isEmpty else {
            return .none
        }

        guard effects.count > 1 else {
            return effects[0]
        }

        return .multiple(effects)
    }
}

// MARK: - Type-Erased Reducer

/// Type-erased wrapper for any Reducer
public struct AnyReducer<State, Action>: Reducer {
    private let _reduce: (inout State, Action) -> Effect<Action>

    public init<R: Reducer>(_ reducer: R) where R.State == State, R.Action == Action {
        self._reduce = reducer.reduce
    }

    public init(reduce: @escaping (inout State, Action) -> Effect<Action>) {
        self._reduce = reduce
    }

    public func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
        _reduce(&state, action)
    }
}

// MARK: - Reducer + Pullback

extension Reducer {
    /// Transform this reducer to work on a different state and action type
    ///
    /// This enables composition of reducers working on different slices of state.
    ///
    /// - Parameters:
    ///   - toLocalState: Extract local state from global state
    ///   - toLocalAction: Extract local action from global action
    ///   - toGlobalAction: Transform local action to global action
    /// - Returns: A reducer working on the global state and action
    public func pullback<GlobalState, GlobalAction>(
        state toLocalState: WritableKeyPath<GlobalState, State>,
        action toLocalAction: @escaping (GlobalAction) -> Action?,
        toGlobalAction: @escaping (Action) -> GlobalAction
    ) -> AnyReducer<GlobalState, GlobalAction> {
        return AnyReducer { globalState, globalAction in
            guard let localAction = toLocalAction(globalAction) else {
                return .none
            }

            let effect = self.reduce(&globalState[keyPath: toLocalState], localAction)

            // Transform effects to work with global actions
            switch effect {
            case .none:
                return .none
            case .task(let task):
                return .task {
                    guard let action = await task() else { return nil }
                    return toGlobalAction(action)
                }
            case .cancellable(let id, let task):
                return .cancellable(id: id) {
                    guard let action = try await task() else { return nil }
                    return toGlobalAction(action)
                }
            case .stream(let id, let streamBuilder):
                return .stream(id: id) {
                    let stream = streamBuilder()
                    return AsyncStream { continuation in
                        Task {
                            for await action in stream {
                                continuation.yield(toGlobalAction(action))
                            }
                            continuation.finish()
                        }
                    }
                }
            case .cancel(let id):
                return .cancel(id: id)
            case .multiple(let effects):
                let globalEffects = effects.map { localEffect -> Effect<GlobalAction> in
                    switch localEffect {
                    case .none:
                        return .none
                    case .task(let task):
                        return .task {
                            guard let action = await task() else { return nil }
                            return toGlobalAction(action)
                        }
                    case .cancellable(let id, let task):
                        return .cancellable(id: id) {
                            guard let action = try await task() else { return nil }
                            return toGlobalAction(action)
                        }
                    case .stream(let id, let streamBuilder):
                        return .stream(id: id) {
                            let stream = streamBuilder()
                            return AsyncStream { continuation in
                                Task {
                                    for await action in stream {
                                        continuation.yield(toGlobalAction(action))
                                    }
                                    continuation.finish()
                                }
                            }
                        }
                    case .cancel(let id):
                        return .cancel(id: id)
                    case .multiple:
                        return .none // Nested multiple not supported in this simplified version
                    }
                }
                return .multiple(globalEffects)
            }
        }
    }
}
