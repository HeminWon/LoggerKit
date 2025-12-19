//
//  LogDetailReducer.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - LogDetailReducer

/// Main reducer for the log detail scene (协调器模式)
///
/// This reducer acts as a coordinator and delegates to sub-features:
/// - LogList Feature: List data loading, pagination, query sequencing
/// - Export Feature: Log export functionality
/// - Filter Feature: Filter management
/// - Search Feature: Search functionality
/// - Delete Feature: Log deletion
///
/// Legacy sub-reducers:
/// - CacheReducer: Cache management
///
/// DEPRECATED sub-reducers (已移除):
/// - FilterReducer: ❌ Removed, use FilterFeature instead
/// - PaginationReducer: ❌ Merged into LogList Feature
public struct LogDetailReducer: Reducer {
    public typealias State = LogDetailState
    public typealias Action = LogDetailAction

    private let environment: LogDetailEnvironment

    // Sub-reducers
    private let listReducer: LogList.Reducer  // ✅ LogList Reducer
    // ❌ 已移除: private let filterReducer: FilterReducer  // 使用 FilterFeature 代替
    private let cacheReducer: CacheReducer
    private let exportReducer: ExportFeature.ExportReducer
    private let filterFeatureReducer: FilterFeature.Reducer
    private let searchFeatureReducer: SearchFeature.Reducer
    private let deleteFeatureReducer: DeleteFeature.DeleteReducer

    public init(environment: LogDetailEnvironment) {
        self.environment = environment

        // Initialize LogList.Reducer with LogList.Environment
        let listEnvironment = LogList.Environment.live(
            dataLoader: environment.dataLoader,
            sessionIds: environment.sessionIds
        )
        self.listReducer = LogList.Reducer(environment: listEnvironment)

        // ❌ 已移除: self.filterReducer = FilterReducer(environment: environment)  // 使用 FilterFeature 代替
        self.cacheReducer = CacheReducer()

        // Initialize ExportReducer with ExportFeature.Environment
        let exportEnvironment = ExportFeature.Environment.live(
            dataLoader: environment.dataLoader,
            allSessionIds: environment.sessionIds
        )
        self.exportReducer = ExportFeature.ExportReducer(environment: exportEnvironment)

        // Initialize FilterFeature.Reducer with FilterFeature.Environment
        let filterFeatureEnvironment = FilterFeature.Environment.live(
            dataLoader: environment.dataLoader
        )
        self.filterFeatureReducer = FilterFeature.Reducer(environment: filterFeatureEnvironment)

        // Initialize SearchFeature.Reducer
        self.searchFeatureReducer = SearchFeature.Reducer()

        // Initialize DeleteFeature.DeleteReducer with DeleteFeature.Environment
        let deleteFeatureEnvironment = DeleteFeature.Environment(
            databaseManager: environment.databaseManager
        )
        self.deleteFeatureReducer = DeleteFeature.DeleteReducer(environment: deleteFeatureEnvironment)
    }

    public func reduce(_ state: inout LogDetailState, _ action: LogDetailAction) -> Effect<LogDetailAction> {
        // First, let sub-reducers handle their actions
        let subEffects = [
            // ❌ 已移除: filterReducer.reduce(&state, action),  // 使用 FilterFeature 代替
            cacheReducer.reduce(&state, action)
        ]

        // Then handle core actions
        let coreEffect = reduceCoreActions(&state, action)

        // Merge all effects
        let allEffects = subEffects + [coreEffect]
        let nonNoneEffects = allEffects.filter { effect in
            if case .none = effect {
                return false
            }
            return true
        }

        guard !nonNoneEffects.isEmpty else {
            return .none
        }

        return .multiple(nonNoneEffects)
    }

    // MARK: - Core Actions

