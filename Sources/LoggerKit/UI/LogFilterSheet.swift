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

#Preview {
    LogFilterSheet(sceneState: LogDetailSceneState(
        logFileURL: URL(fileURLWithPath: "/tmp/test.log"),
        prefix: "test",
        identifier: "123"
    ))
}
