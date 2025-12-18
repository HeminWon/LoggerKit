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

        // MARK: - Initializer

        public init() {}

        // MARK: - State Mutations

        /// Reset to initial state
        public mutating func reset() {
            isExporting = false
            progress = 0.0
            exportedCount = 0
            totalCount = 0
            exportedFileURL = nil
            error = nil
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
            lhs.error?.localizedDescription == rhs.error?.localizedDescription
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
                return .none

            case .exportFailed(let error):
                state.isExporting = false
                state.error = error
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

            return .cancellable(id: CancellationID.export) { [environment, filterOptions] in
                do {
                    // Convert filterOptions to FilterState on MainActor
                    let filterState = await MainActor.run {
                        filterOptions?.toFilterState() ?? FilterState()
                    }

                    // Step 1: Count total events
                    print("🔵 [ExportFeature] Counting total events...")
                    let totalCount = try await environment.dataLoader.countEvents(
                        sessionIds: sessionIds,
                        filterState: filterState
                    )
                    print("🟢 [ExportFeature] Total events: \(totalCount)")

                    guard totalCount > 0 else {
                        throw ExportFeatureError.emptyData
                    }

                    // Step 2: Generate file name
                    let fileName = generateFileName(
                        sessionIds: sessionIds,
                        format: format
                    )

                    // Step 3: Stream export to file
                    print("🔵 [ExportFeature] Starting streaming export...")
                    let fileURL = try await LogParser.logEventToTempFileStreaming(
                        fileName: fileName,
                        batchSize: 1000,
                        progressHandler: { written, _ in
                            print("📊 [ExportFeature] Progress: \(written)/\(totalCount)")
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

                    print("🟢 [ExportFeature] Export completed: \(fileURL.path)")
                    return .exportSucceeded(fileURL)

                } catch {
                    print("🔴 [ExportFeature] Export failed: \(error.localizedDescription)")
                    return .exportFailed(error)
                }
            }
        }

        private func handleCancelExport(_ state: inout State) -> Effect<Action> {
            state.isExporting = false
            return .cancel(id: CancellationID.export)
        }

        // MARK: - Helpers

        private func generateFileName(sessionIds: Set<String>, format: ExportFormat) -> String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let dateString = dateFormatter.string(from: Date())

            let sessionIdentifier = sessionIds.count == 1 ? sessionIds.first! : "all"
            let ext = format == .log ? "log" : "json"

            return "logs_\(sessionIdentifier)_\(dateString).\(ext)"
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
