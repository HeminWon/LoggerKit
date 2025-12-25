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
            dataLoader: environment.dataLoader,
            databaseManager: environment.databaseManager
        )
        self.filterFeatureReducer = FilterFeature.Reducer(environment: filterFeatureEnvironment)

        // Initialize SearchFeature.Reducer with dataLoader dependency
        self.searchFeatureReducer = SearchFeature.Reducer(dataLoader: environment.dataLoader)

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
        case .allEventsLoaded(let events):
            // 保留 allEventsForSearchPreview 用于其他功能（如筛选选项提取）
            state.allEventsForSearchPreview = events
            print("🔵 [LogDetailReducer] Loaded \(events.count) events for preview (not forwarding to SearchFeature - using DB search now)")
            // 新的深度搜索不再需要 allEventsLoaded，直接查询数据库
            return .none

        case .loadingFailed(let error):
            state.loadingState = .failed(error)
            state.error = error
            return .none

        case .statisticsLoaded(let stats):
            state.statistics = stats
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
            return .task { .list(.loadLogFile) }

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
            // 同步过滤状态到导出功能（类似第 223 行对列表的同步）
            if case .startExport = exportAction {
                state.exportFeature.filterOptions = state.filterFeature.toExportFilterOptions()
            }

            // Delegate to ExportFeature.Reducer
            let exportEffect = exportReducer.reduce(&state.exportFeature, exportAction)

            // Sync UI state from ExportFeature to LogDetailState
            switch exportAction {
            case .exportSucceeded:
                // 导出成功，显示分享面板
                state.isSharePresented = true
                print("🟢 [LogDetailReducer] Setting isSharePresented = true after exportSucceeded")

            case .exportFailed:
                // 导出失败，显示错误提示
                state.showExportError = true
                print("🔴 [LogDetailReducer] Setting showExportError = true after exportFailed")

            default:
                break
            }

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

            // 监听删除成功事件，同步更新 FilterFeature 的会话列表
            if case .singleSessionDeleted(.success(let sessionId)) = deleteAction {
                // 同步更新 FilterFeature 的状态
                state.filterFeature.availableSessions.removeAll { $0.id == sessionId }
                state.filterFeature.selectedSessionIds.remove(sessionId)
                print("🟢 [LogDetailReducer] Session \(sessionId) deleted, synced to FilterFeature")
            }

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
