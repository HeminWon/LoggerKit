//
//  DeleteFeature.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - DeleteFeature

public struct DeleteFeature {
    // 私有初始化器，防止外部实例化
    private init() {}
}

// MARK: - State

extension DeleteFeature {
    /// Delete State
    public struct State: Equatable, Sendable {
        // MARK: - Session Management

        /// Selected session IDs for deletion
        public var selectedSessionIds: Set<String> = []

        /// Available sessions that can be deleted
        public var availableSessions: [SessionInfo] = []

        /// Loading state for sessions
        public var isLoadingSessions: Bool = false

        // MARK: - Delete Operation

        /// Whether deletion is in progress
        public var isDeleting: Bool = false

        /// Delete progress (0.0 to 1.0)
        public var deleteProgress: Double = 0

        /// Error message (if deletion fails)
        public var error: Error?

        // MARK: - Confirmation Dialog State

        /// Confirmation dialog type (使用枚举表示互斥状态)
        public var confirmationDialog: ConfirmationDialogType? = nil

        // MARK: - Computed Properties

        /// Whether any session is selected
        public var hasSelectedSessions: Bool {
            !selectedSessionIds.isEmpty
        }

        /// Number of selected sessions
        public var selectedSessionCount: Int {
            selectedSessionIds.count
        }

        /// Whether all sessions are selected
        public var isAllSessionsSelected: Bool {
            !availableSessions.isEmpty &&
            selectedSessionIds.count == availableSessions.count
        }

        /// Whether delete all confirmation is shown
        public var showDeleteAllConfirmation: Bool {
            if case .deleteAll = confirmationDialog { return true }
            return false
        }

        /// Whether delete sessions confirmation is shown
        public var showDeleteSessionsConfirmation: Bool {
            if case .deleteSelectedSessions = confirmationDialog { return true }
            return false
        }

        /// Whether error dialog is shown
        public var showError: Bool {
            if case .error = confirmationDialog { return true }
            return false
        }

        // MARK: - Initializer

        public init() {}

        // MARK: - State Mutations

        /// Reset all selections
        public mutating func reset() {
            selectedSessionIds.removeAll()
            deleteProgress = 0
            error = nil
        }

        /// Select all sessions
        public mutating func selectAllSessions() {
            selectedSessionIds = Set(availableSessions.map { $0.id })
        }

        /// Deselect all sessions
        public mutating func deselectAllSessions() {
            selectedSessionIds.removeAll()
        }

        // MARK: - Confirmation Dialog Type

        /// Confirmation dialog type enumeration
        public enum ConfirmationDialogType: Equatable, Sendable {
            case deleteAll              // 删除所有日志
            case deleteSelectedSessions // 删除选中会话
            case error(String)          // 错误提示（存储错误消息文本）
        }

        // MARK: - Equatable

        // ⚠️ 注意: 添加新属性时需要同步更新此 == 运算符实现
        // 手动实现的 Equatable 需要在添加新字段时记得更新，否则会导致状态比较不准确
        public static func == (lhs: State, rhs: State) -> Bool {
            lhs.selectedSessionIds == rhs.selectedSessionIds &&
            lhs.availableSessions == rhs.availableSessions &&
            lhs.isLoadingSessions == rhs.isLoadingSessions &&
            lhs.isDeleting == rhs.isDeleting &&
            lhs.deleteProgress == rhs.deleteProgress &&
            lhs.error?.localizedDescription == rhs.error?.localizedDescription &&
            lhs.confirmationDialog == rhs.confirmationDialog  // ✅ 新增此行
        }
    }
}

// MARK: - Action

extension DeleteFeature {
    /// Delete Actions
    public enum Action: Equatable {
        // MARK: - User Actions (命令型)

        /// Load available sessions
        case loadSessions

        /// Toggle session selection
        case toggleSession(String)

        /// Select all sessions
        case selectAllSessions

        /// Deselect all sessions
        case deselectAllSessions

        /// Confirm delete operation
        case confirmDelete

        /// Cancel ongoing delete operation
        case cancelDelete

        /// Reset all selections and state
        case reset

        /// Show delete all confirmation dialog
        case showDeleteAllConfirmation

        /// Show delete sessions confirmation dialog
        case showDeleteSessionsConfirmation

        /// Dismiss confirmation dialog
        case dismissConfirmationDialog

        /// Confirm delete all logs
        case confirmDeleteAll

        /// Delete single session
        case deleteSingleSession(String)

        // MARK: - System Feedback (事件型)

