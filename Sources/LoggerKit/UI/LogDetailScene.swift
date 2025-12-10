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
            if sceneState.isLoading {
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
                    Text(String(format: totalCountFormat, sceneState.filteredEvents.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
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

                // 2️⃣ 日志列表
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(sceneState.filteredEvents, id: \.id) { logEvent in
                            LogRowView(event: logEvent)
                        }
                    }
                    .padding(.horizontal)
                }
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
            let shareSheet = ShareSheet(activityItems: [activityItem]) {
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
            isSharePresented = true
        } label: {
            Label(shareLogText, systemImage: "square.and.arrow.up")
        }
    }

    private var activityItem: URL {
        LogParser.logEventToTempFile(fileName: sceneState.exportFileName, events: sceneState.filteredEvents)
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

struct LogRowView: View {
    let event: LogEvent

    // 缓存计算的颜色,避免每次重绘都计算
    private let cachedSessionColor: Color

    public init(event: LogEvent) {
        self.event = event
        self.cachedSessionColor = Self.sessionColor(for: event.sessionId)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.sessionId)
                .foregroundColor(cachedSessionColor)
                .font(.system(size: 9))
            + Text(" ")
                .font(.system(size: 9))
            + Text(event.prefix)
                .foregroundColor(.gray)
                .font(.system(size: 9))

            Text(event.message)
                .foregroundColor(event.level.color)
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
    
    private func copyLog() {
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        // 复制完整日志内容：前缀 + message
        pasteboard.string = "\(event.prefix) - \(event.message)"
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(event.prefix) - \(event.message)", forType: .string)
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
