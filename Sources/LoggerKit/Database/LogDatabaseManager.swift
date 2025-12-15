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

    private let coreDataStack: CoreDataStack

    public init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
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
        let context = coreDataStack.viewContext
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
        sessionId: String? = nil,
        searchText: String = "",
        messageKeywords: Set<String> = [],
        sortDescriptors: [NSSortDescriptor] = [],
        limit: Int = 1000,
        offset: Int = 0
    ) throws -> [LogEvent] {

        let targetContext = context ?? coreDataStack.viewContext
        let fetchRequest = LogEventEntity.fetchRequest()

        // 构建谓词
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
        if let sessionId = sessionId {
            predicates.append(NSPredicate(format: "sessionId == %@", sessionId))
        }

        // 搜索文本 (在 message, function, fileName 中搜索)
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(
                format: "message CONTAINS[cd] %@ OR %K CONTAINS[cd] %@ OR fileName CONTAINS[cd] %@",
                searchText, "function", searchText, searchText
            )
            predicates.append(searchPredicate)
        }

        // 消息关键词筛选 (OR逻辑: 任意一个关键词匹配即可)
        if !messageKeywords.isEmpty {
            let keywordPredicates = messageKeywords.map { keyword in
                NSPredicate(format: "message CONTAINS[cd] %@", keyword)
            }
            let orPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: keywordPredicates)
            predicates.append(orPredicate)
        }

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

    /// 统计信息
    /// 优化版本:使用2次查询代替原来的9次查询(1次总数 + 7次级别统计 + 1次热门函数)
    public func fetchStatistics() throws -> LogStatistics {
        let context = coreDataStack.viewContext

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

        // 过滤掉function为空的情况
        functionRequest.predicate = NSPredicate(format: "function != nil AND function != ''")

        let functionResults = try context.fetch(functionRequest) as! [NSDictionary]
        let topFunctions = functionResults.compactMap { dict -> (String, Int)? in
            guard let function = dict["function"] as? String,
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
        sessionId: String? = nil,
        searchText: String = "",
        messageKeywords: Set<String> = []
    ) throws -> Int {
        let targetContext = context ?? coreDataStack.viewContext
        let fetchRequest = LogEventEntity.fetchRequest()

        // 构建谓词(复用 fetchEvents 的逻辑)
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
        if let sessionId = sessionId {
            predicates.append(NSPredicate(format: "sessionId == %@", sessionId))
        }

        // 搜索文本
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(
                format: "message CONTAINS[cd] %@ OR %K CONTAINS[cd] %@ OR fileName CONTAINS[cd] %@",
                searchText, "function", searchText, searchText
            )
            predicates.append(searchPredicate)
        }

        // 消息关键词筛选
        if !messageKeywords.isEmpty {
            let keywordPredicates = messageKeywords.map { keyword in
                NSPredicate(format: "message CONTAINS[cd] %@", keyword)
            }
            let orPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: keywordPredicates)
            predicates.append(orPredicate)
        }

        // 组合谓词
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        // 执行 COUNT 查询
        return try targetContext.count(for: fetchRequest)
    }

    /// 获取唯一值列表
    public func fetchUniqueValues(for keyPath: String) throws -> [String] {
        let context = coreDataStack.viewContext
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
        let context = coreDataStack.viewContext
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
        let context = coreDataStack.viewContext
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

    /// 查询指定日期的日志数量
    public func fetchEventCount(for date: String) throws -> Int {
        let context = coreDataStack.viewContext
        let fetchRequest = LogEventEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", date)
        return try context.count(for: fetchRequest)
    }

    /// 删除指定日期的日志
    public func deleteLogs(forDate date: String) throws {
        let context = coreDataStack.newBackgroundContext()

        context.performAndWait {
            let fetchRequest = LogEventEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "date == %@", date)

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
            deleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(deleteRequest) as! NSBatchDeleteResult
                let objectIDs = result.result as! [NSManagedObjectID]

                // 合并更改到主上下文
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [coreDataStack.viewContext]
                )

                print("✅ Deleted \(objectIDs.count) logs for date \(date)")
            } catch {
                print("❌ Failed to delete logs: \(error)")
            }
        }
    }

    /// 删除指定日期之前的日志
    public func deleteLogs(before date: Date) throws {
        let context = coreDataStack.newBackgroundContext()

        context.performAndWait {
            let fetchRequest = LogEventEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "timestamp < %f",
                date.timeIntervalSince1970
            )

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
            deleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(deleteRequest) as! NSBatchDeleteResult
                let objectIDs = result.result as! [NSManagedObjectID]

                // 合并更改到主上下文
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [coreDataStack.viewContext]
                )

                print("✅ Deleted \(objectIDs.count) logs before \(date)")
            } catch {
                print("❌ Failed to delete logs: \(error)")
            }
        }
    }

    /// 删除所有日志
    public func deleteAllLogs() throws {
        let context = coreDataStack.newBackgroundContext()

        context.performAndWait {
            let fetchRequest = LogEventEntity.fetchRequest()

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
            deleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(deleteRequest) as! NSBatchDeleteResult
                let objectIDs = result.result as! [NSManagedObjectID]

                // 合并更改到主上下文
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [coreDataStack.viewContext]
                )

                print("✅ Deleted all \(objectIDs.count) logs")
            } catch {
                print("❌ Failed to delete all logs: \(error)")
            }
        }
    }

    /// 数据库大小
    public func databaseSize() -> Int64 {
        guard let storeURL = coreDataStack.persistentContainer.persistentStoreCoordinator.persistentStores.first?.url else {
            return 0
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: storeURL.path) else {
            return 0
        }

        return attributes[.size] as? Int64 ?? 0
    }
}