    private func reduceCoreActions(_ state: inout LogDetailState, _ action: LogDetailAction) -> Effect<LogDetailAction> {
        switch action {
        case .loadLogFile:
            // ⚠️ 向后兼容: 委托给 LogList Feature
            // 同步 filterState 到 LogList
            state.list.filterState = state.filterFeature

            return .multiple([
                // Delegate to LogList
                .task { .list(.loadLogFile) },
                // Load statistics
                .task { [environment] in
                    do {
                        let stats = try await environment.dataLoader.loadStatistics()
                        return .statisticsLoaded(stats)
                    } catch {
                        // Statistics failure doesn't fail the whole load
                        return .statisticsLoaded(LogStatistics(totalCount: 0, levelCounts: [:], topFunctions: []))
                    }
                },
                // Load all events for search preview
                .task { [environment] in
                    do {
                        let allEvents = try await environment.dataLoader.loadAllEventsForSearchPreview(
                            sessionIds: environment.sessionIds,
                            limit: 10000
                        )
                        print("🟢 [LogDetailReducer] allEventsLoaded: \(allEvents.count) events")
                        return .allEventsLoaded(allEvents)
                    } catch {
                        // Search preview failure doesn't fail the whole load
                        print("🔴 [LogDetailReducer] loadAllEventsForSearchPreview failed: \(error)")
                        return .allEventsLoaded([])
                    }
                }
            ])

        case .refresh:
            // ⚠️ 向后兼容: 委托给 LogList Feature
            return .task { .list(.refresh) }

        case .logsLoaded:
            // ⚠️ 向后兼容: 现在由 LogList Feature 处理（通过 PaginationReducer 已合并到 LogList）
            // 这个 case 不应该再被触发，因为新的流程使用 .list(.loadSucceeded)
            return .none

        case .loadMore:
            // ⚠️ 向后兼容: 委托给 LogList Feature
            return .task { .list(.loadMore) }

        case .allEventsLoaded(let events):
            state.allEventsForSearchPreview = events
            print("🔵 [LogDetailReducer] Forwarding \(events.count) events to SearchFeature")
            // Sync to SearchFeature
            return .task { .search(.allEventsLoaded(events)) }

        case .loadingFailed(let error):
            state.loadingState = .failed(error)
            state.error = error
            return .none

        case .statisticsLoaded(let stats):
            state.statistics = stats
            return .none

        case .exportStarted:
            // Reset export state when export starts
            state.exportState = ExportState()
            state.exportState.isExporting = true
            state.error = nil
            return .none

        case .exportProgressUpdated(let exported, let total):
            // Update export progress
            state.exportState.exportedCount = exported
            state.exportState.totalCount = total
            state.exportState.progress = total > 0 ? Double(exported) / Double(total) : 0.0
            return .none

        case .exportLogs(_, let progress):
            // Clear previous export state before starting new export
            state.exportState = ExportState()
            state.exportState.isExporting = true
            state.error = nil

            // Export logs with streaming approach
            // Capture values
            let sessionIds = environment.sessionIds
            let levels = state.selectedLevels
            let functions = state.selectedFunctions
            let fileNames = state.selectedFileNames
            let contexts = state.selectedContexts
            let threads = state.selectedThreads
            let messageKeywords = state.selectedMessageKeywords
            let sessionIdFilters = state.selectedSessionIds

            return .task { [environment] in
                print("🔵 [Export] Streaming export started")
                do {
                    // 1. Count total events for progress tracking
                    print("🔵 [Export] Counting total events...")
                    let filterState = await MainActor.run {
                        let fs = FilterState()
                        fs.selectedLevels = levels
                        fs.selectedFunctions = functions
                        fs.selectedFileNames = fileNames
                        fs.selectedContexts = contexts
                        fs.selectedThreads = threads
                        fs.selectedMessageKeywords = messageKeywords
                        fs.selectedSessionIds = sessionIdFilters
                        return fs
                    }

                    let totalCount = try await environment.dataLoader.countEvents(
                        sessionIds: sessionIds,
                        filterState: filterState
                    )
                    print("🟢 [Export] Total events to export: \(totalCount)")

                    guard totalCount > 0 else {
                        throw ExportError.emptyData
                    }

                    // 2. Generate file name with timestamp
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                    let dateString = dateFormatter.string(from: Date())
                    let sessionIdentifier = sessionIds.count == 1 ? sessionIds.first! : "all"
                    let fileName = "logs_\(sessionIdentifier)_\(dateString).log"

                    // 3. Use streaming export
                    print("🔵 [Export] Starting streaming write to file: \(fileName)")
                    let fileURL = try await LogParser.logEventToTempFileStreaming(
                        fileName: fileName,
                        batchSize: 1000,
                        progressHandler: { written, _ in
                            // Update progress with actual total
                            let progressPercent = Double(written) / Double(totalCount)
                            progress(progressPercent)
                            print("📊 [Export] Progress: \(written)/\(totalCount) (\(Int(progressPercent * 100))%)")
                        },
                        eventFetcher: { offset, limit in
                            // Fetch events in batches
                            print("🔵 [Export] Fetching batch: offset=\(offset), limit=\(limit)")
                            let events = try await environment.dataLoader.loadEvents(
                                sessionIds: sessionIds,
                                filterState: filterState,
                                offset: offset,
                                limit: limit
                            )
                            return events
                        }
                    )

                    print("🟢 [Export] Streaming export completed: \(fileURL.path)")
                    return .exportCompleted(fileURL)
                } catch {
                    print("🔴 [Export] Error: \(error.localizedDescription)")
                    return .exportFailed(error)
                }
            }

        case .exportCompleted(let url):
            // Store exported file URL and show share sheet
            print("🟢 [Export] .exportCompleted received, setting exportedFileURL = \(url.path)")
            state.exportState.isExporting = false
            state.exportState.exportedFileURL = url
            state.isSharePresented = true
            return .none

        case .exportFailed(let error):
            // Store error and show error alert
            print("🔴 [Export] .exportFailed received: \(error.localizedDescription)")
            state.exportState.isExporting = false
            state.error = error
            state.showExportError = true
            return .none

        case .deleteAllLogs:
            return .task { [environment] in
                do {
                    try await environment.databaseManager.deleteLogs(forSessions: environment.sessionIds)
                    return .deletionCompleted
                } catch {
                    return .deletionFailed(error)
                }
            }

        case .deletionCompleted:
            // Reload after deletion
            return reduceCoreActions(&state, .loadLogFile)

        case .deletionFailed(let error):
            state.error = error
            return .none

        case .setSharePresented(let value):
            state.isSharePresented = value
            return .none

        case .setFilterPresented(let value):
            state.isFilterPresented = value
            return .none

        case .setDeleteManagementPresented(let value):
            state.isDeleteManagementPresented = value
            return .none

        case .setExportErrorPresented(let value):
            state.showExportError = value
            return .none

        case .list(let listAction):
            // Delegate to LogList.Reducer
            let listEffect = listReducer.reduce(&state.list, listAction)

            // 如果是 loadLogFile,也需要加载搜索预览数据和统计信息
            if case .loadLogFile = listAction {
                return .multiple([
                    listEffect.map { .list($0) },
                    // Load statistics
                    .task { [environment] in
                        do {
                            let stats = try await environment.dataLoader.loadStatistics()
                            return .statisticsLoaded(stats)
                        } catch {
                            return .statisticsLoaded(LogStatistics(totalCount: 0, levelCounts: [:], topFunctions: []))
                        }
                    },
                    // Load all events for search preview
                    .task { [environment] in
                        do {
                            let allEvents = try await environment.dataLoader.loadAllEventsForSearchPreview(
                                sessionIds: environment.sessionIds,
                                limit: 10000
                            )
                            print("🟢 [LogDetailReducer] allEventsLoaded: \(allEvents.count) events")
                            return .allEventsLoaded(allEvents)
                        } catch {
                            print("🔴 [LogDetailReducer] loadAllEventsForSearchPreview failed: \(error)")
                            return .allEventsLoaded([])
                        }
                    }
                ])
            }

            return listEffect.map { .list($0) }

        case .export(let exportAction):
            // Delegate to ExportFeature.Reducer
            let exportEffect = exportReducer.reduce(&state.exportFeature, exportAction)
            return exportEffect.map { .export($0) }

        case .filter(let filterAction):
            // Delegate to FilterFeature.Reducer
            let filterEffect = filterFeatureReducer.reduce(&state.filterFeature, filterAction)

            // 始终同步 filterState 到 LogList.State（确保数据一致性）
            state.list.filterState = state.filterFeature

            // Check if this is the availableOptionsLoaded event
            if case .availableOptionsLoaded(let functions, let fileNames, let contexts, let threads) = filterAction {
                // 将加载的选项缓存到父层状态
                state.cachedAvailableFunctions = functions
                state.cachedAvailableFileNames = fileNames
                state.cachedAvailableContexts = contexts
                state.cachedAvailableThreads = threads
                print("🟢 [FilterFeature] Available options cached: \(functions.count) functions, \(fileNames.count) files")
            }

            // Check if this is the filtersApplied event
            if case .filtersApplied = filterAction {
                // Filters have been applied, trigger list refresh
                print("🟢 [FilterFeature] Filters applied, triggering list refresh")
                state.resetPagination()

                // Return combined effects: filter effect + reload data
                return .multiple([
                    filterEffect.map { .filter($0) },
                    .task { .list(.refresh) }  // ✅ 使用 LogList.refresh
                ])
            }

            // 对于显式的 applyFilters 操作，关闭筛选面板
            if case .applyFilters = filterAction {
                state.isFilterPresented = false
            }

            return filterEffect.map { .filter($0) }

        case .search(let searchAction):
            // Delegate to SearchFeature.Reducer
            let searchEffect = searchFeatureReducer.reduce(&state.searchFeature, searchAction)
            return searchEffect.map { .search($0) }

        case .delete(let deleteAction):
            // Delegate to DeleteFeature.DeleteReducer
            let deleteEffect = deleteFeatureReducer.reduce(&state.deleteFeature, deleteAction)

            // Check if this is the deletionConfirmed event
            if case .deletionConfirmed = deleteAction {
                // Deletion completed, close sheet and refresh list
                print("🟢 [DeleteFeature] Deletion confirmed, triggering list refresh")
                state.isDeleteManagementPresented = false
                state.resetPagination()

                // Return combined effects: delete effect + reload data
                return .multiple([
                    deleteEffect.map { .delete($0) },
                    .task { .list(.refresh) }  // ✅ 使用 LogList.refresh
                ])
            }

            return deleteEffect.map { .delete($0) }

        default:
            // Already handled by sub-reducers
            return .none
        }
    }

}
