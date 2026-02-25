//
//  LogDatabaseManager.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025/11/25.
//

import CoreData
import Combine

/// 会话信息
public struct SessionInfo: Identifiable, Hashable {
    public let id: String  // sessionId
    public let startTime: TimeInterval
    public let logCount: Int

    public init(id: String, startTime: TimeInterval, logCount: Int) {
        self.id = id
        self.startTime = startTime
        self.logCount = logCount
    }
}

/// 日志统计信息
public struct LogStatistics {
    public let totalCount: Int
    public let levelCounts: [Int: Int]
    public let topFunctions: [(String, Int)]
}

public final class LogDatabaseManager: LogDatabaseManagerProtocol {

    private let coreDataStack: CoreDataStack?

    public init(coreDataStack: CoreDataStack? = CoreDataStack.shared) {
        if let coreDataStack {
            self.coreDataStack = coreDataStack
            return
        }

        CoreDataStack.initialize()
        self.coreDataStack = CoreDataStack.shared
    }

    // MARK: - 私有辅助方法

    /// 获取 CoreDataStack，如果不可用则抛出错误
    private func getStack() throws -> CoreDataStack {
        guard let stack = coreDataStack else {
            throw NSError(
                domain: "LogDatabaseManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "CoreDataStack 不可用"]
            )
        }
        return stack
    }

    /// 在后台线程执行 CoreData 操作，避免阻塞主线程
    /// - Parameter block: 在后台上下文中执行的操作
    /// - Note: 此方法为异步操作，不会阻塞调用线程
    private func performBackgroundOperation(_ block: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        let context = try getStack().newBackgroundContext()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    try block(context)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 构建查询谓词（复用逻辑，消除 fetchEvents 和 countEvents 的重复代码）
    private func buildPredicates(
        levels: Set<LogEvent.Level>,
        functions: Set<String>,
        fileNames: Set<String>,
        contexts: Set<String>,
        threads: Set<String>,
        sessionIds: Set<String>,
        messageKeywords: Set<String>
    ) -> [NSPredicate] {
        var predicates: [NSPredicate] = []

        // 日志等级筛选
        if !levels.isEmpty {
            let levelValues = levels.map { Int16($0.rawValue) }
            predicates.append(NSPredicate(format: "level IN %@", levelValues))
        }

        // 函数名筛选
        if !functions.isEmpty {
            predicates.append(NSPredicate(format: "%K IN %@", "function", Array(functions)))
        }

        // 文件名筛选
        if !fileNames.isEmpty {
            predicates.append(NSPredicate(format: "fileName IN %@", Array(fileNames)))
        }

        // Context 筛选
        if !contexts.isEmpty {
            predicates.append(NSPredicate(format: "context IN %@", Array(contexts)))
        }

        // 线程筛选
        if !threads.isEmpty {
            predicates.append(NSPredicate(format: "thread IN %@", Array(threads)))
        }

        // 会话筛选
        if !sessionIds.isEmpty {
            predicates.append(NSPredicate(format: "sessionId IN %@", Array(sessionIds)))
        }

        // 消息关键词筛选 (OR逻辑: 任一关键词匹配即可)
        if !messageKeywords.isEmpty {
            var messagePredicates: [NSPredicate] = []
            for keyword in messageKeywords {
                messagePredicates.append(NSPredicate(format: "message CONTAINS[cd] %@", keyword))
            }
            // 组合为 OR 关系
            let combinedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: messagePredicates)
            predicates.append(combinedPredicate)
        }

        return predicates
    }

    // MARK: - 查询方法

    /// 按日期查询日志事件
    public func fetchEvents(
        forDate date: String,
        levels: Set<LogEvent.Level> = [.verbose, .debug, .info, .warning, .error, .critical, .fault],
        sortDescriptors: [NSSortDescriptor] = [],
        limit: Int = 10000,
        offset: Int = 0
    ) throws -> [LogEvent] {
        let context = try getStack().viewContext
        let fetchRequest = LogEventEntity.fetchRequest()

        // 构建谓词
        var predicates: [NSPredicate] = []

        // 日期筛选
        predicates.append(NSPredicate(format: "date == %@", date))

        // 日志等级筛选
        if !levels.isEmpty {
            let levelValues = levels.map { Int16($0.rawValue) }
            predicates.append(NSPredicate(format: "level IN %@", levelValues))
        }

        // 组合谓词
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        // 排序
        if sortDescriptors.isEmpty {
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        } else {
            fetchRequest.sortDescriptors = sortDescriptors
        }

        // 分页
        fetchRequest.fetchLimit = limit
        fetchRequest.fetchOffset = offset

        // 执行查询
        let entities = try context.fetch(fetchRequest)
        return entities.map { $0.toLogEvent() }
    }

