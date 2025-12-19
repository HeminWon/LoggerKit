//
//  LogDeleteManagementSheet.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025-12-17.
//

import SwiftUI

/// 日志删除管理面板
struct LogDeleteManagementSheet: View {
    @ObservedObject var viewStore: LogDetailViewStore
    @Environment(\.dismiss) private var dismiss

    @State private var sessions: [SessionInfo] = []
    @State private var selectedSessionIds: Set<String> = []
    @State private var isLoading = false
    @State private var showDeleteAllConfirmation = false
    @State private var showDeleteSessionsConfirmation = false
    @State private var deleteError: LogDatabaseError?
    @State private var showError = false

    // 向后兼容:支持 SceneState 初始化
    init(sceneState: LogDetailSceneState) {
        self.viewStore = ViewStore(store: sceneState.store)
    }

    // 推荐:使用 ViewStore 初始化
    init(viewStore: LogDetailViewStore) {
        self.viewStore = viewStore
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. 删除所有日志区域
                    deleteAllSection

                    Divider()

                    // 2. 按 Session 删除区域
                    deleteBySessionSection
                }
                .padding()
            }
            .navigationTitle(String(localized: "delete_management_title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done_button", bundle: .module)) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadSessions()
        }
        // 删除所有日志确认对话框
        .alert(String(localized: "delete_all_confirmation_title", bundle: .module), isPresented: $showDeleteAllConfirmation) {
            Button(String(localized: "cancel_button", bundle: .module), role: .cancel) { }
            Button(String(localized: "delete_button", bundle: .module), role: .destructive) {
                deleteAllLogs()
            }
        } message: {
            Text(String(localized: "delete_all_confirmation_message", bundle: .module))
        }
        // 删除选中 Session 确认对话框
        .alert(String(localized: "delete_sessions_confirmation_title", bundle: .module), isPresented: $showDeleteSessionsConfirmation) {
            Button(String(localized: "cancel_button", bundle: .module), role: .cancel) { }
            Button(String(localized: "delete_button", bundle: .module), role: .destructive) {
                deleteSelectedSessions()
            }
        } message: {
            Text(String(format: String(localized: "delete_sessions_confirmation_message", bundle: .module), selectedSessionIds.count))
        }
        // 错误提示
        .alert(String(localized: "delete_failed_title", bundle: .module), isPresented: $showError) {
            Button(String(localized: "confirm_button", bundle: .module), role: .cancel) { }
        } message: {
            if let error = deleteError {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - 删除所有日志区域
    private var deleteAllSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "delete_all_logs_title", bundle: .module))
                        .font(.headline)
                    Text(String(localized: "delete_all_logs_description", bundle: .module))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Button {
                showDeleteAllConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text(String(localized: "delete_all_logs_button", bundle: .module))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 按 Session 删除区域
    private var deleteBySessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "delete_by_session_title", bundle: .module))
                        .font(.headline)
                    if !selectedSessionIds.isEmpty {
                        Text(String(format: String(localized: "selected_sessions_count", bundle: .module), selectedSessionIds.count))
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Text(String(localized: "delete_by_session_description", bundle: .module))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                // 全选/清空按钮
                if !sessions.isEmpty {
                    if selectedSessionIds.isEmpty {
                        Button(String(localized: "select_all", bundle: .module)) {
                            selectedSessionIds = Set(sessions.map { $0.id })
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    } else {
                        Button(String(localized: "empty", bundle: .module)) {
                            selectedSessionIds.removeAll()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            }

            // Session 列表
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if sessions.isEmpty {
                Text(String(localized: "no_session_records", bundle: .module))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                sessionList
            }

            // 删除选中会话按钮
            if !selectedSessionIds.isEmpty {
                Button {
                    showDeleteSessionsConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text(String(format: String(localized: "delete_selected_sessions_button", bundle: .module), selectedSessionIds.count))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
            }
        }
    }

    // Session 芯片列表
    private var sessionList: some View {
        VStack(spacing: 8) {
            ForEach(sessions) { session in
                // 复用 SessionChip，通过 onDelete 参数启用删除功能，fullWidth 启用全宽列表样式
                SessionChip(
                    session: session,
                    isSelected: selectedSessionIds.contains(session.id),
                    action: {
                        if selectedSessionIds.contains(session.id) {
                            selectedSessionIds.remove(session.id)
                        } else {
                            selectedSessionIds.insert(session.id)
                        }
                    },
                    onDelete: { sessionId in
                        Task {
                            await deleteSingleSession(sessionId)
                        }
                    },
                    fullWidth: true
                )
            }
        }
    }

    // MARK: - 数据加载
    private func loadSessions() async {
        isLoading = true

        do {
            guard let dbManager = LoggerEngine.shared.getDatabaseManager() else {
                throw LogDatabaseError.databaseNotAvailable
            }

            let loadedSessions = try await Task.detached {
                try dbManager.fetchAllSessions()
            }.value

            sessions = loadedSessions
        } catch {
            deleteError = error as? LogDatabaseError ?? .deleteFailed(underlying: error)
            showError = true
        }

        isLoading = false
    }

    // MARK: - 删除操作
    private func deleteAllLogs() {
        Task {
            do {
                try await viewStore.deleteAllLogsAsync()
                dismiss()
            } catch {
                deleteError = error as? LogDatabaseError ?? .deleteFailed(underlying: error)
                showError = true
            }
        }
    }

    private func deleteSelectedSessions() {
        Task {
            do {
                try await viewStore.deleteSessions(selectedSessionIds)

                // 清空选中状态
                selectedSessionIds.removeAll()

                // 重新加载会话列表
                await loadSessions()
            } catch {
                deleteError = error as? LogDatabaseError ?? .deleteFailed(underlying: error)
                showError = true
            }
        }
    }

    private func deleteSingleSession(_ sessionId: String) async {
        do {
            try await viewStore.deleteSession(sessionId)

            // 从选中列表移除
            selectedSessionIds.remove(sessionId)

            // 重新加载会话列表
            await loadSessions()
        } catch {
            deleteError = error as? LogDatabaseError ?? .deleteFailed(underlying: error)
            showError = true
        }
    }
}
