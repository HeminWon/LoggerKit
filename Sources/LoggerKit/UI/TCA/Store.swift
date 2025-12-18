//
//  Store.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation
import Combine

// MARK: - Store

/// A store holds state and orchestrates the unidirectional data flow
///
/// The Store is the runtime of the TCA architecture:
/// 1. Holds the current State
/// 2. Receives Actions from the View
/// 3. Calls the Reducer to get new State and Effects
/// 4. Updates State (triggers SwiftUI updates via @Published)
/// 5. Executes Effects which may produce new Actions
/// 6. Recursively sends new Actions back to step 2
///
/// Example usage:
/// ```swift
/// let store = Store(
///     initialState: CounterState(),
///     reducer: CounterReducer()
/// )
///
/// // In SwiftUI View:
/// Text("Count: \(store.state.count)")
/// Button("Increment") {
///     Task {
///         await store.send(.increment)
///     }
/// }
/// ```
@MainActor
public final class Store<State: Equatable, Action>: ObservableObject, EffectExecutorProtocol {
    // MARK: - Properties

    /// The current state (read-only from outside)
    @Published public private(set) var state: State

    /// The reducer that handles actions
    private let reducer: AnyReducer<State, Action>

    /// Running tasks that can be cancelled
    private var runningTasks: [AnyHashable: Task<Void, Never>] = [:]

    /// Whether action logging is enabled (for debugging)
    private let enableActionLogging: Bool

    /// Action history for debugging (optional)
    private var actionHistory: [ActionRecord] = []

    // MARK: - Initialization

    /// Create a new store
    ///
    /// - Parameters:
    ///   - initialState: The initial state
    ///   - reducer: The reducer to handle actions
    ///   - enableActionLogging: Whether to log actions (default: false)
    public init(
        initialState: State,
        reducer: AnyReducer<State, Action>,
        enableActionLogging: Bool = false
    ) {
        self.state = initialState
        self.reducer = reducer
        self.enableActionLogging = enableActionLogging
    }

    // MARK: - Action Handling

    /// Send an action to update the state
    ///
    /// This is the entry point for all state changes:
    /// 1. Logs the action (if enabled)
    /// 2. Calls reducer to get new state and effects
    /// 3. Updates state (triggers @Observable)
    /// 4. Executes effects which may send new actions
    ///
    /// - Parameter action: The action to handle
    public func send(_ action: Action) async {
        // Log action
        if enableActionLogging {
            logAction(action)
        }

        // Create a copy of state for mutation
        var newState = state

        // Call reducer to get new state and effects
        let effect = reducer.reduce(&newState, action)

        // Update state (triggers @Observable -> SwiftUI updates)
        let hasChanged = state != newState
        if hasChanged {
            state = newState
        }

        // Execute effects
        await executeEffect(effect)
    }

    // MARK: - Effect Execution

    /// Execute an effect and handle any resulting actions
    private func executeEffect(_ effect: Effect<Action>) async {
        switch effect {
        case .none:
            // No effect to execute
            return

        case .task(let asyncTask):
            // Execute task and send resulting action
            if let action = await asyncTask() {
                await send(action)
            }

        case .cancellable(let id, let asyncTask):
            // Cancel any existing task with this ID
            cancel(id: id)

            // Start new task
            runningTasks[id] = Task { [weak self] in
                guard let self = self else { return }

                // Execute task
                if let action = try? await asyncTask() {
                    await self.send(action)
                }

                // Clean up task reference
                await MainActor.run {
                    self.runningTasks[id] = nil
                }
            }

        case .cancel(let id):
            // Cancel the running effect with the specified ID
            cancel(id: id)

        case .multiple(let effects):
            // Execute all effects concurrently
            await withTaskGroup(of: Void.self) { group in
                for effect in effects {
                    group.addTask { [weak self] in
                        await self?.executeEffect(effect)
                    }
                }
            }
        }
    }

    // MARK: - EffectExecutorProtocol

    /// Cancel a running effect by its ID
    ///
    /// - Parameter id: The ID of the effect to cancel
    public func cancel(id: AnyHashable) {
        runningTasks[id]?.cancel()
        runningTasks[id] = nil
    }

    /// Cancel all running effects
    public func cancelAll() {
        for task in runningTasks.values {
            task.cancel()
        }
        runningTasks.removeAll()
    }

    // MARK: - Action Logging (for debugging)

    private struct ActionRecord {
        let action: String
        let timestamp: Date
        let stateBefore: String
        let stateAfter: String
    }

    private func logAction(_ action: Action) {
        let timestamp = Date()
        let stateBefore = String(describing: state)

        let record = ActionRecord(
            action: String(describing: action),
            timestamp: timestamp,
            stateBefore: stateBefore,
            stateAfter: "" // Will be filled later
        )

        actionHistory.append(record)

        #if DEBUG
        print("🎬 Action: \(String(describing: action))")
        #endif
    }

    /// Get action history for debugging
    public func getActionHistory() -> [(action: String, timestamp: Date)] {
        actionHistory.map { (action: $0.action, timestamp: $0.timestamp) }
    }

    /// Clear action history
    public func clearActionHistory() {
        actionHistory.removeAll()
    }
}

// MARK: - Store + Convenience Initializers

extension Store {
    /// Create a store with a closure-based reducer
    public convenience init(
        initialState: State,
        enableActionLogging: Bool = false,
        reduce: @escaping (inout State, Action) -> Effect<Action>
    ) {
        self.init(
            initialState: initialState,
            reducer: AnyReducer(reduce: reduce),
            enableActionLogging: enableActionLogging
        )
    }

    /// Create a store with any Reducer
    public convenience init<R: Reducer>(
        initialState: State,
        reducer: R,
        enableActionLogging: Bool = false
    ) where R.State == State, R.Action == Action {
        self.init(
            initialState: initialState,
            reducer: AnyReducer(reducer),
            enableActionLogging: enableActionLogging
        )
    }
}
