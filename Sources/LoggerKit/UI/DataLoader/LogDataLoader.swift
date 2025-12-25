//
//  LogDataLoader.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/12/15.
//

import Foundation
import CoreData

/// 日志数据加载器实现
@MainActor
public class LogDataLoader: LogDataLoaderProtocol {

    // MARK: - Properties

    private let databaseManager: LogDatabaseManagerProtocol
    private var currentTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(databaseManager: LogDatabaseManagerProtocol) {
        self.databaseManager = databaseManager
    }

    // MARK: - LogDataLoaderProtocol

    public func loadEvents(
        sessionIds: Set<String>,
        filterState: FilterFeature.State,
        offset: Int,
        limit: Int
    ) async throws -> [LogEvent] {
        // 在主线程捕获需要的值
        let dbManager = self.databaseManager
        let levels = filterState.selectedLevels
        let functions = filterState.selectedFunctions
        let fileNames = filterState.selectedFileNames
        let contexts = filterState.selectedContexts
        let threads = filterState.selectedThreads
        let messageKeywords = filterState.selectedMessageKeywords
        let selectedSessionIds = filterState.selectedSessionIds

        // 合并 sessionIds: 优先使用用户选择的 selectedSessionIds,否则使用环境的 sessionIds
        // 如果用户选择了特定会话,只查询这些会话;否则使用环境限定的会话范围
        let finalSessionIds: Set<String> = selectedSessionIds.isEmpty ? sessionIds : selectedSessionIds

        // 使用 performBackgroundTask 确保线程安全
        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    // 在后台 context 中执行查询
                    let events = try dbManager.fetchEvents(
                        in: context,
                        levels: levels,
                        functions: functions,
                        fileNames: fileNames,
                        contexts: contexts,
                        threads: threads,
                        sessionIds: finalSessionIds,  // ✅ 使用合并后的 sessionIds
                        messageKeywords: messageKeywords,
                        sortDescriptors: [],
                        limit: limit,
                        offset: offset
                    )

                    continuation.resume(returning: events)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func loadStatistics() async throws -> LogStatistics {
        let dbManager = self.databaseManager

        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    // fetchStatistics()内部使用自己的viewContext,这里只需要在后台线程调用
                    let stats = try dbManager.fetchStatistics()
                    continuation.resume(returning: stats)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func countEvents(
        sessionIds: Set<String>,
        filterState: FilterFeature.State
    ) async throws -> Int {
        // 在主线程捕获需要的值
        let dbManager = self.databaseManager
        let levels = filterState.selectedLevels
        let functions = filterState.selectedFunctions
        let fileNames = filterState.selectedFileNames
        let contexts = filterState.selectedContexts
        let threads = filterState.selectedThreads
        let messageKeywords = filterState.selectedMessageKeywords
        let selectedSessionIds = filterState.selectedSessionIds

        // 合并 sessionIds: 优先使用用户选择的 selectedSessionIds,否则使用环境的 sessionIds
        let finalSessionIds: Set<String> = selectedSessionIds.isEmpty ? sessionIds : selectedSessionIds

        // 使用 performBackgroundTask 确保线程安全
        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    // 在后台 context 中执行 COUNT 查询
                    let count = try dbManager.countEvents(
                        in: context,
                        levels: levels,
                        functions: functions,
                        fileNames: fileNames,
                        contexts: contexts,
                        threads: threads,
                        sessionIds: finalSessionIds,  // ✅ 使用合并后的 sessionIds
                        messageKeywords: messageKeywords
                    )

                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func loadAllEvents(
        sessionIds: Set<String>,
        filterState: FilterFeature.State
    ) async throws -> [LogEvent] {
        // 在主线程捕获需要的值
        let dbManager = self.databaseManager
        let levels = filterState.selectedLevels
        let functions = filterState.selectedFunctions
        let fileNames = filterState.selectedFileNames
        let contexts = filterState.selectedContexts
        let threads = filterState.selectedThreads
        let messageKeywords = filterState.selectedMessageKeywords
        let selectedSessionIds = filterState.selectedSessionIds

        // 合并 sessionIds: 优先使用用户选择的 selectedSessionIds,否则使用环境的 sessionIds
        let finalSessionIds: Set<String> = selectedSessionIds.isEmpty ? sessionIds : selectedSessionIds

        // 使用 performBackgroundTask 确保线程安全
        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    // 在后台 context 中执行全量查询(使用大数值作为 limit)
                    let events = try dbManager.fetchEvents(
                        in: context,
                        levels: levels,
                        functions: functions,
                        fileNames: fileNames,
                        contexts: contexts,
                        threads: threads,
                        sessionIds: finalSessionIds,  // ✅ 使用合并后的 sessionIds
                        messageKeywords: messageKeywords,
                        sortDescriptors: [],
                        limit: 100000,  // 使用大数值代替无限制
                        offset: 0
                    )

                    continuation.resume(returning: events)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func loadAllEventsForSearchPreview(
        sessionIds: Set<String>,
        limit: Int
    ) async throws -> [LogEvent] {
        let dbManager = self.databaseManager

        // 使用 performBackgroundTask 确保线程安全
        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    // 在后台 context 中执行全量查询
                    let events = try dbManager.fetchAllEventsForSearchPreview(
                        in: context,
                        sessionIds: sessionIds,
                        limit: limit
                    )

                    continuation.resume(returning: events)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - 筛选选项查询方法

    public func getAvailableFunctions() async throws -> [String] {
        let dbManager = self.databaseManager

        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    let functions = try dbManager.fetchAvailableFunctions()
                    continuation.resume(returning: functions)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func getAvailableFileNames() async throws -> [String] {
        let dbManager = self.databaseManager

        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    let fileNames = try dbManager.fetchAvailableFileNames()
                    continuation.resume(returning: fileNames)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func getAvailableContexts() async throws -> [String] {
        let dbManager = self.databaseManager

        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    let contexts = try dbManager.fetchAvailableContexts()
                    continuation.resume(returning: contexts)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func getAvailableThreads() async throws -> [String] {
        let dbManager = self.databaseManager

        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    let threads = try dbManager.fetchAvailableThreads()
                    continuation.resume(returning: threads)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Deep Search Support

    public func getSessions(
        sessionIds: Set<String>,
        sortOrder: LogDatabaseManager.SessionSortOrder
    ) async throws -> [SessionInfo] {
        let dbManager = self.databaseManager

        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    let sessions = try dbManager.getSessions(
                        in: context,
                        sessionIds: sessionIds,
                        sortOrder: sortOrder
                    )
                    continuation.resume(returning: sessions)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func searchEvents(
        sessionIds: Set<String>,
        searchText: String,
        searchFields: Set<SearchField>,
        limit: Int
    ) async throws -> [LogEvent] {
        let dbManager = self.databaseManager

        // 将 SearchField 转换为字段名字符串数组
        let fieldNames = searchFields.map { field in
            switch field {
            case .message: return "message"
            case .fileName: return "fileName"
            case .function: return "function"
            case .context: return "context"
            case .thread: return "thread"
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            CoreDataStack.shared.persistentContainer.performBackgroundTask { context in
                do {
                    let events = try dbManager.searchEvents(
                        in: context,
                        sessionIds: sessionIds,
                        searchText: searchText,
                        searchFields: fieldNames,
                        limit: limit
                    )
                    continuation.resume(returning: events)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
