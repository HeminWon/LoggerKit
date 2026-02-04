//
//  LogFilterSheet.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/21.
//

import SwiftUI

/// 半屏筛选面板
struct LogFilterSheet: View {
    @ObservedObject var viewStore: LogDetailViewStore
    @Environment(\.dismiss) private var dismiss

    // 使用 ViewStore 初始化
    init(viewStore: LogDetailViewStore) {
        self.viewStore = viewStore
    }

    /// 是否处于预览模式：有搜索文本且有匹配结果
    private var isInPreviewMode: Bool {
        !viewStore.searchText.isEmpty && !viewStore.searchResults.isEmpty
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 搜索区域（含实时预览）
                    SearchPreviewSection(viewStore: viewStore) {
                        // 添加筛选后清空搜索框，退出预览模式
                        viewStore.send(.search(.updateSearchText("")))
                    }

                    // 预览模式下不显示其他筛选条件
                    if !isInPreviewMode {
                        Divider()

                        // 消息关键词筛选
                        if !viewStore.state.filterFeature.selectedMessageKeywords.isEmpty {
                            messageKeywordsSection
                            Divider()
                        }

                        // 日志等级
                        levelSection

                        Divider()

                        // 模块筛选（折叠式）
                        if !viewStore.availableContexts.isEmpty {
                            CollapsibleFilterSection(
                                title: String(localized: "search_field_context", bundle: .loggerKit),
                                options: viewStore.availableContexts,
                                selectedOptions: viewStore.selectedContexts,
                                onToggle: { viewStore.send(.filter(.updateFilter(.context, .toggle($0)))) },
                                onSelectAll: { viewStore.send(.filter(.updateFilter(.context, .selectAll))) },
                                onClear: { viewStore.send(.filter(.updateFilter(.context, .clear))) }
                            )
                            Divider()
                        }

                        // 文件筛选（折叠式）
                        if !viewStore.availableFileNames.isEmpty {
                            CollapsibleFilterSection(
                                title: String(localized: "search_field_file", bundle: .loggerKit),
                                options: viewStore.availableFileNames,
                                selectedOptions: viewStore.selectedFileNames,
                                onToggle: { viewStore.send(.filter(.updateFilter(.fileName, .toggle($0)))) },
                                onSelectAll: { viewStore.send(.filter(.updateFilter(.fileName, .selectAll))) },
                                onClear: { viewStore.send(.filter(.updateFilter(.fileName, .clear))) }
                            )
                            Divider()
                        }

                        // 函数筛选（折叠式）
                        if !viewStore.availableFunctions.isEmpty {
                            CollapsibleFilterSection(
                                title: String(localized: "search_field_function", bundle: .loggerKit),
                                options: viewStore.availableFunctions,
                                selectedOptions: viewStore.selectedFunctions,
                                onToggle: { viewStore.send(.filter(.updateFilter(.function, .toggle($0)))) },
                                onSelectAll: { viewStore.send(.filter(.updateFilter(.function, .selectAll))) },
                                onClear: { viewStore.send(.filter(.updateFilter(.function, .clear))) }
                            )
                            Divider()
                        }

                        // 会话筛选
                        SessionFilterSection(viewStore: viewStore)
                        Divider()

                        // 线程筛选（折叠式）
                        if !viewStore.availableThreads.isEmpty {
                            CollapsibleFilterSection(
                                title: String(localized: "search_field_thread", bundle: .loggerKit),
                                options: viewStore.availableThreads,
                                selectedOptions: viewStore.selectedThreads,
                                onToggle: { viewStore.send(.filter(.updateFilter(.thread, .toggle($0)))) },
                                onSelectAll: { viewStore.send(.filter(.updateFilter(.thread, .selectAll))) },
                                onClear: { viewStore.send(.filter(.updateFilter(.thread, .clear))) }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "filter_title", bundle: .loggerKit))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(String(localized: "filter_title", bundle: .loggerKit))
                            .font(.headline)
                        Text(String(format: String(localized: "match_count", bundle: .loggerKit), viewStore.totalCount))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "reset_button", bundle: .loggerKit)) {
                        viewStore.resetFilters()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done_button", bundle: .loggerKit)) {
                        dismiss()
                    }
                }
            }
            .task {
                // 打开筛选页面时加载全量选项
                viewStore.send(.filter(.loadAvailableOptions))
            }
        }
    }

    // MARK: - 消息关键词筛选
    private var messageKeywordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "message_keywords", bundle: .loggerKit))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(viewStore.state.filterFeature.selectedMessageKeywords.count))")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Button(String(localized: "clear_button", bundle: .loggerKit)) {
                    // 逐个移除所有关键词
                    viewStore.selectedMessageKeywords.forEach { keyword in
                        viewStore.send(.filter(.updateFilter(.messageKeyword, .toggle(keyword))))
                    }
                }
                .font(.caption)
                .foregroundColor(.red)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewStore.state.filterFeature.selectedMessageKeywords).sorted(), id: \.self) { keyword in
                        HStack(spacing: 4) {
                            Text(keyword)
                                .font(.caption)
                                .lineLimit(1)
                            Button(action: {
                                viewStore.send(.filter(.updateFilter(.messageKeyword, .toggle(keyword))))
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
                Text(String(localized: "log_level", bundle: .loggerKit))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(viewStore.selectedLevels.count == 5 ? String(localized: "clear_button", bundle: .loggerKit) : String(localized: "select_all_button", bundle: .loggerKit)) {
                    if viewStore.selectedLevels.count == 5 {
                        // 清除所有:逐个toggle
                        [LogEvent.Level.verbose, .debug, .info, .warning, .error].forEach { level in
                            if viewStore.selectedLevels.contains(level) {
                                viewStore.send(.filter(.toggleLevel(level)))
                            }
                        }
                    } else {
                        // 全选:逐个toggle
                        [LogEvent.Level.verbose, .debug, .info, .warning, .error].forEach { level in
                            if !viewStore.selectedLevels.contains(level) {
                                viewStore.send(.filter(.toggleLevel(level)))
                            }
                        }
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
                            isSelected: viewStore.state.filterFeature.selectedLevels.contains(level),
                            color: level.color
                        ) {
                            viewStore.toggleLevel(level)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 会话筛选 Section
struct SessionFilterSection: View {
    @ObservedObject var viewStore: LogDetailViewStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "session_filter_title", bundle: .loggerKit))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(viewStore.selectedSessionIds.count))")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()

                if !viewStore.selectedSessionIds.isEmpty {
                    Button(String(localized: "clear_button", bundle: .loggerKit)) {
                        viewStore.send(.filter(.clearSessionIds))
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }

            // 使用 ViewStore 状态
            if viewStore.isLoadingSessions {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let errorMessage = viewStore.sessionLoadingError {
                // 错误展示
                VStack(spacing: 4) {
                    Text(String(localized: "session_load_failed", bundle: .loggerKit))
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Button(String(localized: "retry_button", bundle: .loggerKit)) {
                        viewStore.send(.filter(.loadSessions))
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if viewStore.availableSessions.isEmpty {
                Text(String(localized: "session_empty_message", bundle: .loggerKit))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 使用 ViewStore 中的会话列表
                        ForEach(viewStore.availableSessions) { session in
                            SessionChip(
                                session: session,
                                isSelected: viewStore.selectedSessionIds.contains(session.id)
                            ) {
                                viewStore.send(.filter(.updateFilter(.sessionId, .toggle(session.id))))
                            }
                        }
                    }
                }
            }
        }
        .task {
            // 通过 Action 触发加载（缓存机制在 Reducer 中处理）
            viewStore.send(.filter(.loadSessions))
        }
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

                            Text(String(format: String(localized: "session_log_count", bundle: .loggerKit), session.logCount))
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

                    Text(String(format: String(localized: "session_log_count", bundle: .loggerKit), session.logCount))
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
                    Label(String(localized: "delete_session_context_menu", bundle: .loggerKit), systemImage: "trash")
                }
            }
        }
        // 删除确认对话框（仅在删除模式下显示）
        .alert(String(format: String(localized: "delete_session_confirmation_title", bundle: .loggerKit), session.id), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "cancel_button", bundle: .loggerKit), role: .cancel) { }
            Button(String(localized: "delete_button", bundle: .loggerKit), role: .destructive) {
                onDelete?(session.id)
            }
        } message: {
            Text(String(format: String(localized: "delete_session_confirmation_message", bundle: .loggerKit), session.logCount))
        }
    }

    private var formattedDate: String {
        let date = Date(timeIntervalSince1970: session.startTime)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - FilterSectionWrapper (临时包装器,简化 ViewStore 使用)
#Preview {
    LogFilterSheet(viewStore: LoggerKit.makeViewStore())
}
