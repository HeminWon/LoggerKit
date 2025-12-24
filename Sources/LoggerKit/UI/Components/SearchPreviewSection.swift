//
//  SearchPreviewSection.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/23.
//

import SwiftUI
import Combine

/// 搜索结果预览面板
struct SearchPreviewSection: View {
    @ObservedObject var viewStore: LogDetailViewStore
    var onFilterAdded: (() -> Void)?

    // 本地状态：用于 TextField 绑定，避免直接操作 Store
    @State private var localSearchText: String = ""

    // Combine 防抖
    @State private var searchTextPublisher = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()

    // 使用 ViewStore 初始化
    init(viewStore: LogDetailViewStore, onFilterAdded: (() -> Void)? = nil) {
        self.viewStore = viewStore
        self.onFilterAdded = onFilterAdded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 搜索框
            searchBox

            // 搜索范围配置
            searchFieldsSelector

            // 搜索状态提示
            searchPhaseIndicator

            // 搜索结果预览（仅在有结果或搜索完成时显示）
            if !viewStore.searchText.isEmpty && shouldShowResults {
                searchResultsPreview
                    // 使用 searchText 和 totalCount 的组合作为 id，确保搜索时视图能正确刷新
                    .id("\(viewStore.searchText)-\(viewStore.searchResults.totalCount)")
            }
        }
        .onAppear {
            // 初始化本地搜索文本
            localSearchText = viewStore.searchText

            // 设置 Combine 防抖管道
            setupSearchDebounce()
        }
        .onChange(of: viewStore.searchText) { newValue in
            // 当 Store 中的文本变化时（例如清除按钮），同步到本地
            if localSearchText != newValue {
                localSearchText = newValue
            }
        }
    }

    // MARK: - 防抖设置

    private func setupSearchDebounce() {
        searchTextPublisher
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [viewStore] text in
                print("🎯 [SearchPreviewSection] 防抖完成，发送搜索文本: '\(text)'")
                viewStore.send(.search(.updateSearchText(text)))
            }
            .store(in: &cancellables)
    }

    // MARK: - 搜索框
    private var searchBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "keyword_search", bundle: .module))
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField(String(localized: "search_placeholder", bundle: .module), text: $localSearchText)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .onChange(of: localSearchText) { newValue in
                        print("📝 [SearchPreviewSection] TextField 变化: '\(newValue)'")
                        searchTextPublisher.send(newValue)
                    }
                if !localSearchText.isEmpty {
                    Button(action: {
                        localSearchText = ""
                        searchTextPublisher.send("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - 计算属性

    /// 是否应该显示搜索结果
    private var shouldShowResults: Bool {
        switch viewStore.state.searchFeature.searchPhase {
        case .idle, .typing, .cancelled, .failed:
            return false
        case .previewSearching, .previewCompleted, .fullSearching, .completed, .tooManyResults:
            return true
        }
    }

    // MARK: - 搜索状态指示器

    @ViewBuilder
    private var searchPhaseIndicator: some View {
        let phase = viewStore.state.searchFeature.searchPhase

        switch phase {
        case .idle:
            EmptyView()

        case .typing:
            HStack {
                ProgressView()
                    .scaleEffect(0.6)
                Text("正在输入...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)

        case .previewSearching(let sessionCount):
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("预览搜索中")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("正在搜索最近 \(sessionCount) 个 session")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)

        case .previewCompleted(let matchCount, let searchedSessions, let hasMoreSessions):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("预览完成")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()

                    // 搜索更多按钮
                    if hasMoreSessions {
                        Button {
                            viewStore.send(.search(.userRequestedFullSearch))
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("搜索更多")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    Label("\(matchCount) 条匹配", systemImage: "doc.text.magnifyingglass")
                    Label("最新 \(searchedSessions) 个 session", systemImage: "folder")
                }
                .font(.caption2)
                .foregroundColor(.gray)

                if hasMoreSessions {
                    Text("💡 点击「搜索更多」可搜索更早的日志")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)

        case .fullSearching(let currentIndex, let totalSessions, let matchCount, let scannedEvents):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("完整搜索中")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()

                    // 取消按钮
                    Button {
                        viewStore.send(.search(.cancelAllSearches))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("取消")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            // 进度
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(
                                    width: geometry.size.width * CGFloat(currentIndex) / CGFloat(max(totalSessions, 1)),
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)

                    // 状态信息
                    HStack(spacing: 12) {
                        Text("\(currentIndex)/\(totalSessions) sessions")
                            .font(.caption2)
                        Text("\(matchCount) 条匹配")
                            .font(.caption2)
                        Text("\(scannedEvents) 条已扫描")
                            .font(.caption2)
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)

        case .completed(let totalMatches, let searchedSessions):
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("搜索完成")
                        .font(.caption)
                        .fontWeight(.medium)
                    HStack(spacing: 12) {
                        Label("\(totalMatches) 条匹配", systemImage: "doc.text.magnifyingglass")
                        Label("\(searchedSessions) 个 session", systemImage: "folder")
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)

        case .cancelled:
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.orange)
                Text("搜索已取消")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .padding(.vertical, 8)

        case .failed(let message):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("搜索失败")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)

        case .tooManyResults(let currentCount, let limit):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("结果过多")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }

                Text("已找到 \(currentCount) 条结果（限制：\(limit) 条）")
                    .font(.caption2)
                    .foregroundColor(.gray)

                Text("💡 建议：使用更具体的关键词来缩小搜索范围")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 搜索范围选择器
    private var searchFieldsSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "search_scope", bundle: .module))
                .font(.caption)
                .foregroundColor(.gray)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SearchField.allCases) { field in
                        Button(action: { viewStore.toggleSearchField(field) }) {
                            HStack(spacing: 4) {
                                Image(systemName: field.icon)
                                Text(field.localizedName)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                viewStore.state.searchFeature.searchFields.contains(field)
                                    ? Color.blue.opacity(0.2)
                                    : Color.gray.opacity(0.1)
                            )
                            .foregroundColor(
                                viewStore.state.searchFeature.searchFields.contains(field)
                                    ? .blue
                                    : .primary
                            )
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        viewStore.state.searchFeature.searchFields.contains(field)
                                            ? Color.blue
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 搜索结果预览
    private var searchResultsPreview: some View {
        let results = viewStore.searchResults
        let _ = print("🖼️ UI渲染搜索预览: isEmpty=\(results.isEmpty), totalCount=\(results.totalCount), searchText='\(viewStore.searchText)'")

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "match_preview", bundle: .module))
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                if !results.isEmpty {
                    Text(String(format: String(localized: "items_count", bundle: .module), results.totalCount))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            if results.isEmpty {
                Text(String(localized: "no_match", bundle: .module))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // 消息匹配 - 特殊处理，添加搜索词作为关键词
                    if !results.message.isEmpty {
                        messageResultCategory(
                            items: results.message
                        )
                    }

                    // 文件匹配
                    if !results.fileName.isEmpty {
                        resultCategory(
                            title: String(localized: "search_field_file", bundle: .module),
                            icon: "doc",
                            items: results.fileName
                        )
                    }

                    // 函数匹配
                    if !results.function.isEmpty {
                        resultCategory(
                            title: String(localized: "search_field_function", bundle: .module),
                            icon: "function",
                            items: results.function
                        )
                    }

                    // 模块匹配
                    if !results.context.isEmpty {
                        resultCategory(
                            title: String(localized: "search_field_context", bundle: .module),
                            icon: "square.stack.3d.up",
                            items: results.context
                        )
                    }

                    // 线程匹配
                    if !results.thread.isEmpty {
                        resultCategory(
                            title: String(localized: "search_field_thread", bundle: .module),
                            icon: "arrow.triangle.branch",
                            items: results.thread
                        )
                    }
                }
                .padding(10)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - 消息结果分类视图（特殊处理：添加搜索词作为关键词）
    private func messageResultCategory(
        items: [SearchResultItem]
    ) -> some View {
        let keyword = viewStore.searchText
        let isKeywordSelected = viewStore.state.filterFeature.selectedMessageKeywords.contains(keyword)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "text.bubble")
                    .font(.caption2)
                Text("\(String(localized: "search_field_message", bundle: .module)) (\(items.count))")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                // 添加/移除搜索词按钮
                Button(action: {
                    if isKeywordSelected {
                        viewStore.send(.filter(.updateFilter(.messageKeyword, .remove(keyword))))
                    } else {
                        viewStore.send(.filter(.updateFilter(.messageKeyword, .add(keyword))))
                        onFilterAdded?()
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: isKeywordSelected ? "minus.circle" : "plus.circle")
                        Text(isKeywordSelected ? String(localized: "remove_keyword", bundle: .module) : String(localized: "add_keyword", bundle: .module))
                    }
                    .font(.caption2)
                    .foregroundColor(isKeywordSelected ? .red : .blue)
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.gray)

            ForEach(items) { item in
                Text(highlightedText(item.value))
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 结果分类视图
    private func resultCategory(
        title: String,
        icon: String,
        items: [SearchResultItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption2)
                Text("\(title) (\(items.count))")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.gray)

            ForEach(items) { item in
                HStack {
                    Text(highlightedText(item.value))
                        .font(.caption)
                        .lineLimit(1)

                    Spacer()

                    let isSelected = viewStore.isInFilter(item)
                    Button(action: {
                        viewStore.toggleFilter(item)
                        if !isSelected {
                            onFilterAdded?()
                        }
                    }) {
                        Image(systemName: isSelected ? "minus.circle" : "plus.circle")
                            .font(.caption)
                            .foregroundColor(isSelected ? .red : .blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 高亮文本
    private func highlightedText(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)

        if let range = text.lowercased().range(of: viewStore.searchText.lowercased()) {
            let startIndex = text.distance(from: text.startIndex, to: range.lowerBound)
            let length = viewStore.searchText.count

            if let attrRange = Range(NSRange(location: startIndex, length: length), in: attributedString) {
                attributedString[attrRange].backgroundColor = .yellow.opacity(0.3)
                attributedString[attrRange].foregroundColor = .primary
            }
        }

        return attributedString
    }
}
