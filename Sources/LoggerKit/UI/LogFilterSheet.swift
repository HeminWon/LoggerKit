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

                        // 模块筛选（折叠式） - 临时使用 State,未来版本将重构
                        if !viewStore.availableContexts.isEmpty {
                            FilterSectionWrapper(
                                title: String(localized: "search_field_context", bundle: .module),
                                options: viewStore.availableContexts,
                                selected: viewStore.selectedContexts,
                                onAdd: { viewStore.send(.filter(.addContext($0))) },
                                onRemove: { viewStore.send(.filter(.removeContext($0))) },
                                onSelectAll: {
                                    viewStore.availableContexts.forEach { viewStore.send(.filter(.addContext($0))) }
                                },
                                onClear: {
                                    viewStore.selectedContexts.forEach { viewStore.send(.filter(.removeContext($0))) }
                                }
                            )
                            Divider()
                        }

                        // 文件筛选（折叠式）
                        if !viewStore.availableFileNames.isEmpty {
                            FilterSectionWrapper(
                                title: String(localized: "search_field_file", bundle: .module),
                                options: viewStore.availableFileNames,
                                selected: viewStore.selectedFileNames,
                                onAdd: { viewStore.send(.filter(.addFileName($0))) },
                                onRemove: { viewStore.send(.filter(.removeFileName($0))) },
                                onSelectAll: {
                                    viewStore.availableFileNames.forEach { viewStore.send(.filter(.addFileName($0))) }
                                },
                                onClear: {
                                    viewStore.selectedFileNames.forEach { viewStore.send(.filter(.removeFileName($0))) }
                                }
                            )
                            Divider()
                        }

                        // 函数筛选（折叠式）
                        if !viewStore.availableFunctions.isEmpty {
                            FilterSectionWrapper(
                                title: String(localized: "search_field_function", bundle: .module),
                                options: viewStore.availableFunctions,
                                selected: viewStore.selectedFunctions,
                                onAdd: { viewStore.send(.filter(.addFunction($0))) },
                                onRemove: { viewStore.send(.filter(.removeFunction($0))) },
                                onSelectAll: {
                                    viewStore.availableFunctions.forEach { viewStore.send(.filter(.addFunction($0))) }
                                },
                                onClear: {
                                    viewStore.selectedFunctions.forEach { viewStore.send(.filter(.removeFunction($0))) }
                                }
                            )
                            Divider()
                        }

                        // 会话筛选
                        SessionFilterSection(viewStore: viewStore)
                        Divider()

                        // 线程筛选（折叠式）
                        if !viewStore.availableThreads.isEmpty {
                            FilterSectionWrapper(
                                title: String(localized: "search_field_thread", bundle: .module),
                                options: viewStore.availableThreads,
                                selected: viewStore.selectedThreads,
                                onAdd: { viewStore.send(.filter(.addThread($0))) },
                                onRemove: { viewStore.send(.filter(.removeThread($0))) },
                                onSelectAll: {
                                    viewStore.availableThreads.forEach { viewStore.send(.filter(.addThread($0))) }
                                },
                                onClear: {
                                    viewStore.selectedThreads.forEach { viewStore.send(.filter(.removeThread($0))) }
                                }
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
                        Text(String(format: String(localized: "match_count", bundle: .module), viewStore.displayEvents.count))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "reset_button", bundle: .module)) {
                        viewStore.resetFilters()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done_button", bundle: .module)) {
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
                Text(String(localized: "message_keywords", bundle: .module))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(viewStore.state.filterFeature.selectedMessageKeywords.count))")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Button(String(localized: "clear_button", bundle: .module)) {
                    // 逐个移除所有关键词
                    viewStore.selectedMessageKeywords.forEach { keyword in
                        viewStore.send(.filter(.removeMessageKeyword(keyword)))
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
                                viewStore.send(.filter(.removeMessageKeyword(keyword)))
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
                Button(viewStore.selectedLevels.count == 5 ? String(localized: "clear_button", bundle: .module) : String(localized: "select_all_button", bundle: .module)) {
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
                Text(String(localized: "session_filter_title", bundle: .module))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(viewStore.selectedSessionIds.count))")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()

                if !viewStore.selectedSessionIds.isEmpty {
                    Button(String(localized: "clear_button", bundle: .module)) {
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
                    Text(String(localized: "session_load_failed", bundle: .module))
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Button(String(localized: "retry_button", bundle: .module)) {
                        viewStore.send(.filter(.loadSessions))
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if viewStore.availableSessions.isEmpty {
                Text(String(localized: "session_empty_message", bundle: .module))
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
                                if viewStore.selectedSessionIds.contains(session.id) {
                                    viewStore.send(.filter(.removeSessionId(session.id)))
                                } else {
                                    viewStore.send(.filter(.addSessionId(session.id)))
                                }
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

// MARK: - FilterSectionWrapper (临时包装器,简化 ViewStore 使用)
struct FilterSectionWrapper: View {
    let title: String
    let options: [String]
    let selected: Set<String>
    let onAdd: (String) -> Void
    let onRemove: (String) -> Void
    let onSelectAll: () -> Void
    let onClear: () -> Void

    /// 排序后的选项列表：选中的在前，未选中的在后
    private var sortedOptions: [String] {
        let selectedArray = options.filter { selected.contains($0) }.sorted()
        let unselected = options.filter { !selected.contains($0) }.sorted()
        return selectedArray + unselected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题栏
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !selected.isEmpty {
                    Text("(\(selected.count))")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Spacer()

                if selected.isEmpty {
                    // 没有选中时显示全选按钮
                    Button(String(localized: "select_all_button", bundle: .module)) {
                        onSelectAll()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                } else {
                    // 有选中时显示清除按钮
                    Button(String(localized: "clear_button", bundle: .module)) {
                        onClear()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }

            // 选项列表（水平滚动，使用 LazyHStack 优化性能）
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(sortedOptions, id: \.self) { option in
                        FilterChip(
                            title: truncateText(option, maxLength: 20),
                            isSelected: selected.contains(option)
                        ) {
                            if selected.contains(option) {
                                onRemove(option)
                            } else {
                                onAdd(option)
                            }
                        }
                    }
                }
                .padding(.vertical, 1) // 防止 LazyHStack 裁剪阴影
            }
        }
    }

    private func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count > maxLength {
            return String(text.prefix(maxLength)) + "..."
        }
        return text
    }
}

#Preview {
    LogFilterSheet(viewStore: LoggerKit.makeViewStore())
}
