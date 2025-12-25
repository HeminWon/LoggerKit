//
//  LogDetailEnvironment.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation
import CoreData

// MARK: - LogDetailEnvironment

/// Dependency container for the log detail feature
///
/// The Environment pattern centralizes all dependencies:
/// - Data loading
/// - Database access
/// - File system operations
///
/// Benefits:
/// - Easy to test (swap live for mock)
/// - Clear dependency declaration
/// - Single source of truth
///
/// Example:
/// ```swift
/// // Production
/// let env = LogDetailEnvironment.live
///
/// // Testing
/// let env = LogDetailEnvironment.mock
/// ```
public struct LogDetailEnvironment {
    // MARK: - Dependencies

    /// Data loader for fetching log events
    public let dataLoader: LogDataLoaderProtocol

    /// Database manager for database operations
    public let databaseManager: LogDatabaseManagerProtocol

    /// Session IDs to filter (if any)
    public let sessionIds: Set<String>

    // MARK: - Initialization

    public init(
        dataLoader: LogDataLoaderProtocol,
        databaseManager: LogDatabaseManagerProtocol,
        sessionIds: Set<String> = []
    ) {
        self.dataLoader = dataLoader
        self.databaseManager = databaseManager
        self.sessionIds = sessionIds
    }

    // MARK: - Live Environment

    /// Production environment with real dependencies
    @MainActor
    public static func live(sessionIds: Set<String> = []) -> LogDetailEnvironment {
        guard let dbManager = LoggerEngine.shared.getDatabaseManager() else {
            fatalError("DatabaseManager not initialized. Call LoggerEngine.shared.setup() first.")
        }

        let dataLoader = LogDataLoader(databaseManager: dbManager)

        return LogDetailEnvironment(
            dataLoader: dataLoader,
            databaseManager: dbManager,
            sessionIds: sessionIds
        )
    }

    // MARK: - Mock Environment

    /// Mock environment for testing
    @MainActor
    public static func mock(
        dataLoader: LogDataLoaderProtocol? = nil,
        databaseManager: LogDatabaseManagerProtocol? = nil,
        sessionIds: Set<String> = []
    ) -> LogDetailEnvironment {
        return LogDetailEnvironment(
            dataLoader: dataLoader ?? MockLogDataLoader(),
            databaseManager: databaseManager ?? MockLogDatabaseManager(),
            sessionIds: sessionIds
        )
    }
}

// MARK: - Mock Implementations

/// Mock data loader for testing
@MainActor
public final class MockLogDataLoader: LogDataLoaderProtocol {
    public var mockEvents: [LogEvent] = []
    public var mockStatistics: LogStatistics?
    public var mockTotalCount: Int = 0
    public var shouldThrowError: Bool = false
    public var loadEventsCallCount: Int = 0
    public var loadStatisticsCallCount: Int = 0

    public init() {}

    public func loadEvents(
        sessionIds: Set<String>,
        filterState: FilterFeature.State,
        offset: Int,
        limit: Int
    ) async throws -> [LogEvent] {
        loadEventsCallCount += 1

        if shouldThrowError {
            throw MockError.loadFailed
        }

        let start = min(offset, mockEvents.count)
        let end = min(start + limit, mockEvents.count)
        return Array(mockEvents[start..<end])
    }

    public func loadStatistics() async throws -> LogStatistics {
        loadStatisticsCallCount += 1

        if shouldThrowError {
            throw MockError.loadFailed
        }

        return mockStatistics ?? LogStatistics(
            totalCount: 0,
            levelCounts: [:],
            topFunctions: []
        )
    }

    public func countEvents(
        sessionIds: Set<String>,
        filterState: FilterFeature.State
    ) async throws -> Int {
        if shouldThrowError {
            throw MockError.loadFailed
        }
        return mockTotalCount
    }

    public func loadAllEvents(
        sessionIds: Set<String>,
        filterState: FilterFeature.State
    ) async throws -> [LogEvent] {
        if shouldThrowError {
            throw MockError.loadFailed
        }
        return mockEvents
    }

    public func loadAllEventsForSearchPreview(
        sessionIds: Set<String>,
        limit: Int
    ) async throws -> [LogEvent] {
        if shouldThrowError {
            throw MockError.loadFailed
        }
        return Array(mockEvents.prefix(limit))
    }

    public func cancelCurrentTask() {
        // No-op for mock
    }

    // MARK: - 筛选选项查询方法

    public func getAvailableFunctions() async throws -> [String] {
        if shouldThrowError {
            throw MockError.loadFailed
        }
        return ["func1", "func2", "func3"]
    }

