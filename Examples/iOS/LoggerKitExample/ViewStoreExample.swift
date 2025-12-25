//
//  ViewStoreExample.swift
//  LoggerKitExample
//
//  ViewStore 使用示例
//  演示如何使用新的 ViewStore API
//

import SwiftUI
import LoggerKit

// MARK: - 示例 1: 最简单的用法

struct SimpleViewStoreExample: View {
    // ✅ 使用 LoggerKit Facade 创建 ViewStore
    @StateObject private var viewStore = LoggerKit.makeViewStore()

    var body: some View {
        NavigationView {
            VStack {
                // ✅ 使用预定义 binding
                SearchBar(text: viewStore.searchTextBinding)

                // ✅ 直接访问计算属性
                if viewStore.isLoading {
                    ProgressView("Loading logs...")
                } else {
                    LogList(events: viewStore.displayEvents)
                }
            }
            .navigationTitle("Logs (\(viewStore.totalCount))")
        }
        .task {
            // ✅ 异步加载
            await viewStore.loadLogFileAsync()
        }
    }
}

// MARK: - 示例 2: 完整功能演示

struct FullViewStoreExample: View {
    @StateObject private var viewStore = LoggerKit.makeViewStore(
        configuration: .init(
            sessionIds: ["current-session"],
            enableActionLogging: true  // 开启调试日志
        )
    )

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索和过滤工具栏
                ToolbarSection(viewStore: viewStore)

                // 日志列表
                LogListSection(viewStore: viewStore)

                // 底部状态栏
                StatusBar(viewStore: viewStore)
            }
            .navigationTitle("Logger")
            .toolbar {
                ToolbarContent(viewStore: viewStore)
            }
        }
        .task {
            await viewStore.loadLogFileAsync()
        }
        // Sheets
        .sheet(isPresented: viewStore.filterPresentedBinding) {
            FilterSheet(viewStore: viewStore)
        }
        .sheet(isPresented: viewStore.sharePresentedBinding) {
            if let url = viewStore.exportedFileURL {
                ShareSheet(url: url)
            }
        }
    }
}

// MARK: - 子视图

struct ToolbarSection: View {
    @ObservedObject var viewStore: LogDetailViewStore

    var body: some View {
        HStack(spacing: 12) {
            // ✅ 使用预定义 binding
            TextField("Search...", text: viewStore.searchTextBinding)
                .textFieldStyle(.roundedBorder)

            // ✅ 使用便捷方法
            Button("Search") {
                viewStore.executeSearch()
            }
            .buttonStyle(.bordered)

            // ✅ 条件显示
            if viewStore.isSearchActive {
                Button("Clear") {
                    viewStore.clearSearch()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

struct LogListSection: View {
    @ObservedObject var viewStore: LogDetailViewStore

    var body: some View {
        Group {
            if viewStore.isLoading {
                ProgressView("Loading logs...")
            } else if viewStore.displayEvents.isEmpty {
                EmptyView()
            } else {
                List {
                    ForEach(viewStore.displayEvents) { event in
                        LogRowView(viewModel: event)
                    }

                    // 加载更多
                    if viewStore.state.hasMoreData {
                        Button("Load More") {
                            // ✅ 同步调用，不需要 Task
                            viewStore.loadMore()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct StatusBar: View {
    @ObservedObject var viewStore: LogDetailViewStore

    var body: some View {
        HStack {
            // ✅ 使用计算属性
            Text("\(viewStore.totalCount) events")
                .font(.caption)
                .foregroundColor(.secondary)

            if viewStore.activeFilterCount > 0 {
                Text("• \(viewStore.activeFilterCount) filters")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Spacer()

            // ✅ 导出进度
            if viewStore.isExporting {
                HStack(spacing: 8) {
                    ProgressView(value: viewStore.exportProgress)
                        .frame(width: 80)
                    Text("\(Int(viewStore.exportProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

struct ToolbarContent: ToolbarContent {
    @ObservedObject var viewStore: LogDetailViewStore

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button("Export as Log") {
                    viewStore.startExport(format: .log)
                }
                Button("Export as JSON") {
                    viewStore.startExport(format: .json)
                }
                Button("Export as TXT") {
                    viewStore.startExport(format: .txt)
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }

        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                // ✅ 同步 send
                viewStore.send(.setFilterPresented(true))
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    // ✅ 显示活动过滤器数量
                    if viewStore.activeFilterCount > 0 {
                        Text("\(viewStore.activeFilterCount)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

struct FilterSheet: View {
    @ObservedObject var viewStore: LogDetailViewStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Log Levels") {
                    ForEach(LogEvent.Level.allCases, id: \.self) { level in
                        Toggle(level.description, isOn: Binding(
                            get: {
                                viewStore.state.selectedLevels.contains(level)
                            },
                            set: { _ in
                                // ✅ 使用便捷方法
                                viewStore.toggleLevel(level)
                            }
                        ))
                    }
                }

                Section {
                    Button("Reset All Filters") {
                        viewStore.resetFilter()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 辅助视图

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search...", text: $text)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct LogList: View {
    let events: [LogRowViewModel]

    var body: some View {
        List(events) { event in
            LogRowView(viewModel: event)
        }
        .listStyle(.plain)
    }
}

struct LogRowView: View {
    let viewModel: LogRowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // 日志级别
                Text(viewModel.level.description)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(levelColor(viewModel.level))

                Spacer()

                // 时间戳
                Text(viewModel.timestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // 消息
            Text(viewModel.message)
                .font(.body)
                .lineLimit(3)

            // 元数据
            if let function = viewModel.function {
                Text(function)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func levelColor(_ level: LogEvent.Level) -> Color {
        switch level {
        case .verbose: return .gray
        case .debug: return .blue
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct ShareSheet: View {
    let url: URL

    var body: some View {
        // 简化的分享视图
        VStack {
            Text("Share Log File")
                .font(.headline)
            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 示例 3: 对比旧 API

struct ComparisonExample: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("API 对比")
                .font(.title)

            // ❌ 旧 API (SceneState)
            OldAPIExample()

            Divider()

            // ✅ 新 API (ViewStore)
            NewAPIExample()
        }
    }
}

struct OldAPIExample: View {
    @StateObject private var sceneState = LogDetailSceneState()

    var body: some View {
        VStack {
            Text("旧 API (SceneState)")
                .font(.headline)

            // ❌ 复杂的 binding
            TextField("Search", text: $sceneState.searchState.searchText)

            // ❌ 需要 Task
            Button("Load") {
                Task {
                    await sceneState.loadLogFile()
                }
            }
        }
    }
}

struct NewAPIExample: View {
    @StateObject private var viewStore = LoggerKit.makeViewStore()

    var body: some View {
        VStack {
            Text("新 API (ViewStore)")
                .font(.headline)

            // ✅ 简洁的预定义 binding
            TextField("Search", text: viewStore.searchTextBinding)

            // ✅ 同步调用
            Button("Load") {
                viewStore.loadLogFile()
            }
        }
    }
}

// MARK: - Preview

#Preview("Simple") {
    SimpleViewStoreExample()
}

#Preview("Full") {
    FullViewStoreExample()
}

#Preview("Comparison") {
    ComparisonExample()
}
