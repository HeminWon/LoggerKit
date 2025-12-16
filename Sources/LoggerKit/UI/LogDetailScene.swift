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
    @ObservedObject var sceneState: LogDetailSceneState

    @State var isSharePresented: Bool = false
    @State var isFilterPresented: Bool = false
    @State var exportURL: URL?
    @State var isExporting: Bool = false
    @State var exportProgress: Double = 0.0
    @State var exportedCount: Int = 0
    @State var totalExportCount: Int = 0
    @State var exportError: Error?
    @State var showExportError: Bool = false

    public init(sceneState: LogDetailSceneState? = nil) {
        self.sceneState = sceneState ?? LogDetailSceneState()
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

    public var body: some View {
        VStack {
            if case .loading = sceneState.loadingState {
                Spacer()
                ProgressView(loadingText)
                Spacer()
            } else if let error = sceneState.error {
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
                // 1️⃣ 筛选结果统计
                HStack {
                    if sceneState.totalCount > 0 {
                        Text("已加载 \(sceneState.displayEvents.count) / 总计 \(sceneState.totalCount) 条")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: totalCountFormat, sceneState.displayEvents.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if sceneState.activeFilterCount > 0 {
                        Text(String(format: filterCountFormat, sceneState.activeFilterCount))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // 2️⃣ 日志列表 - 使用List实现真正的虚拟化
                List {
                    ForEach(sceneState.displayEvents) { viewModel in
                        if #available(iOS 15.0, macOS 13.0, *) {
                            LogRowView(viewModel: viewModel)
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .listRowSeparator(.hidden)
                                .onAppear {
                                    // 滚动到底部时加载更多
                                    if viewModel.id == sceneState.displayEvents.last?.id {
                                        Task {
                                            await sceneState.loadMore()
                                        }
                                    }
                                }
                        } else {
                            LogRowView(viewModel: viewModel)
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .onAppear {
                                    // 滚动到底部时加载更多
                                    if viewModel.id == sceneState.displayEvents.last?.id {
                                        Task {
                                            await sceneState.loadMore()
                                        }
                                    }
                                }
                        }
                    }

                    // 分页加载指示器
                    if sceneState.loadingState == .loadingMore {
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
            await sceneState.loadLogFile()
        }
        .sheet(isPresented: $isFilterPresented) {
            if #available(iOS 16.0, macOS 13.0, *) {
                LogFilterSheet(sceneState: sceneState)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                LogFilterSheet(sceneState: sceneState)
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $isSharePresented) {
            if let url = exportURL {
                let shareSheet = ShareSheet(activityItems: [url]) {
                    isSharePresented = false
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
        .navigationTitle(sceneState.displayTitle)
        #if os(iOS) || os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // 筛选按钮
                Button {
                    isFilterPresented = true
                } label: {
                    if sceneState.activeFilterCount > 0 {
                        Label(filterButtonText, systemImage: "line.3.horizontal.decrease.circle.fill")
                    } else {
                        Label(filterButtonText, systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

                // 分享按钮
                shareButton
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
    
    // MARK: - Subviews
    private var shareButton: some View {
        Button {
            Task {
                isExporting = true
                exportProgress = 0.0
                exportedCount = 0
                totalExportCount = 0

                do {
                    // 使用流式导出
                    exportURL = try await sceneState.exportAllEventsStreaming(
                        fileName: sceneState.exportFileName,
                        progressHandler: { written, total in
                            exportedCount = written
                            totalExportCount = total
                            exportProgress = total > 0 ? Double(written) / Double(total) : 0.0
                        }
                    )
                    isExporting = false
                    isSharePresented = true
                } catch {
                    exportError = error
                    showExportError = true
                    isExporting = false
                    print("❌ 导出失败: \(error)")
                }
            }
        } label: {
            // 使用固定尺寸的 ZStack 确保布局不会因图标切换而变化
            ZStack {
                if isExporting {
                    // 圆环进度条
                    if totalExportCount > 0 {
                        ZStack {
                            // 背景圆环
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 2.5)
                                .frame(width: 24, height: 24)

                            // 进度圆环
                            Circle()
                                .trim(from: 0, to: exportProgress)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.1), value: exportProgress)

                            // 百分比文字
                            Text("\(Int(exportProgress * 100))")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    } else {
                        // 初始化阶段,显示不定进度的圆环
                        ProgressView()
                            .frame(width: 24, height: 24)
                    }
                } else {
                    // 分享图标
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17))
                }
            }
            .frame(width: 32, height: 32) // 固定尺寸,避免布局变化
        }
        .disabled(isExporting)
        .alert("导出失败", isPresented: $showExportError) {
            Button("确定", role: .cancel) { }
        } message: {
            if let error = exportError {
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
/// LogRowView 的专用数据模型,封装了显示所需的 event、index 和预计算的颜色
struct LogRowViewModel: Identifiable {
    let id: UUID              // 使用 event.id 作为唯一标识
    let event: LogEvent       // 原始日志数据
    let index: Int            // 显示序号
    let cachedColor: Color    // 预计算的 session 颜色

    init(event: LogEvent, index: Int) {
        self.id = event.id
        self.event = event
        self.index = index
        self.cachedColor = Self.sessionColor(for: event.sessionId)
    }

    // 根据 sessionId 生成一致的柔和随机颜色
    private static func sessionColor(for sessionId: String) -> Color {
        // 使用稳定的 hash 算法,确保同一 sessionId 总是生成相同的颜色
        let hash = sessionId.utf8.reduce(0) {
            ($0 &* 31 &+ Int($1)) & 0xFFFFFFFF
        }

        // 从 hash 生成 HSB 颜色参数
        // Hue(色相): 0-360度,使用 hash 确保每个会话有不同的颜色
        let hue = Double(abs(hash) % 360) / 360.0

        // Saturation(饱和度): 40%-60%,中等饱和度让前景色更鲜明
        let saturation = 0.40 + Double((abs(hash) >> 8) % 21) / 100.0

        // Brightness(亮度): 50%-70%,中等亮度确保与背景有足够对比度
        let brightness = 0.50 + Double((abs(hash) >> 16) % 21) / 100.0

        // 返回柔和的颜色,前景色使用完全不透明
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

#if canImport(UIKit)
extension LogDetailScene {
    /// 创建一个包含 LogDetailScene 的 UIViewController,方便在 UIKit 项目中使用
    /// - Parameter sceneState: 可选的场景状态,不传则使用默认状态（加载所有日志）
    /// - Returns: 包含 LogDetailScene 的 UIViewController,外部可以自行决定如何展示 (present/push)
    public static func makeViewController(sceneState: LogDetailSceneState? = nil) -> UIViewController {
        let state = sceneState ?? LogDetailSceneState()
        let scene = LogDetailScene(sceneState: state)
        let hostingController = UIHostingController(rootView: scene)
        hostingController.title = "Logs"
        return hostingController
    }
}
#endif
