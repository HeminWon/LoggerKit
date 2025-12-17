//
//  LogFilterSheet.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/21.
//

import SwiftUI

/// 半屏筛选面板
struct LogFilterSheet: View {
    @ObservedObject var sceneState: LogDetailSceneState
    @Environment(\.dismiss) private var dismiss

    /// 是否处于预览模式：有搜索文本且有匹配结果
    private var isInPreviewMode: Bool {
        !sceneState.searchState.searchText.isEmpty && !sceneState.searchState.cachedResults.isEmpty
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 搜索区域（含实时预览）
                    SearchPreviewSection(sceneState: sceneState) {
                        // 添加筛选后清空搜索框，退出预览模式
                        sceneState.searchState.searchText = ""
                    }

                    // 预览模式下不显示其他筛选条件
                    if !isInPreviewMode {
                        Divider()

                        // 消息关键词筛选
                        if !sceneState.filterState.selectedMessageKeywords.isEmpty {
                            messageKeywordsSection
                            Divider()
                        }

                        // 日志等级
                        levelSection

                        Divider()

                        // 模块筛选（折叠式）
                        if !sceneState.availableContexts.isEmpty {
                            CollapsibleFilterSection(
                                title: String(localized: "search_field_context", bundle: .module),
                                options: sceneState.availableContexts,
                                selectedOptions: $sceneState.filterState.selectedContexts
                            )
                            Divider()
                        }

                        // 文件筛选（折叠式）
                        if !sceneState.availableFileNames.isEmpty {
                            CollapsibleFilterSection(
                                title: String(localized: "search_field_file", bundle: .module),
                                options: sceneState.availableFileNames,
                                selectedOptions: $sceneState.filterState.selectedFileNames
                            )
                            Divider()
                        }

                        // 函数筛选（折叠式）
                        if !sceneState.availableFunctions.isEmpty {
                            CollapsibleFilterSection(
                                title: String(localized: "search_field_function", bundle: .module),
                                options: sceneState.availableFunctions,
                                selectedOptions: $sceneState.filterState.selectedFunctions
                            )
                            Divider()
                        }

                        // 会话筛选
                        SessionFilterSection(sceneState: sceneState)
                        Divider()

                        // 线程筛选（折叠式）
                        if !sceneState.availableThreads.isEmpty {
                            CollapsibleFilterSection(
                                title: String(localized: "search_field_thread", bundle: .module),
                                options: sceneState.availableThreads,
                                selectedOptions: $sceneState.filterState.selectedThreads
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "filter_title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(String(localized: "filter_title", bundle: .module))
                            .font(.headline)
                        Text(String(format: String(localized: "match_count", bundle: .module), sceneState.displayEvents.count))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "reset_button", bundle: .module)) {
                        sceneState.resetFilters()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done_button", bundle: .module)) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 消息关键词筛选
    private var messageKeywordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "message_keywords", bundle: .module))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(sceneState.filterState.selectedMessageKeywords.count))")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Button(String(localized: "clear_button", bundle: .module)) {
                    sceneState.filterState.selectedMessageKeywords.removeAll()
                }
                .font(.caption)
                .foregroundColor(.red)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(sceneState.filterState.selectedMessageKeywords).sorted(), id: \.self) { keyword in
                        HStack(spacing: 4) {
                            Text(keyword)
                                .font(.caption)
                                .lineLimit(1)
                            Button(action: {
                                sceneState.filterState.selectedMessageKeywords.remove(keyword)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - 日志等级
    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "log_level", bundle: .module))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(sceneState.filterState.selectedLevels.count == 5 ? String(localized: "clear_button", bundle: .module) : String(localized: "select_all_button", bundle: .module)) {
                    if sceneState.filterState.selectedLevels.count == 5 {
                        sceneState.filterState.selectedLevels.removeAll()
                    } else {
                        sceneState.filterState.selectedLevels = [.verbose, .debug, .info, .warning, .error]
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([LogEvent.Level.verbose, .debug, .info, .warning, .error], id: \.self) { level in
                        FilterChip(
                            title: level.severity,
                            isSelected: sceneState.filterState.selectedLevels.contains(level),
                            color: level.color
                        ) {
                            sceneState.toggleLevel(level)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 会话筛选 Section
struct SessionFilterSection: View {
    @ObservedObject var sceneState: LogDetailSceneState
    @State private var sessions: [SessionInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "session_filter_title", bundle: .module))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(sceneState.filterState.selectedSessionIds.count))")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                if !sceneState.filterState.selectedSessionIds.isEmpty {
                    Button(String(localized: "clear_button", bundle: .module)) {
                        sceneState.filterState.selectedSessionIds.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if sessions.isEmpty {
                Text(String(localized: "session_empty_message", bundle: .module))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sessions) { session in
                            SessionChip(
                                session: session,
                                isSelected: sceneState.filterState.selectedSessionIds.contains(session.id)
                            ) {
                                if sceneState.filterState.selectedSessionIds.contains(session.id) {
                                    sceneState.filterState.selectedSessionIds.remove(session.id)
                                } else {
                                    sceneState.filterState.selectedSessionIds.insert(session.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadSessions()
        }
    }

    private func loadSessions() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let dbManager = LoggerEngine.shared.getDatabaseManager() else {
                errorMessage = "Database manager not available"
                isLoading = false
                return
            }

            let loadedSessions = try await Task.detached {
                try dbManager.fetchAllSessions()
            }.value

            sessions = loadedSessions
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - 会话芯片
struct SessionChip: View {
    let session: SessionInfo
    let isSelected: Bool
    let action: () -> Void
    let onDelete: ((String) -> Void)? // 可选的删除回调
    let fullWidth: Bool // 是否全宽显示（纵向列表模式）

    @State private var showDeleteConfirmation = false

    // 提供默认初始化器，让 onDelete 和 fullWidth 可选
    init(
        session: SessionInfo,
        isSelected: Bool,
        action: @escaping () -> Void,
        onDelete: ((String) -> Void)? = nil,
        fullWidth: Bool = false
    ) {
        self.session = session
        self.isSelected = isSelected
        self.action = action
        self.onDelete = onDelete
        self.fullWidth = fullWidth
    }

    var body: some View {
        Button(action: action) {
            if fullWidth {
                // 全宽列表项样式（用于纵向列表）
                HStack(spacing: 12) {
                    // 左侧：会话信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.id)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 8) {
                            Text(formattedDate)
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)

                            Text("•")
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.6) : .secondary)

                            Text(String(format: String(localized: "session_log_count", bundle: .module), session.logCount))
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                    }

                    Spacer()

                    // 右侧：选中图标
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                )
            } else {
                // 紧凑卡片样式（用于横向滚动）
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(session.id)
                            .font(.caption)
                            .fontWeight(.medium)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                        }
                    }

                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)

                    Text(String(format: String(localized: "session_log_count", bundle: .module), session.logCount))
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
        // 仅当提供 onDelete 回调时显示 Context Menu
        .contextMenu {
            if onDelete != nil {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(String(localized: "delete_session_context_menu", bundle: .module), systemImage: "trash")
                }
            }
        }
        // 删除确认对话框（仅在删除模式下显示）
        .alert(String(format: String(localized: "delete_session_confirmation_title", bundle: .module), session.id), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "cancel_button", bundle: .module), role: .cancel) { }
            Button(String(localized: "delete_button", bundle: .module), role: .destructive) {
                onDelete?(session.id)
            }
        } message: {
            Text(String(format: String(localized: "delete_session_confirmation_message", bundle: .module), session.logCount))
        }
    }

    private var formattedDate: String {
        let date = Date(timeIntervalSince1970: session.startTime)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    LogFilterSheet(sceneState: LogDetailSceneState(
        prefix: "test",
        identifier: "123"
    ))
}