        /// Sessions loaded successfully
        case sessionsLoaded([SessionInfo])

        /// Loading sessions failed
        case loadingSessionsFailed(Error)

        /// Delete progress updated
        case updateProgress(Double)

        /// Delete operation completed
        case deleteCompleted(Result<Void, Error>)

        /// Delete operation has been confirmed (notifies parent to reload)
        case deletionConfirmed

        /// Single session deleted
        case singleSessionDeleted(Result<String, Error>)

        // MARK: - Equatable

        public static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.loadSessions, .loadSessions),
                 (.selectAllSessions, .selectAllSessions),
                 (.deselectAllSessions, .deselectAllSessions),
                 (.confirmDelete, .confirmDelete),
                 (.cancelDelete, .cancelDelete),
                 (.reset, .reset),
                 (.deletionConfirmed, .deletionConfirmed),
                 (.showDeleteAllConfirmation, .showDeleteAllConfirmation),
                 (.showDeleteSessionsConfirmation, .showDeleteSessionsConfirmation),
                 (.dismissConfirmationDialog, .dismissConfirmationDialog),
                 (.confirmDeleteAll, .confirmDeleteAll):
                return true
            case (.toggleSession(let l), .toggleSession(let r)):
                return l == r
            case (.deleteSingleSession(let l), .deleteSingleSession(let r)):
                return l == r
            case (.sessionsLoaded(let l), .sessionsLoaded(let r)):
                return l == r
            case (.loadingSessionsFailed(let l), .loadingSessionsFailed(let r)):
                return l.localizedDescription == r.localizedDescription
            case (.updateProgress(let l), .updateProgress(let r)):
                return l == r
            case (.deleteCompleted(let l), .deleteCompleted(let r)):
                switch (l, r) {
                case (.success, .success):
                    return true
                case (.failure(let lErr), .failure(let rErr)):
                    return lErr.localizedDescription == rErr.localizedDescription
                default:
                    return false
                }
            case (.singleSessionDeleted(let l), .singleSessionDeleted(let r)):
                switch (l, r) {
                case (.success(let lId), .success(let rId)):
                    return lId == rId
                case (.failure(let lErr), .failure(let rErr)):
                    return lErr.localizedDescription == rErr.localizedDescription
                default:
                    return false
                }
            default:
                return false
            }
        }
    }
}

// MARK: - Reducer

extension DeleteFeature {
    /// Delete Reducer
    public struct DeleteReducer: Reducer {
        public typealias State = DeleteFeature.State
        public typealias Action = DeleteFeature.Action

        private let environment: Environment

        public init(environment: Environment) {
            self.environment = environment
        }

        public func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            // MARK: - Load Sessions

            case .loadSessions:
                return handleLoadSessions(&state)

            case .sessionsLoaded(let sessions):
                state.isLoadingSessions = false
                state.availableSessions = sessions
                state.error = nil
                return .none

            case .loadingSessionsFailed(let error):
                state.isLoadingSessions = false
                state.error = error
                return .none

            // MARK: - Session Selection

            case .toggleSession(let sessionId):
                if state.selectedSessionIds.contains(sessionId) {
                    state.selectedSessionIds.remove(sessionId)
                } else {
                    state.selectedSessionIds.insert(sessionId)
                }
                return .none

            case .selectAllSessions:
                state.selectAllSessions()
                return .none

            case .deselectAllSessions:
                state.deselectAllSessions()
                return .none

            case .reset:
                state.reset()
                return .none

            // MARK: - Confirmation Dialogs

            case .showDeleteAllConfirmation:
                state.confirmationDialog = .deleteAll
                return .none

            case .showDeleteSessionsConfirmation:
                guard !state.selectedSessionIds.isEmpty else {
                    state.confirmationDialog = .error(String(localized: "no_sessions_selected", bundle: .module))
                    return .none
                }
                state.confirmationDialog = .deleteSelectedSessions
                return .none

            case .dismissConfirmationDialog:
                state.confirmationDialog = nil
                return .none

            // MARK: - Delete Operations

            case .confirmDeleteAll:
                state.confirmationDialog = nil
                // 选中所有会话，复用现有的 confirmDelete 逻辑
                state.selectedSessionIds = Set(state.availableSessions.map { $0.id })
                return .send(.confirmDelete)

            case .confirmDelete:
                return handleConfirmDelete(&state)

            case .deleteSingleSession(let sessionId):
                state.isDeleting = true
                return .task { [environment] in
                    do {
                        try await environment.databaseManager.deleteSession(sessionId)
                        return .singleSessionDeleted(.success(sessionId))
                    } catch {
                        return .singleSessionDeleted(.failure(error))
                    }
                }

