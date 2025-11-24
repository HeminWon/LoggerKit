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

    public init(sceneState: LogDetailSceneState) {
        self.sceneState = sceneState
    }

    public var body: some View {
        VStack {
            if sceneState.isLoading {
                Spacer()
                ProgressView(String(localized: "loading_logs", bundle: .module))
                Spacer()
            } else if let error = sceneState.error {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(String(format: String(localized: "error_prefix", bundle: .module), error.localizedDescription))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                Spacer()
            } else {
                // 1️⃣ 筛选结果统计
                HStack {
                    Text(String(format: String(localized: "total_count", bundle: .module), sceneState.filteredEvents.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if sceneState.activeFilterCount > 0 {
                        Text(String(format: String(localized: "filter_count", bundle: .module), sceneState.activeFilterCount))
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
                    VStack(alignment: .leading, spacing: 4) {
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
        .navigationTitle(sceneState.logFileURL.lastPathComponent)
        #if os(iOS) || os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // 筛选按钮
                Button {
                    isFilterPresented = true
                } label: {
                    if sceneState.activeFilterCount > 0 {
                        Label(String(localized: "filter_button", bundle: .module), systemImage: "line.3.horizontal.decrease.circle.fill")
                    } else {
                        Label(String(localized: "filter_button", bundle: .module), systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

                // 分享按钮
                Button {
                    isSharePresented = true
                } label: {
                    Label(String(localized: "share_log", bundle: .module), systemImage: "square.and.arrow.up")
                }
            }
        }
        #else
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    isSharePresented = true
                } label: {
                    Label(String(localized: "share_log", bundle: .module), systemImage: "square.and.arrow.up")
                }
            }
        }
        #endif
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

    public init(event: LogEvent) {
        self.event = event
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.prefix)
                .foregroundColor(.gray)   // 前缀灰色
                .font(.system(size: 9))
                .frame(maxWidth: .infinity, alignment: .leading)
 
            Text(event.message)
                .foregroundColor(event.level.color)
                .font(.caption2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
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
        pasteboard.string = "\(event.prefix) - \(event.message)"
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(event.prefix) - \(event.message)", forType: .string)
        #endif
    }
}

#Preview {
}

