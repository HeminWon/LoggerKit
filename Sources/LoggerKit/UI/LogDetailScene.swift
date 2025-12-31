//
//  LogDetailScene.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/9/10.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct LogDetailScene: View {
    @ObservedObject var viewStore: LogDetailViewStore

    /// 使用 ViewStore 初始化
    public init(viewStore: LogDetailViewStore) {
        self.viewStore = viewStore
    }

    // MARK: - Localized Strings
    private var loadingText: String {
        String(localized: "loading_logs", bundle: .module)
    }

    private var errorPrefix: String {
        String(localized: "error_prefix", bundle: .module)
    }

    private var totalCountFormat: String {
        String(localized: "total_count", bundle: .module)
    }

    private var filterCountFormat: String {
        String(localized: "filter_count", bundle: .module)
    }

    private var filterButtonText: String {
        String(localized: "filter_button", bundle: .module)
    }

    private var shareLogText: String {
        String(localized: "share_log", bundle: .module)
    }

    /// 是否没有日志（根据 totalCount 和 loadingState 判断）
    private var hasNoLogs: Bool {
        // 加载中不禁用，避免闪烁
        if viewStore.isLoading {
            return false
        }
        // 总数为 0 且不在加载状态时才禁用
        return viewStore.totalCount == 0 && viewStore.loadingState == .loaded
    }

    public var body: some View {
        VStack {
            if viewStore.isLoading {
                Spacer()
                ProgressView(loadingText)
                Spacer()
            } else if let error = viewStore.error {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(String(format: errorPrefix, error.localizedDescription))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                Spacer()
            } else {
                // 导出进度显示
                logInfoBar
                    .padding(.horizontal)
                    
                Divider()

                // 2️⃣ 日志列表 - 使用 List 实现真正的虚拟化
                List {
                    ForEach(viewStore.displayEvents) { viewModel in
                        if #available(iOS 15.0, macOS 13.0, *) {
                            LogRowView(viewModel: viewModel)
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .listRowSeparator(.hidden)
                                .onAppear {
                                    // 滚动到底部时加载更多
                                    if viewModel.id == viewStore.displayEvents.last?.id {
                                        viewStore.loadMore()
                                    }
                                }
                        } else {
                            LogRowView(viewModel: viewModel)
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .onAppear {
                                    // 滚动到底部时加载更多
                                    if viewModel.id == viewStore.displayEvents.last?.id {
                                        viewStore.loadMore()
                                    }
                                }
                        }
                    }

                    // 分页加载指示器
                    if viewStore.loadingState == .loadingMore {
                        if #available(iOS 15.0, macOS 13.0, *) {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        } else {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                            .listRowInsets(EdgeInsets())
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .task {
            await viewStore.loadLogFileAsync()
        }
        .sheet(isPresented: viewStore.filterPresentedBinding) {
            if #available(iOS 16.0, macOS 13.0, *) {
                LogFilterSheet(viewStore: viewStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                LogFilterSheet(viewStore: viewStore)
            }
        }
        .sheet(isPresented: viewStore.deleteManagementPresentedBinding) {
            if #available(iOS 16.0, macOS 13.0, *) {
                LogDeleteManagementSheet(viewStore: viewStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                LogDeleteManagementSheet(viewStore: viewStore)
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: viewStore.sharePresentedBinding) {
            if let url = viewStore.exportedFileURL {
                let shareSheet = ShareSheet(activityItems: [url]) {
                    viewStore.send(.setSharePresented(false))
                }
                if #available(iOS 16.0, *) {
                    shareSheet
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                } else  {
                    shareSheet
                }
            }
        }
        #endif
        .navigationTitle(viewStore.displayTitle)
        #if os(iOS) || os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // 筛选按钮（高频操作，独立显示）
                Button {
                    viewStore.send(.setFilterPresented(true))
                } label: {
                    if viewStore.activeFilterCount > 0 {
                        Label(filterButtonText, systemImage: "line.3.horizontal.decrease.circle.fill")
                    } else {
                        Label(filterButtonText, systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                .disabled(hasNoLogs)

                // 更多菜单（中低频操作）
                Menu {
                    // 导出日志
                    Button {
                        viewStore.startExport(format: .log)
                    } label: {
                        Label(String(localized: "export_logs", bundle: .module), systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    // 删除管理（危险操作）
                    Button(role: .destructive) {
                        viewStore.send(.setDeleteManagementPresented(true))
                    } label: {
                        Label(String(localized: "delete_management", bundle: .module), systemImage: "trash.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(hasNoLogs)
            }
        }
        #else
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                shareButton
            }
        }
        #endif
    }
    
    // MARK: - Log Info Bar
    /// 显示日志统计信息和导出进度
    @ViewBuilder
    private var logInfoBar: some View {
        Group {
            if viewStore.isExporting {
                HStack(alignment: .center, spacing: 4) {
                    // 圆环进度
                    if viewStore.totalExportCount > 0 {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                                .frame(width: 16, height: 16)
                            Circle()
                                .trim(from: 0, to: viewStore.exportProgress)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 16, height: 16)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.1), value: viewStore.exportProgress)
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    }
                    
                    // 进度文字
                    Text(String(localized: "exporting_progress", bundle: .module))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if viewStore.totalExportCount > 0 {
                        Text("\(viewStore.exportedCount)/\(viewStore.totalExportCount)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // 1️⃣ 筛选结果统计
                HStack(alignment: .center) {
                    if viewStore.totalCount > 0 {
                        Text(String(format: String(localized: "loaded_total_count", bundle: .module), viewStore.displayEvents.count, viewStore.totalCount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: totalCountFormat, viewStore.displayEvents.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if viewStore.activeFilterCount > 0 {
                        Text(String(format: filterCountFormat, viewStore.activeFilterCount))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 16) // 固定高度，避免状态切换时闪动
    }
    
    // MARK: - Subviews
    private var shareButton: some View {
        Button {
            viewStore.startExport(format: .log)
        } label: {
            // 使用固定尺寸的 ZStack 确保布局不会因图标切换而变化
            ZStack {
                if viewStore.isExporting {
                    // 圆环进度条
                    if viewStore.totalExportCount > 0 {
                        ZStack {
                            // 背景圆环
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 2.5)
                                .frame(width: 24, height: 24)

                            // 进度圆环
                            Circle()
                                .trim(from: 0, to: viewStore.exportProgress)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.1), value: viewStore.exportProgress)

                            // 百分比文字
                            Text("\(Int(viewStore.exportProgress * 100))")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    } else {
                        // 初始化阶段，显示不定进度的圆环
                        ProgressView()
                            .frame(width: 24, height: 24)
                    }
                } else {
                    // 分享图标
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17))
                }
            }
            .frame(width: 32, height: 32) // 固定尺寸，避免布局变化
        }
        .disabled(viewStore.isExporting || hasNoLogs)
        .alert(String(localized: "export_failed", bundle: .module), isPresented: viewStore.exportErrorPresentedBinding) {
            Button(String(localized: "confirm_button", bundle: .module), role: .cancel) { }
        } message: {
            if let error = viewStore.error {
                Text(error.localizedDescription)
            }
        }
    }

    private func copyToClipboard(text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

}

// MARK: - LogRowViewModel
/// LogRowView 的专用数据模型，封装了显示所需的 event、index 和预计算的颜色
public struct LogRowViewModel: Identifiable {
    public let id: UUID              // 使用 event.id 作为唯一标识
    public let event: LogEvent       // 原始日志数据
    public let index: Int            // 显示序号
    public let cachedColor: Color    // 预计算的 session 颜色

    public init(event: LogEvent, index: Int) {
        self.id = event.id
        self.event = event
        self.index = index
        self.cachedColor = Self.sessionColor(for: event.sessionId)
    }

    // 根据 sessionId 生成一致的柔和随机颜色
    private static func sessionColor(for sessionId: String) -> Color {
        // 使用稳定的 hash 算法，确保同一 sessionId 总是生成相同的颜色
        let hash = sessionId.utf8.reduce(0) {
            ($0 &* 31 &+ Int($1)) & 0xFFFFFFFF
        }

        // 从 hash 生成 HSB 颜色参数
        // Hue(色相): 0-360 度，使用 hash 确保每个会话有不同的颜色
        let hue = Double(abs(hash) % 360) / 360.0

        // Saturation(饱和度): 40%-60%,中等饱和度让前景色更鲜明
        let saturation = 0.40 + Double((abs(hash) >> 8) % 21) / 100.0

        // Brightness(亮度): 50%-70%,中等亮度确保与背景有足够对比度
        let brightness = 0.50 + Double((abs(hash) >> 16) % 21) / 100.0

        // 返回柔和的颜色，前景色使用完全不透明
        return Color(hue: hue, saturation: saturation, brightness: brightness, opacity: 1.0)
    }
}

struct LogRowView: View {
    let viewModel: LogRowViewModel

    public init(viewModel: LogRowViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.event.sessionId)
                .foregroundColor(viewModel.cachedColor)
                .font(.system(size: 9))
            + Text(" #\(viewModel.index)")
                .foregroundColor(.secondary)
                .font(.system(size: 9))
            + Text(" ")
                .font(.system(size: 9))
            + Text(viewModel.event.prefix)
                .foregroundColor(.gray)
                .font(.system(size: 9))

            Text(viewModel.event.message)
                .foregroundColor(viewModel.event.level.color)
                .font(.caption2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 1)
        // 长按弹出复制菜单
        .contextMenu {
            Button(action: { copyLog() }) {
                Label(String(localized: "copy_log", bundle: .module), systemImage: "doc.on.doc")
            }
        }
    }

    private func copyLog() {
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        // 复制完整日志内容：前缀 + message
        pasteboard.string = "\(viewModel.event.prefix) - \(viewModel.event.message)"
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(viewModel.event.prefix) - \(viewModel.event.message)", forType: .string)
        #endif
    }
}

#Preview {
}