            case .updateProgress(let progress):
                state.deleteProgress = progress
                return .none

            case .deleteCompleted(let result):
                return handleDeleteCompleted(&state, result: result)

            case .singleSessionDeleted(let result):
                state.isDeleting = false
                switch result {
                case .success(let sessionId):
                    state.availableSessions.removeAll { $0.id == sessionId }
                    state.selectedSessionIds.remove(sessionId)
                    return .send(.loadSessions)  // 重新加载列表以确保同步
                case .failure(let error):
                    state.confirmationDialog = .error(error.localizedDescription)
                    return .none
                }

            case .cancelDelete:
                state.isDeleting = false
                state.deleteProgress = 0
                return .none

            case .deletionConfirmed:
                // 由父 Reducer 处理 (触发列表重新加载)
                return .none
            }
        }

        // MARK: - Private Handlers

        private func handleLoadSessions(_ state: inout State) -> Effect<Action> {
            state.isLoadingSessions = true
            state.error = nil

            return .task { [environment] in
                do {
                    print("🔵 [DeleteFeature] Loading available sessions...")

                    let sessions = try await environment.databaseManager.getAvailableSessions()

                    print("🟢 [DeleteFeature] Sessions loaded: \(sessions.count) sessions")

                    return .sessionsLoaded(sessions)
                } catch {
                    print("🔴 [DeleteFeature] Failed to load sessions: \(error.localizedDescription)")
                    return .loadingSessionsFailed(error)
                }
            }
        }

        private func handleConfirmDelete(_ state: inout State) -> Effect<Action> {
            guard !state.selectedSessionIds.isEmpty else {
                print("⚠️ [DeleteFeature] No sessions selected for deletion")
                return .none
            }

            state.isDeleting = true
            state.deleteProgress = 0
            state.error = nil

            let sessionIds = state.selectedSessionIds

            return .cancellable(id: "delete-sessions") { [environment] in
                do {
                    print("🔵 [DeleteFeature] Deleting \(sessionIds.count) sessions...")

                    let totalCount = sessionIds.count
                    var completedCount = 0

                    for sessionId in sessionIds {
                        try await environment.databaseManager.deleteSession(sessionId)

                        completedCount += 1

                        print("🟡 [DeleteFeature] Deleted session \(sessionId) (\(completedCount)/\(totalCount))")

                        // 注意：进度更新需要通过独立的 Effect 发送
                        // 这里简化处理，实际应该发送 .updateProgress(progress)
                    }

                    print("🟢 [DeleteFeature] All sessions deleted successfully")

                    return .deleteCompleted(.success(()))
                } catch {
                    print("🔴 [DeleteFeature] Failed to delete sessions: \(error.localizedDescription)")
                    return .deleteCompleted(.failure(error))
                }
            }
        }

        private func handleDeleteCompleted(_ state: inout State, result: Result<Void, Error>) -> Effect<Action> {
            state.isDeleting = false

            switch result {
            case .success:
                state.reset()
                // 通知父 Reducer 删除完成
                return .send(.deletionConfirmed)

            case .failure(let error):
                state.confirmationDialog = .error(error.localizedDescription)  // ✅ 新增错误对话框
                state.deleteProgress = 0
                return .none
            }
        }
    }
}

// MARK: - Environment

extension DeleteFeature {
    /// Delete Environment (依赖注入)
    public struct Environment {
        /// Database manager for session operations
        let databaseManager: LogDatabaseManagerProtocol

        // MARK: - Initialization

        public init(databaseManager: LogDatabaseManagerProtocol) {
            self.databaseManager = databaseManager
        }

        // MARK: - Live Environment

        @MainActor
        public static func live() -> Environment {
            guard let dbManager = LoggerEngine.shared.getDatabaseManager() else {
                fatalError("DatabaseManager not initialized. Call LoggerEngine.shared.setup() first.")
            }

            return Environment(
                databaseManager: dbManager
            )
        }

        // MARK: - Mock Environment (for testing)

        public static func mock(
            databaseManager: LogDatabaseManagerProtocol
        ) -> Environment {
            Environment(
                databaseManager: databaseManager
            )
        }
    }
}

// MARK: - Effect Extension

extension Effect where Action == DeleteFeature.Action {
    /// Send an action immediately
    static func send(_ action: Action) -> Effect<Action> {
        return .task { action }
    }
}
