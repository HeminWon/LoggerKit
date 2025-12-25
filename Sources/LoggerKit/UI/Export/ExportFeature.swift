//
//  ExportFeature.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - ExportFeature

public struct ExportFeature {
    // 私有初始化器,防止外部实例化
    private init() {}
}

// MARK: - State

extension ExportFeature {
    /// Export State
    public struct State: Equatable, Sendable {
        // MARK: - Export Configuration

        /// Selected export format
        public var format: ExportFormat = .log

        /// Session IDs to export (empty = all sessions)
        public var sessionIds: Set<String> = []

        /// Filter options (optional, for exporting filtered results)
        public var filterOptions: ExportFilterOptions?

        /// Bundle ID（用于文件名，可选）
        public var bundleId: String?

        /// 导出标识符（用于文件名，可选）
        public var exportIdentifier: String?

        // MARK: - Progress State

        /// Whether export is currently in progress
        public var isExporting: Bool = false

        /// Export progress (0.0 to 1.0)
        public var progress: Double = 0.0

        /// Number of events exported so far
        public var exportedCount: Int = 0

        /// Total number of events to export
        public var totalCount: Int = 0

        // MARK: - Result State

        /// URL of the exported file (set when export completes successfully)
        public var exportedFileURL: URL?

        /// Export error (if any)
        public var error: Error?

        // MARK: - UI Presentation State

        /// 分享面板是否显示
        public var isShareSheetPresented: Bool = false

        /// 错误提示是否显示
        public var isErrorAlertPresented: Bool = false

        // MARK: - Progress Throttling State (内部使用)

        /// 上次进度更新时间戳（用于节流）
        internal var lastProgressUpdateTime: TimeInterval = 0

        // MARK: - Computed Properties

        /// Whether export is in idle state (not started, completed, or failed)
        public var isIdle: Bool {
            !isExporting && exportedFileURL == nil && error == nil
        }

        /// Whether export completed successfully
        public var isCompleted: Bool {
            !isExporting && exportedFileURL != nil
        }

        /// Whether export failed
        public var isFailed: Bool {
            !isExporting && error != nil
        }

        /// 是否应该自动显示分享面板
        public var shouldAutoShowShareSheet: Bool {
            isCompleted && exportedFileURL != nil && !isShareSheetPresented
        }

        // MARK: - Initializer

        public init() {}

        // MARK: - State Mutations

        /// Reset to initial state (增强版 - 包含 UI 状态重置)
        public mutating func reset() {
            isExporting = false
            progress = 0.0
            exportedCount = 0
            totalCount = 0
            exportedFileURL = nil
            error = nil
            // 重置 UI 状态
            isShareSheetPresented = false
            isErrorAlertPresented = false
            lastProgressUpdateTime = 0
        }

        /// Update progress
        public mutating func updateProgress(exported: Int, total: Int) {
            exportedCount = exported
            totalCount = total
            progress = total > 0 ? Double(exported) / Double(total) : 0.0
        }

        // MARK: - Equatable

        public static func == (lhs: State, rhs: State) -> Bool {
            lhs.format == rhs.format &&
            lhs.sessionIds == rhs.sessionIds &&
            lhs.filterOptions == rhs.filterOptions &&
            lhs.isExporting == rhs.isExporting &&
            lhs.progress == rhs.progress &&
            lhs.exportedCount == rhs.exportedCount &&
            lhs.totalCount == rhs.totalCount &&
            lhs.exportedFileURL == rhs.exportedFileURL &&
            lhs.error?.localizedDescription == rhs.error?.localizedDescription &&
            // 新增字段比较
            lhs.isShareSheetPresented == rhs.isShareSheetPresented &&
            lhs.isErrorAlertPresented == rhs.isErrorAlertPresented
            // 注意: lastProgressUpdateTime 是内部状态，不包含在相等性比较中
        }
    }
}

// MARK: - Action

extension ExportFeature {
    /// Export Actions
    public enum Action: Equatable {
        // MARK: - User Actions (命令型)

        /// Start export with specified format
        case startExport(format: ExportFormat)

        /// Cancel ongoing export
        case cancelExport

        /// Reset export state to initial
        case resetExport

        // MARK: - System Feedback (事件型)

        /// Export preparation started (counting total events)
        case exportPreparationStarted

        /// Total count calculated
        case totalCountCalculated(Int)

        /// Progress updated
        case progressUpdated(exported: Int, total: Int)

        /// Export completed successfully
        case exportSucceeded(URL)

        /// Export failed with error
        case exportFailed(Error)

