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

    // 使用 ViewStore 初始化
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
            viewStore.send(.delete(.loadSessions))
        }
        // 删除所有日志确认对话框
        .alert(String(localized: "delete_all_confirmation_title", bundle: .module), isPresented: viewStore.binding(
            get: { $0.deleteFeature.showDeleteAllConfirmation },
            send: { _ in .delete(.dismissConfirmationDialog) }
        )) {
            Button(String(localized: "cancel_button", bundle: .module), role: .cancel) {
                viewStore.send(.delete(.dismissConfirmationDialog))
            }
            Button(String(localized: "delete_button", bundle: .module), role: .destructive) {
                viewStore.send(.delete(.confirmDeleteAll))
            }
        } message: {
            Text(String(localized: "delete_all_confirmation_message", bundle: .module))
        }
        // 删除选中 Session 确认对话框
        .alert(String(localized: "delete_sessions_confirmation_title", bundle: .module), isPresented: viewStore.binding(
            get: { $0.deleteFeature.showDeleteSessionsConfirmation },
            send: { _ in .delete(.dismissConfirmationDialog) }
        )) {
            Button(String(localized: "cancel_button", bundle: .module), role: .cancel) {
                viewStore.send(.delete(.dismissConfirmationDialog))
            }
            Button(String(localized: "delete_button", bundle: .module), role: .destructive) {
                viewStore.send(.delete(.confirmDelete))
            }
        } message: {
            Text(String(format: String(localized: "delete_sessions_confirmation_message", bundle: .module), viewStore.state.deleteFeature.selectedSessionCount))
        }
        // 错误提示
        .alert(String(localized: "delete_failed_title", bundle: .module), isPresented: viewStore.binding(
            get: { $0.deleteFeature.showError },
            send: { _ in .delete(.dismissConfirmationDialog) }
        )) {
            Button(String(localized: "confirm_button", bundle: .module), role: .cancel) {
                viewStore.send(.delete(.dismissConfirmationDialog))
            }
        } message: {
            if case .error(let errorMessage) = viewStore.state.deleteFeature.confirmationDialog {
                Text(errorMessage)
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
                viewStore.send(.delete(.showDeleteAllConfirmation))
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
        // 提取 deleteFeature 状态，避免重复访问嵌套路径
        let deleteState = viewStore.state.deleteFeature

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "delete_by_session_title", bundle: .module))
                        .font(.headline)
                    if !deleteState.selectedSessionIds.isEmpty {
                        Text(String(format: String(localized: "selected_sessions_count", bundle: .module), deleteState.selectedSessionCount))
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
                if !deleteState.availableSessions.isEmpty {
                    if deleteState.selectedSessionIds.isEmpty {
                        Button(String(localized: "select_all", bundle: .module)) {
                            viewStore.send(.delete(.selectAllSessions))
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    } else {
                        Button(String(localized: "empty", bundle: .module)) {
                            viewStore.send(.delete(.deselectAllSessions))
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            }

            // Session 列表
            if deleteState.isLoadingSessions {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if deleteState.availableSessions.isEmpty {
                Text(String(localized: "no_session_records", bundle: .module))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                sessionList
            }

            // 删除选中会话按钮
            if !deleteState.selectedSessionIds.isEmpty {
                Button {
                    viewStore.send(.delete(.showDeleteSessionsConfirmation))
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text(String(format: String(localized: "delete_selected_sessions_button", bundle: .module), deleteState.selectedSessionCount))
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
        // 提取 deleteFeature 状态，避免重复访问嵌套路径
        let deleteState = viewStore.state.deleteFeature

        return VStack(spacing: 8) {
            ForEach(deleteState.availableSessions) { session in
                // 复用 SessionChip，通过 onDelete 参数启用删除功能，fullWidth 启用全宽列表样式
                SessionChip(
                    session: session,
                    isSelected: deleteState.selectedSessionIds.contains(session.id),
                    action: {
                        viewStore.send(.delete(.toggleSession(session.id)))
                    },
                    onDelete: { sessionId in
                        viewStore.send(.delete(.deleteSingleSession(sessionId)))
                    },
                    fullWidth: true
                )
            }
        }
    }
}
