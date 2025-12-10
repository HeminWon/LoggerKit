//
//  SearchPreviewSection.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/23.
//

import SwiftUI

/// 搜索结果预览面板
struct SearchPreviewSection: View {
    @ObservedObject var sceneState: LogDetailSceneState
    var onFilterAdded: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 搜索框
            searchBox

            // 搜索范围配置
            searchFieldsSelector

            // 搜索结果预览
            if !sceneState.searchText.isEmpty {
                searchResultsPreview
            }
        }
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
                TextField(String(localized: "search_placeholder", bundle: .module), text: $sceneState.searchText)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                if !sceneState.searchText.isEmpty {
                    Button(action: { sceneState.searchText = "" }) {
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

    // MARK: - 搜索范围选择器
    private var searchFieldsSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "search_scope", bundle: .module))
                .font(.caption)
                .foregroundColor(.gray)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SearchField.allCases) { field in
                        Button(action: { sceneState.toggleSearchField(field) }) {
                            HStack(spacing: 4) {
                                Image(systemName: field.icon)
                                Text(field.localizedName)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                sceneState.searchFields.contains(field)
                                    ? Color.blue.opacity(0.2)
                                    : Color.gray.opacity(0.1)
                            )
                            .foregroundColor(
                                sceneState.searchFields.contains(field)
                                    ? .blue
                                    : .primary
                            )
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        sceneState.searchFields.contains(field)
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
        let results = sceneState.searchResults

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
        let keyword = sceneState.searchText
        let isKeywordSelected = sceneState.selectedMessageKeywords.contains(keyword)

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
                        sceneState.selectedMessageKeywords.remove(keyword)
                    } else {
                        sceneState.selectedMessageKeywords.insert(keyword)
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

                    let isSelected = sceneState.isInFilter(item)
                    Button(action: {
                        if !isSelected {
                            sceneState.addToFilter(item)
                            onFilterAdded?()
                        } else {
                            sceneState.removeFromFilter(item)
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

        if let range = text.lowercased().range(of: sceneState.searchText.lowercased()) {
            let startIndex = text.distance(from: text.startIndex, to: range.lowerBound)
            let length = sceneState.searchText.count

            if let attrRange = Range(NSRange(location: startIndex, length: length), in: attributedString) {
                attributedString[attrRange].backgroundColor = .yellow.opacity(0.3)
                attributedString[attrRange].foregroundColor = .primary
            }
        }

        return attributedString
    }
}