        // MARK: - UI Actions

        /// 设置分享面板显示状态
        case setShareSheetPresented(Bool)

        /// 设置错误提示显示状态
        case setErrorAlertPresented(Bool)

        /// 清除错误并重置（便捷操作）
        case dismissError

        // MARK: - Equatable

        public static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.startExport(let lf), .startExport(let rf)):
                return lf == rf
            case (.cancelExport, .cancelExport),
                 (.resetExport, .resetExport),
                 (.exportPreparationStarted, .exportPreparationStarted):
                return true
            case (.totalCountCalculated(let l), .totalCountCalculated(let r)):
                return l == r
            case (.progressUpdated(let le, let lt), .progressUpdated(let re, let rt)):
                return le == re && lt == rt
            case (.exportSucceeded(let l), .exportSucceeded(let r)):
                return l == r
            case (.exportFailed(let l), .exportFailed(let r)):
                return l.localizedDescription == r.localizedDescription
            // 新增 UI actions 比较
            case (.setShareSheetPresented(let l), .setShareSheetPresented(let r)):
                return l == r
            case (.setErrorAlertPresented(let l), .setErrorAlertPresented(let r)):
                return l == r
            case (.dismissError, .dismissError):
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - Reducer

extension ExportFeature {
    /// Export Reducer
    public struct ExportReducer: Reducer {
        public typealias State = ExportFeature.State
        public typealias Action = ExportFeature.Action

        private let environment: Environment

        public init(environment: Environment) {
            self.environment = environment
        }

        public func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            case .startExport(let format):
                return handleStartExport(&state, format: format)

            case .cancelExport:
                return handleCancelExport(&state)

            case .resetExport:
                state.reset()
                return .none

            case .exportPreparationStarted:
                state.isExporting = true
                state.progress = 0.0
                state.error = nil
                state.exportedFileURL = nil
                return .none

            case .totalCountCalculated(let total):
                state.totalCount = total
                return .none

            case .progressUpdated(let exported, let total):
                state.updateProgress(exported: exported, total: total)
                return .none

            case .exportSucceeded(let url):
                state.isExporting = false
                state.exportedFileURL = url
                state.progress = 1.0
                // 自动显示分享面板
                state.isShareSheetPresented = true
                return .none

            case .exportFailed(let error):
                state.isExporting = false
                state.error = error
                // 自动显示错误提示
                state.isErrorAlertPresented = true
                return .none

            // MARK: - UI Actions

            case .setShareSheetPresented(let presented):
                state.isShareSheetPresented = presented
                return .none

            case .setErrorAlertPresented(let presented):
                state.isErrorAlertPresented = presented
                // 如果关闭错误提示，清除错误
                if !presented {
                    state.error = nil
                }
                return .none

            case .dismissError:
                state.error = nil
                state.isErrorAlertPresented = false
                return .none
            }
        }

        // MARK: - Private Handlers

