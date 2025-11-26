//
//  LogDatabaseManager.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025/11/25.
//

import CoreData
import Combine

/// 日志统计信息
public struct LogStatistics {
    public let totalCount: Int
    public let levelCounts: [Int: Int]
    public let topFunctions: [(String, Int)]
}

public final class LogDatabaseManager {

    private let coreDataStack: CoreDataStack

    public init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
    }

    // MARK: - 查询方法

    /// 查询日志事件
    public func fetchEvents(
        levels: Set<LogEvent.Level>,
        functions: Set<String> = [],
        fileNames: Set<String> = [],
        contexts: Set<String> = [],
        threads: Set<String> = [],
        searchText: String = "",
        sortDescriptors: [NSSortDescriptor] = [],
        limit: Int = 1000,
        offset: Int = 0
    ) throws -> [LogEvent] {

        let context = coreDataStack.viewContext
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
            predicates.append(NSPredicate(format: "function IN %@", Array(functions)))
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

        // 搜索文本 (在 message, function, fileName 中搜索)
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(
                format: "message CONTAINS[cd] %@ OR function CONTAINS[cd] %@ OR fileName CONTAINS[cd] %@",
                searchText, searchText, searchText
            )
            predicates.append(searchPredicate)
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
        let entities = try context.fetch(fetchRequest)
        return entities.map { $0.toLogEvent() }
    }

    /// 统计信息
    public func fetchStatistics() throws -> LogStatistics {
        let context = coreDataStack.viewContext

        // 总数
        let countRequest = LogEventEntity.fetchRequest()
        let totalCount = try context.count(for: countRequest)

        // 按等级统计
        var levelCounts: [Int: Int] = [:]
        for level in 0...6 {
            let request = LogEventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "level == %d", level)
            let count = try context.count(for: request)
            levelCounts[level] = count
        }

        // 热门函数 (Top 100)
        let functionRequest = LogEventEntity.fetchRequest()
        functionRequest.propertiesToFetch = ["function"]
        functionRequest.resultType = .dictionaryResultType

        let functionExpression = NSExpression(forKeyPath: "function")
        let countExpression = NSExpression(forFunction: "count:", arguments: [functionExpression])

        let countDescription = NSExpressionDescription()
        countDescription.name = "count"
        countDescription.expression = countExpression
        countDescription.expressionResultType = .integer64AttributeType

        functionRequest.propertiesToGroupBy = ["function"]
        functionRequest.propertiesToFetch = ["function", countDescription]
        functionRequest.sortDescriptors = [NSSortDescriptor(key: "count", ascending: false)]
        functionRequest.fetchLimit = 100

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