    public func getAvailableFileNames() async throws -> [String] {
        if shouldThrowError {
            throw MockError.loadFailed
        }
        return ["file1.swift", "file2.swift"]
    }

    public func getAvailableContexts() async throws -> [String] {
        if shouldThrowError {
            throw MockError.loadFailed
        }
        return ["context1", "context2"]
    }

    public func getAvailableThreads() async throws -> [String] {
        if shouldThrowError {
            throw MockError.loadFailed
        }
        return ["main", "background"]
    }

    // MARK: - Deep Search Support

    public func getSessions(
        sessionIds: Set<String>,
        sortOrder: LogDatabaseManager.SessionSortOrder
    ) async throws -> [SessionInfo] {
        if shouldThrowError {
            throw MockError.loadFailed
        }
        // Return empty array for mock
        return []
    }

    public func searchEvents(
        sessionIds: Set<String>,
        searchText: String,
        searchFields: Set<SearchField>,
        limit: Int
    ) async throws -> [LogEvent] {
        if shouldThrowError {
            throw MockError.loadFailed
        }
        // Simple mock implementation: filter mockEvents by searchText in message
        return mockEvents.filter { $0.message.contains(searchText) }
    }

    enum MockError: Error {
        case loadFailed
    }
}

/// Mock database manager for testing
@MainActor
public final class MockLogDatabaseManager: LogDatabaseManagerProtocol {
    public var mockDeleteAllResult: Result<Void, Error> = .success(())
    public var deleteAllLogsCallCount: Int = 0

    public init() {}

    // MARK: - LogDatabaseManagerProtocol Implementation

    public func fetchEvents(
        in context: NSManagedObjectContext?,
        levels: Set<LogEvent.Level>,
        functions: Set<String>,
        fileNames: Set<String>,
        contexts: Set<String>,
        threads: Set<String>,
        sessionIds: Set<String>,
        messageKeywords: Set<String>,
        sortDescriptors: [NSSortDescriptor],
        limit: Int,
        offset: Int
    ) throws -> [LogEvent] {
        return []
    }

    public func fetchEvents(
        forDate date: String,
        levels: Set<LogEvent.Level>,
        sortDescriptors: [NSSortDescriptor],
        limit: Int,
        offset: Int
    ) throws -> [LogEvent] {
        return []
    }

    public func fetchAllEventsForSearchPreview(
        in context: NSManagedObjectContext?,
        sessionIds: Set<String>,
        limit: Int
    ) throws -> [LogEvent] {
        return []
    }

    public func fetchStatistics() throws -> LogStatistics {
        return LogStatistics(totalCount: 0, levelCounts: [:], topFunctions: [])
    }

    public func countEvents(
        in context: NSManagedObjectContext?,
        levels: Set<LogEvent.Level>,
        functions: Set<String>,
        fileNames: Set<String>,
        contexts: Set<String>,
        threads: Set<String>,
        sessionIds: Set<String>,
        messageKeywords: Set<String>
    ) throws -> Int {
        return 0
    }

    public func fetchUniqueValues(for field: String) throws -> [String] {
        return []
    }

    public func fetchAllSessions() throws -> [SessionInfo] {
        return []
    }

    // MARK: - 筛选选项查询方法

    public func fetchAvailableFunctions() throws -> [String] {
        return ["func1", "func2"]
    }

    public func fetchAvailableFileNames() throws -> [String] {
        return ["file1.swift", "file2.swift"]
    }

    public func fetchAvailableContexts() throws -> [String] {
        return ["context1"]
    }

    public func fetchAvailableThreads() throws -> [String] {
        return ["main"]
    }

    public func deleteAllLogs() throws {
        deleteAllLogsCallCount += 1
        switch mockDeleteAllResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    public func deleteLogs(forDate date: String) throws {}

    public func deleteLogs(before date: Date) throws {}

    public func deleteLogs(forSession sessionId: String) throws {}

    public func deleteLogs(forSessions sessionIds: Set<String>) throws {
        deleteAllLogsCallCount += 1
        switch mockDeleteAllResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    public func databaseSize() -> Int64 {
        return 0
    }

    // MARK: - Deep Search Support

    public func getSessions(
        in context: NSManagedObjectContext?,
        sessionIds: Set<String>,
        sortOrder: LogDatabaseManager.SessionSortOrder
    ) throws -> [SessionInfo] {
        return []
    }

    public func searchEvents(
        in context: NSManagedObjectContext?,
        sessionIds: Set<String>,
        searchText: String,
        searchFields: [String],
        limit: Int
    ) throws -> [LogEvent] {
        return []
    }
}