        private func handleStartExport(_ state: inout State, format: ExportFormat) -> Effect<Action> {
            // Update state
            state.format = format
            state.reset()
            state.isExporting = true

            // Capture values
            let sessionIds = state.sessionIds.isEmpty ? environment.allSessionIds : state.sessionIds
            let filterOptions = state.filterOptions
            let bundleId = state.bundleId
            let exportIdentifier = state.exportIdentifier

            return .stream(id: CancellationID.export) { [environment, filterOptions, bundleId, exportIdentifier] in
                AsyncStream { continuation in
                    Task {
                        do {
                            // Convert filterOptions to FilterFeature.State
                            let filterState = filterOptions?.toFilterState() ?? FilterFeature.State()

                            // Step 1: Notify preparation started
                            print("🔵 [ExportFeature] Export preparation started")
                            continuation.yield(.exportPreparationStarted)

                            // Step 2: Count total events
                            print("🔵 [ExportFeature] Counting total events...")
                            let totalCount = try await environment.dataLoader.countEvents(
                                sessionIds: sessionIds,
                                filterState: filterState
                            )
                            print("🟢 [ExportFeature] Total events: \(totalCount)")

                            guard totalCount > 0 else {
                                throw ExportFeatureError.emptyData
                            }

                            // Step 3: Send total count
                            continuation.yield(.totalCountCalculated(totalCount))

                            // Step 4: Generate file name
                            let fileName = generateFileName(
                                bundleId: bundleId,
                                exportIdentifier: exportIdentifier,
                                format: format
                            )

                            // Step 5: Stream export to file with progress updates
                            print("🔵 [ExportFeature] Starting streaming export...")

                            // 时间节流的进度更新（避免过度更新 UI）
                            var lastProgressUpdateTime: TimeInterval = 0
                            let progressThrottleInterval: TimeInterval = 0.1 // 100ms

                            let fileURL = try await LogParser.logEventToTempFileStreaming(
                                fileName: fileName,
                                batchSize: 1000,
                                progressHandler: { written, _ in
                                    // 忽略 LogParser 传来的 total（总是 -1），使用我们计算的 totalCount
                                    let now = Date().timeIntervalSince1970

                                    // 关键点立即更新 + 时间节流
                                    let shouldUpdate = written == 1 ||                              // 首次
                                                      written == totalCount ||                     // 末次（使用正确的 totalCount）
                                                      (now - lastProgressUpdateTime) >= progressThrottleInterval  // 节流间隔

                                    if shouldUpdate {
                                        lastProgressUpdateTime = now
                                        print("📊 [ExportFeature] Progress: \(written)/\(totalCount)")
                                        continuation.yield(.progressUpdated(exported: written, total: totalCount))
                                    }
                                },
                                eventFetcher: { offset, limit in
                                    print("🔵 [ExportFeature] Fetching batch: offset=\(offset), limit=\(limit)")
                                    return try await environment.dataLoader.loadEvents(
                                        sessionIds: sessionIds,
                                        filterState: filterState,
                                        offset: offset,
                                        limit: limit
                                    )
                                }
                            )

                            // Step 6: Export completed successfully
                            print("🟢 [ExportFeature] Export completed: \(fileURL.path)")
                            continuation.yield(.exportSucceeded(fileURL))
                            continuation.finish()

                        } catch is CancellationError {
                            print("🟡 [ExportFeature] Export cancelled")
                            // 取消不算错误，直接结束 stream
                            continuation.finish()
                        } catch {
                            print("🔴 [ExportFeature] Export failed: \(error.localizedDescription)")
                            continuation.yield(.exportFailed(error))
                            continuation.finish()
                        }
                    }
                }
            }
        }

        private func handleCancelExport(_ state: inout State) -> Effect<Action> {
            // 清理已导出的临时文件（如果存在）
            if let fileURL = state.exportedFileURL {
                cleanupTemporaryFile(at: fileURL)
            }

            // 完全重置状态（包括 UI 状态）
            state.reset()

            // 取消 Effect
            return .cancel(id: CancellationID.export)
        }

        // MARK: - Helpers

        private func generateFileName(bundleId: String?, exportIdentifier: String?, format: ExportFormat) -> String {
            // 1. 日期时间部分 - 格式：yyyy-MM-dd_HHmmss
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let dateString = dateFormatter.string(from: Date())

            // 2. bundleId 部分 - 如果为 nil，从 Bundle.main 获取
            let resolvedBundleId = bundleId ?? Bundle.main.bundleIdentifier

            // 3. 构建前缀部分
            var components: [String] = []

            // 添加 bundleId（如果存在且非空）
            if let resolvedBundleId = resolvedBundleId, !resolvedBundleId.isEmpty {
                components.append(resolvedBundleId)
            }

            // 添加 identifier（如果存在且非空）
            if let exportIdentifier = exportIdentifier, !exportIdentifier.isEmpty {
                components.append(exportIdentifier)
            }

            // 4. 组合文件名
            let prefix = components.joined(separator: "_")
            let fileName = prefix.isEmpty ? dateString : "\(prefix)_\(dateString)"

            // 5. 添加扩展名
            let ext = format == .log ? "log" : "json"

            return "\(fileName).\(ext)"
        }

        /// 清理临时文件
        private func cleanupTemporaryFile(at url: URL) {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    print("🗑️ [ExportFeature] Cleaned up temporary file: \(url.path)")
                }
            } catch {
                print("⚠️ [ExportFeature] Failed to cleanup temporary file: \(error.localizedDescription)")
            }
        }

        // MARK: - Cancellation IDs

        enum CancellationID: Hashable {
            case export
        }
    }
}

// MARK: - Environment

extension ExportFeature {
    /// Export Environment (依赖注入)
    public struct Environment {
        /// Data loader for fetching events
        let dataLoader: LogDataLoaderProtocol

        /// All available session IDs (for "export all" scenario)
        let allSessionIds: Set<String>

        // MARK: - Live Environment

        public static func live(
            dataLoader: LogDataLoaderProtocol,
            allSessionIds: Set<String>
        ) -> Environment {
            Environment(
                dataLoader: dataLoader,
                allSessionIds: allSessionIds
            )
        }
    }
}