    /// 查询日志事件
    /// 支持后台context查询,用于线程安全的数据库操作
    /// - Parameter in: 可选的NSManagedObjectContext,如未提供则使用viewContext
    public func fetchEvents(
        in context: NSManagedObjectContext? = nil,
        levels: Set<LogEvent.Level>,
        functions: Set<String> = [],
        fileNames: Set<String> = [],
        contexts: Set<String> = [],
        threads: Set<String> = [],
        sessionIds: Set<String> = [],
        messageKeywords: Set<String> = [],
        sortDescriptors: [NSSortDescriptor] = [],
        limit: Int = 1000,
        offset: Int = 0
    ) throws -> [LogEvent] {

        let targetContext: NSManagedObjectContext
        if let ctx = context {
            targetContext = ctx
        } else {
            targetContext = try getStack().viewContext
        }
        let fetchRequest = LogEventEntity.fetchRequest()

        // 使用共用方法构建谓词
        let predicates = buildPredicates(
            levels: levels,
            functions: functions,
            fileNames: fileNames,
            contexts: contexts,
            threads: threads,
            sessionIds: sessionIds,
            messageKeywords: messageKeywords
        )

        // 组合谓词
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        // 排序
        if sortDescriptors.isEmpty {
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        } else {
            fetchRequest.sortDescriptors = sortDescriptors
        }

        // 分页
        fetchRequest.fetchLimit = limit
        fetchRequest.fetchOffset = offset

        // 执行查询
        let entities = try targetContext.fetch(fetchRequest)
        return entities.map { $0.toLogEvent() }
    }

