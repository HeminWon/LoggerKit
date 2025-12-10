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
        !sceneState.searchText.isEmpty && !sceneState.searchResults.isEmpty
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 搜索区域（含实时预览）
                    SearchPreviewSection(sceneState: sceneState) {
                        // 添加筛选后清空搜索框，退出预览模式
                        sceneState.searchText = ""
                    }

                    // 预览模式下不显示其他筛选条件
                    if !isInPreviewMode {
                        Divider()

                        // 消息关键词筛选
                        if !sceneState.selectedMessageKeywords.isEmpty {
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
                                selectedOptions: $sceneState.selectedContexts
                            )
                            Divider()
                        }

                        // 文件筛选（折叠式）
                        if !sceneState.availableFileNames.isEmpty {
                            CollapsibleFilterSection(
                                title: String(localized: "search_field_file", bundle: .module),
                                options: sceneState.availableFileNames,
                                selectedOptions: $sceneState.selectedFileNames
                            )
                            Divider()
                        }

                        // 函数筛选（折叠式）
                        if !sceneState.availableFunctions.isEmpty {
                            CollapsibleFilterSection(
                                title: String(localized: "search_field_function", bundle: .module),
                                options: sceneState.availableFunctions,
                                selectedOptions: $sceneState.selectedFunctions
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
                                selectedOptions: $sceneState.selectedThreads
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
                        Text(String(format: String(localized: "match_count", bundle: .module), sceneState.filteredEvents.count))
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
                Text("(\(sceneState.selectedMessageKeywords.count))")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Button(String(localized: "clear_button", bundle: .module)) {
                    sceneState.selectedMessageKeywords.removeAll()
                }
                .font(.caption)
                .foregroundColor(.red)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(sceneState.selectedMessageKeywords).sorted(), id: \.self) { keyword in
                        HStack(spacing: 4) {
                            Text(keyword)
                                .font(.caption)
                                .lineLimit(1)
                            Button(action: {
                                sceneState.selectedMessageKeywords.remove(keyword)
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
                Button(sceneState.selectedLevels.count == 5 ? String(localized: "clear_button", bundle: .module) : String(localized: "select_all_button", bundle: .module)) {
                    if sceneState.selectedLevels.count == 5 {
                        sceneState.selectedLevels.removeAll()
                    } else {
                        sceneState.selectedLevels = [.verbose, .debug, .info, .warning, .error]
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
                            isSelected: sceneState.selectedLevels.contains(level),
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
                Spacer()
                if let _ = sceneState.selectedSessionId {
                    Button(String(localized: "clear_button", bundle: .module)) {
                        sceneState.selectedSessionId = nil
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
                                isSelected: sceneState.selectedSessionId == session.id
                            ) {
                                if sceneState.selectedSessionId == session.id {
                                    sceneState.selectedSessionId = nil
                                } else {
                                    sceneState.selectedSessionId = session.id
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

    var body: some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
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
        logFileURL: URL(fileURLWithPath: "/tmp/test.log"),
        prefix: "test",
        identifier: "123"
    ))
}