    /// 查询日志事件用于搜索预览 (不应用过滤条件,仅用于全局搜索)
    /// - Parameters:
    ///   - context: 可选的NSManagedObjectContext
    ///   - sessionIds: 可选的会话ID集合筛选
    ///   - limit: 查询数量限制,默认3000条（优化后的默认值，平衡性能和覆盖范围）
    /// - Returns: 日志事件数组
    public func fetchAllEventsForSearchPreview(
        in context: NSManagedObjectContext? = nil,
        sessionIds: Set<String> = [],
        limit: Int = 3000
    ) throws -> [LogEvent] {
        let targetContext: NSManagedObjectContext
        if let ctx = context {
            targetContext = ctx
        } else {
            targetContext = try getStack().viewContext
        }
        let fetchRequest = LogEventEntity.fetchRequest()

        // 只应用会话筛选(如果有)
        if !sessionIds.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "sessionId IN %@", Array(sessionIds))
        }

        // 按时间倒序
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        // 限制数量避免内存问题
        fetchRequest.fetchLimit = limit

        // 执行查询
        let entities = try targetContext.fetch(fetchRequest)
        print("🔵 [LogDatabaseManager] fetchAllEventsForSearchPreview: sessionIds=\(sessionIds.isEmpty ? "all" : String(describing: sessionIds)), limit=\(limit), fetched=\(entities.count)")
        return entities.map { $0.toLogEvent() }
    }

    /// 统计信息
    /// 优化版本:使用2次查询代替原来的9次查询(1次总数 + 7次级别统计 + 1次热门函数)
    public func fetchStatistics() throws -> LogStatistics {
        let context = try getStack().viewContext

        // === 优化 1/2: 单次分组查询获取所有级别统计 ===
        let levelRequest = LogEventEntity.fetchRequest()
        levelRequest.resultType = .dictionaryResultType

        // 配置分组查询:按level分组,统计每个级别的数量
        let levelExpression = NSExpression(forKeyPath: "level")
        let countExpression = NSExpression(forFunction: "count:", arguments: [levelExpression])

        let countDescription = NSExpressionDescription()
        countDescription.name = "levelCount"
        countDescription.expression = countExpression
        countDescription.expressionResultType = .integer64AttributeType

        levelRequest.propertiesToGroupBy = ["level"]
        levelRequest.propertiesToFetch = ["level", countDescription]

        // 执行分组查询
        let levelResults = try context.fetch(levelRequest) as! [NSDictionary]

        // 解析结果:构建levelCounts字典并计算总数
        var levelCounts: [Int: Int] = [:]
        var totalCount = 0

        for dict in levelResults {
            guard let level = dict["level"] as? Int16,
                  let count = dict["levelCount"] as? Int else { continue }

            let levelInt = Int(level)
            levelCounts[levelInt] = count
            totalCount += count
        }

        // === 优化 2/2: 热门函数查询(保持原有实现) ===
        let functionRequest = LogEventEntity.fetchRequest()
        functionRequest.resultType = .dictionaryResultType

        let functionExpression = NSExpression(forKeyPath: "function")
        let functionCountExpression = NSExpression(forFunction: "count:", arguments: [functionExpression])

        let functionCountDescription = NSExpressionDescription()
        functionCountDescription.name = "count"
        functionCountDescription.expression = functionCountExpression
        functionCountDescription.expressionResultType = .integer64AttributeType

        functionRequest.propertiesToGroupBy = ["function"]
        functionRequest.propertiesToFetch = ["function", functionCountDescription]
        functionRequest.sortDescriptors = [NSSortDescriptor(key: "count", ascending: false)]
        functionRequest.fetchLimit = 100

        // 过滤掉function为空的情况 - 只在数据库层过滤nil，空字符串在应用层过滤
//        functionRequest.predicate = NSPredicate(format: "function != nil")

        let functionResults = try context.fetch(functionRequest) as! [NSDictionary]
        let topFunctions = functionResults.compactMap { dict -> (String, Int)? in
            guard let function = dict["function"] as? String,
                  !function.isEmpty,  // 在应用层过滤空字符串
                  let count = dict["count"] as? Int else { return nil }
            return (function, count)
        }

        return LogStatistics(
            totalCount: totalCount,
            levelCounts: levelCounts,
            topFunctions: topFunctions
        )
    }

    /// 统计符合条件的日志总数
    public func countEvents(
        in context: NSManagedObjectContext? = nil,
        levels: Set<LogEvent.Level>,
        functions: Set<String> = [],
        fileNames: Set<String> = [],
        contexts: Set<String> = [],
        threads: Set<String> = [],
        sessionIds: Set<String> = [],
        messageKeywords: Set<String> = []
    ) throws -> Int {
        let targetContext: NSManagedObjectContext
        if let ctx = context {
            targetContext = ctx
        } else {
            targetContext = try getStack().viewContext
        }
        let fetchRequest = LogEventEntity.fetchRequest()

        // 使用共用方法构建谓词
        let predicates = buildPredicates(
            levels: levels,
            functions: functions,
            fileNames: fileNames,
            contexts: contexts,
            threads: threads,
            sessionIds: sessionIds,
            messageKeywords: messageKeywords
        )

        // 组合谓词
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        // 执行 COUNT 查询
        return try targetContext.count(for: fetchRequest)
    }

    /// 获取唯一值列表
    public func fetchUniqueValues(for keyPath: String) throws -> [String] {
        let context = try getStack().viewContext
        let fetchRequest = LogEventEntity.fetchRequest()

        fetchRequest.propertiesToFetch = [keyPath]
        fetchRequest.returnsDistinctResults = true
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: keyPath, ascending: true)]

        let results = try context.fetch(fetchRequest) as! [NSDictionary]
        return results.compactMap { $0[keyPath] as? String }.filter { !$0.isEmpty }
    }

    /// 获取所有唯一的日期列表（按日期倒序排列）
    public func fetchUniqueDates() throws -> [String] {
        let context = try getStack().viewContext
        let fetchRequest = LogEventEntity.fetchRequest()

        fetchRequest.propertiesToFetch = ["date"]
        fetchRequest.returnsDistinctResults = true
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        let results = try context.fetch(fetchRequest) as! [NSDictionary]
        return results.compactMap { $0["date"] as? String }.filter { !$0.isEmpty }
    }

    /// 获取所有会话列表（按启动时间倒序排列）
    public func fetchAllSessions() throws -> [SessionInfo] {
        let context = try getStack().viewContext
        let fetchRequest = LogEventEntity.fetchRequest()

        // 配置 GROUP BY 查询
        fetchRequest.propertiesToGroupBy = ["sessionId"]
        fetchRequest.returnsDistinctResults = true
        fetchRequest.resultType = .dictionaryResultType

        // 添加 MAX(sessionStartTime) 表达式获取会话启动时间
        let startTimeExpression = NSExpression(forFunction: "max:", arguments: [NSExpression(forKeyPath: "sessionStartTime")])
        let startTimeDescription = NSExpressionDescription()
        startTimeDescription.name = "sessionStartTime"
        startTimeDescription.expression = startTimeExpression
        startTimeDescription.expressionResultType = .doubleAttributeType

        // 添加 COUNT 表达式统计日志数量
        let countExpression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "sessionId")])
        let countDescription = NSExpressionDescription()
        countDescription.name = "logCount"
        countDescription.expression = countExpression
        countDescription.expressionResultType = .integer64AttributeType

        fetchRequest.propertiesToFetch = ["sessionId", startTimeDescription, countDescription]
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sessionStartTime", ascending: false)]

        let results = try context.fetch(fetchRequest) as! [NSDictionary]

        return results.compactMap { dict -> SessionInfo? in
            guard let sessionId = dict["sessionId"] as? String,
                  let sessionStartTime = dict["sessionStartTime"] as? Double,
                  let logCount = dict["logCount"] as? Int else {
                return nil
            }
            return SessionInfo(id: sessionId, startTime: sessionStartTime, logCount: logCount)
        }
    }

    // MARK: - 筛选选项查询方法

    /// 获取所有可用的函数名
    public func fetchAvailableFunctions() throws -> [String] {
        return try fetchUniqueValues(for: "function")
    }

    /// 获取所有可用的文件名
    public func fetchAvailableFileNames() throws -> [String] {
        return try fetchUniqueValues(for: "fileName")
    }

    /// 获取所有可用的上下文
    public func fetchAvailableContexts() throws -> [String] {
        return try fetchUniqueValues(for: "context")
    }

    /// 获取所有可用的线程名
    public func fetchAvailableThreads() throws -> [String] {
        return try fetchUniqueValues(for: "thread")
    }

    /// 查询指定日期的日志数量
    public func fetchEventCount(for date: String) throws -> Int {
        let context = try getStack().viewContext
        let fetchRequest = LogEventEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", date)
        return try context.count(for: fetchRequest)
    }

    /// 删除指定日期的日志
    public func deleteLogs(forDate date: String) async throws {
        let stack = try getStack()

        try await performBackgroundOperation { context in
            let fetchRequest = LogEventEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "date == %@", date)

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
            deleteRequest.resultType = .resultTypeObjectIDs

            let result = try context.execute(deleteRequest) as! NSBatchDeleteResult
            let objectIDs = result.result as! [NSManagedObjectID]

            // 合并更改到主上下文
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                into: [stack.viewContext]
            )

            print("✅ Deleted \(objectIDs.count) logs for date \(date)")
        }
    }

    /// 删除指定日期之前的日志
    public func deleteLogs(before date: Date) async throws {
        let stack = try getStack()

        try await performBackgroundOperation { context in
            let fetchRequest = LogEventEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "timestamp < %f",
                date.timeIntervalSince1970
            )

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
            deleteRequest.resultType = .resultTypeObjectIDs

            let result = try context.execute(deleteRequest) as! NSBatchDeleteResult
            let objectIDs = result.result as! [NSManagedObjectID]

            // 合并更改到主上下文
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                into: [stack.viewContext]
            )

            print("✅ Deleted \(objectIDs.count) logs before \(date)")
        }
    }

    /// 删除所有日志
    public func deleteAllLogs() async throws {
        let stack = try getStack()

        try await performBackgroundOperation { context in
            let fetchRequest = LogEventEntity.fetchRequest()

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
            deleteRequest.resultType = .resultTypeObjectIDs

            let result = try context.execute(deleteRequest) as! NSBatchDeleteResult
            let objectIDs = result.result as! [NSManagedObjectID]

            // 合并更改到主上下文
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                into: [stack.viewContext]
            )

            print("✅ Deleted all \(objectIDs.count) logs")
        }
    }

    /// 删除指定会话的所有日志
    public func deleteLogs(forSession sessionId: String) async throws {
        let stack = try getStack()

        try await performBackgroundOperation { context in
            let fetchRequest = LogEventEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "sessionId == %@", sessionId)

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
            deleteRequest.resultType = .resultTypeObjectIDs

            let result = try context.execute(deleteRequest) as! NSBatchDeleteResult
            let objectIDs = result.result as! [NSManagedObjectID]

            // 合并更改到主上下文
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                into: [stack.viewContext]
            )

            print("✅ Deleted \(objectIDs.count) logs for session \(sessionId)")
        }
    }

    /// 删除多个会话的日志
    public func deleteLogs(forSessions sessionIds: Set<String>) async throws {
        guard !sessionIds.isEmpty else { return }

        let stack = try getStack()

        try await performBackgroundOperation { context in
            let fetchRequest = LogEventEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "sessionId IN %@", Array(sessionIds))

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
            deleteRequest.resultType = .resultTypeObjectIDs

            let result = try context.execute(deleteRequest) as! NSBatchDeleteResult
            let objectIDs = result.result as! [NSManagedObjectID]

            // 合并更改到主上下文
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                into: [stack.viewContext]
            )

            print("✅ Deleted \(objectIDs.count) logs for \(sessionIds.count) sessions")
        }
    }

    /// 数据库大小
    public func databaseSize() -> Int64 {
        guard let stack = coreDataStack,
              let storeURL = stack.persistentContainer.persistentStoreCoordinator.persistentStores.first?.url else {
            return 0
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: storeURL.path) else {
            return 0
        }

        return attributes[FileAttributeKey.size] as? Int64 ?? 0
    }

    // MARK: - Deep Search Support

    /// 排序顺序
    public enum SessionSortOrder {
        case timeAscending
        case timeDescending
    }

    /// 获取指定的 sessions（按时间排序）
    /// - Parameters:
    ///   - context: 可选的 NSManagedObjectContext
    ///   - sessionIds: 要获取的 session IDs（如果为空，返回所有）
    ///   - sortOrder: 排序顺序
    /// - Returns: SessionInfo 数组
    public func getSessions(
        in context: NSManagedObjectContext? = nil,
        sessionIds: Set<String>,
        sortOrder: SessionSortOrder = .timeDescending
    ) throws -> [SessionInfo] {
        let targetContext: NSManagedObjectContext
        if let ctx = context {
            targetContext = ctx
        } else {
            targetContext = try getStack().viewContext
        }
        let fetchRequest = LogEventEntity.fetchRequest()

        // 配置 GROUP BY 查询
        fetchRequest.propertiesToGroupBy = ["sessionId"]
        fetchRequest.returnsDistinctResults = true
        fetchRequest.resultType = .dictionaryResultType

        // Session 过滤
        if !sessionIds.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "sessionId IN %@", Array(sessionIds))
        }

        // 添加 MAX(sessionStartTime) 表达式
        let startTimeExpression = NSExpression(forFunction: "max:", arguments: [NSExpression(forKeyPath: "sessionStartTime")])
        let startTimeDescription = NSExpressionDescription()
        startTimeDescription.name = "sessionStartTime"
        startTimeDescription.expression = startTimeExpression
        startTimeDescription.expressionResultType = .doubleAttributeType

        // 添加 COUNT 表达式
        let countExpression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "sessionId")])
        let countDescription = NSExpressionDescription()
        countDescription.name = "logCount"
        countDescription.expression = countExpression
        countDescription.expressionResultType = .integer64AttributeType

        fetchRequest.propertiesToFetch = ["sessionId", startTimeDescription, countDescription]

        // 排序
        let ascending = sortOrder == .timeAscending
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sessionStartTime", ascending: ascending)]

        let results = try targetContext.fetch(fetchRequest) as! [NSDictionary]

        return results.compactMap { dict -> SessionInfo? in
            guard let sessionId = dict["sessionId"] as? String,
                  let sessionStartTime = dict["sessionStartTime"] as? Double,
                  let logCount = dict["logCount"] as? Int else {
                return nil
            }
            return SessionInfo(id: sessionId, startTime: sessionStartTime, logCount: logCount)
        }
    }

    /// 在数据库层搜索日志事件
    /// - Parameters:
    ///   - context: 可选的 NSManagedObjectContext
    ///   - sessionIds: 要搜索的 session IDs
    ///   - searchText: 搜索关键词
    ///   - searchFields: 搜索字段（message, fileName, function, context, thread）
    ///   - limit: 结果数量限制
    /// - Returns: 匹配的 LogEvent 数组（按时间倒序）
    public func searchEvents(
        in context: NSManagedObjectContext? = nil,
        sessionIds: Set<String>,
        searchText: String,
        searchFields: [String],
        limit: Int
    ) throws -> [LogEvent] {
        let targetContext: NSManagedObjectContext
        if let ctx = context {
            targetContext = ctx
        } else {
            targetContext = try getStack().viewContext
        }
        let fetchRequest = LogEventEntity.fetchRequest()

        var predicates: [NSPredicate] = []

        // Session 过滤
        if !sessionIds.isEmpty {
            predicates.append(NSPredicate(format: "sessionId IN %@", Array(sessionIds)))
        }

        // 搜索字段过滤（OR 逻辑）
        if !searchFields.isEmpty {
            var searchPredicates: [NSPredicate] = []
            for field in searchFields {
                searchPredicates.append(NSPredicate(format: "%K CONTAINS[cd] %@", field, searchText))
            }
            let combinedSearchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: searchPredicates)
            predicates.append(combinedSearchPredicate)
        }

        // 组合所有谓词（AND 逻辑）
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        // 按时间倒序排序
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        // 限制结果数量
        fetchRequest.fetchLimit = limit

        // 执行查询
        let entities = try targetContext.fetch(fetchRequest)
        return entities.map { $0.toLogEvent() }
    }
}
