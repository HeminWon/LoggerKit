# LoggerKit 迁移到 CoreData 存储方案

## 📋 方案概述

将 LoggerKit 从文件存储迁移到 **CoreData** 数据库存储，解决 > 100MB 大日志文件的内存暴涨和 OOM 问题。

**目标:**
- 降低内存占用 90% (500MB → 50MB)
- 提升加载速度 10x
- 增强搜索和筛选功能
- 支持自动轮转和清理

---

## 🎯 为什么选择 CoreData

### 优点
- ✅ Apple 原生框架，无需第三方依赖
- ✅ 与 SwiftUI 深度集成 (`@FetchRequest`)
- ✅ 自动内存管理和对象生命周期
- ✅ 支持数据迁移和版本管理
- ✅ 支持 NSPredicate 复杂查询
- ✅ 支持批量操作优化性能

### 适用场景
- 日志文件 > 100MB
- 需要复杂筛选和搜索
- 需要统计分析功能
- 希望使用 Apple 官方技术栈

---

## 📊 CoreData 模型设计

### 实体定义: LogEventEntity

| 属性名 | 类型 | 索引 | 可选 | 说明 |
|--------|------|------|------|------|
| id | UUID | ✅ | ❌ | 唯一标识符 |
| timestamp | Double | ✅ | ❌ | 时间戳 |
| level | Int16 | ✅ | ❌ | 日志等级 (0-6) |
| message | String | ❌ | ❌ | 日志消息 |
| thread | String | ✅ | ❌ | 线程名称 |
| function | String | ✅ | ❌ | 函数名 |
| fileName | String | ✅ | ❌ | 文件名 (从 file 提取) |
| file | String | ❌ | ❌ | 完整文件路径 |
| line | Int32 | ❌ | ❌ | 代码行号 |
| context | String | ✅ | ❌ | 上下文/模块 |
| date | String | ✅ | ❌ | 日期字符串 (YYYY-MM-DD) |
| hour | Int16 | ✅ | ❌ | 小时 (0-23) |

### 索引策略

```swift
// 复合索引 (在 .xcdatamodeld 中配置)
1. timestamp (降序) - 用于时间排序
2. level - 用于等级筛选
3. date + hour - 用于时间范围查询
4. fileName - 用于文件筛选
5. function - 用于函数筛选
6. context - 用于模块筛选
7. thread - 用于线程筛选
```

---

## 🏗️ 架构设计

### 1. CoreData Stack

```swift
// Database/CoreDataStack.swift
import CoreData

public final class CoreDataStack {

    public static let shared = CoreDataStack()

    private init() {}

    // MARK: - Core Data Stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "LoggerKit")

        // 配置存储路径
        let storeURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("LoggerKit")
            .appendingPathComponent("logs.sqlite")

        // 确保目录存在
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let description = NSPersistentStoreDescription(url: storeURL)

        // 性能优化配置
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.setOption(FileProtectionType.complete as NSObject,
                             forKey: NSPersistentStoreFileProtectionKey)

        // 启用 WAL 模式 (Write-Ahead Logging)
        description.setOption("WAL" as NSObject,
                             forKey: NSSQLitePragmasOption as String)

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            print("✅ CoreData store loaded: \(storeDescription.url?.path ?? "")")
        }

        // 配置视图上下文
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    // 主线程上下文 (用于 UI)
    public var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    // 后台上下文 (用于批量写入)
    public func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }

    // MARK: - Save Context

    public func saveContext(context: NSManagedObjectContext? = nil) {
        let targetContext = context ?? viewContext

        guard targetContext.hasChanges else { return }

        do {
            try targetContext.save()
        } catch {
            let nserror = error as NSError
            print("❌ CoreData save error: \(nserror), \(nserror.userInfo)")
        }
    }
}
```

### 2. LogEventEntity (NSManagedObject 子类)

```swift
// Database/LogEventEntity+CoreDataClass.swift
import CoreData
import Foundation

@objc(LogEventEntity)
public class LogEventEntity: NSManagedObject {

    // 从 LogEvent 创建
    static func create(from event: LogEvent, in context: NSManagedObjectContext) -> LogEventEntity {
        let entity = LogEventEntity(context: context)
        entity.id = UUID()
        entity.timestamp = event.timestamp
        entity.level = Int16(event.level.rawValue)
        entity.message = event.message
        entity.thread = event.thread
        entity.function = event.function
        entity.file = event.file
        entity.line = Int32(event.line)
        entity.context = event.context

        // 提取文件名
        entity.fileName = event.fileName

        // 提取日期和小时
        let date = Date(timeIntervalSince1970: event.timestamp)
        entity.date = DateFormatters.dateOnlyFormatter.string(from: date)
        entity.hour = Int16(Calendar.current.component(.hour, from: date))

        return entity
    }

    // 转换为 LogEvent
    func toLogEvent() -> LogEvent {
        return LogEvent(
            thread: thread ?? "",
            function: function ?? "",
            line: Int(line),
            file: file ?? "",
            timestamp: timestamp,
            level: LogEvent.Level(rawValue: Int(level)) ?? .debug,
            message: message ?? "",
            context: context ?? ""
        )
    }
}
```

```swift
// Database/LogEventEntity+CoreDataProperties.swift
import CoreData
import Foundation

extension LogEventEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LogEventEntity> {
        return NSFetchRequest<LogEventEntity>(entityName: "LogEventEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Double
    @NSManaged public var level: Int16
    @NSManaged public var message: String?
    @NSManaged public var thread: String?
    @NSManaged public var function: String?
    @NSManaged public var file: String?
    @NSManaged public var fileName: String?
    @NSManaged public var line: Int32
    @NSManaged public var context: String?
    @NSManaged public var date: String?
    @NSManaged public var hour: Int16
}

extension LogEventEntity: Identifiable {}
```

### 3. SwiftyBeaver CoreData Destination

```swift
// Database/CoreDataDestination.swift
import Foundation
import SwiftyBeaver
import CoreData

/// CoreData 日志输出目标
public final class CoreDataDestination: BaseDestination {

    private let coreDataStack: CoreDataStack
    private let batchSize: Int
    private var pendingEvents: [LogEvent] = []
    private let queue = DispatchQueue(label: "com.loggerkit.coredata", qos: .utility)
    private var flushTimer: Timer?

    public init(coreDataStack: CoreDataStack = .shared, batchSize: Int = 50) {
        self.coreDataStack = coreDataStack
        self.batchSize = batchSize

        super.init()

        // 设置格式 (不需要格式化，直接存储结构化数据)
        self.format = ""

        // 启动定时刷新 (每 5 秒刷新一次)
        setupFlushTimer()
    }

    private func setupFlushTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.flushTimer = Timer.scheduledTimer(
                withTimeInterval: 5.0,
                repeats: true
            ) { [weak self] _ in
                self?.flush()
            }
        }
    }

    override public func send(
        _ level: SwiftyBeaver.Level,
        msg: String,
        thread: String,
        file: String,
        function: String,
        line: Int,
        context: Any? = nil
    ) -> String? {
        // 构造日志事件
        let logEvent = LogEvent(
            thread: thread,
            function: function,
            line: line,
            file: file,
            timestamp: Date().timeIntervalSince1970,
            level: mapLevel(level),
            message: msg,
            context: (context as? String) ?? ""
        )

        // 添加到待写入队列
        queue.async { [weak self] in
            self?.addEvent(logEvent)
        }

        return nil
    }

    private func addEvent(_ event: LogEvent) {
        pendingEvents.append(event)

        // 达到批量大小时立即写入
        if pendingEvents.count >= batchSize {
            flushPendingEvents()
        }
    }

    public func flush() {
        queue.async { [weak self] in
            self?.flushPendingEvents()
        }
    }

    private func flushPendingEvents() {
        guard !pendingEvents.isEmpty else { return }

        let eventsToWrite = pendingEvents
        pendingEvents.removeAll(keepingCapacity: true)

        // 后台上下文批量写入
        let context = coreDataStack.newBackgroundContext()

        context.perform {
            for event in eventsToWrite {
                _ = LogEventEntity.create(from: event, in: context)
            }

            do {
                try context.save()
            } catch {
                print("❌ CoreDataDestination: Failed to save logs: \(error)")
            }
        }
    }

    private func mapLevel(_ level: SwiftyBeaver.Level) -> LogEvent.Level {
        switch level {
        case .verbose: return .verbose
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }

    deinit {
        flushTimer?.invalidate()
        flush()
    }
}
```

### 4. CoreData 查询管理器

```swift
// Database/LogDatabaseManager.swift
import CoreData
import Combine

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

/// 日志统计信息
public struct LogStatistics {
    public let totalCount: Int
    public let levelCounts: [Int: Int]
    public let topFunctions: [(String, Int)]
}
```

### 5. 数据库轮转管理器

```swift
// Database/LogDatabaseRotationManager.swift
import Foundation
import CoreData

public final class LogDatabaseRotationManager {

    private let databaseManager: LogDatabaseManager
    private let maxDatabaseSize: Int64
    private let maxRetentionDays: Int

    public init(
        databaseManager: LogDatabaseManager,
        maxDatabaseSize: Int64 = 100 * 1024 * 1024, // 100MB
        maxRetentionDays: Int = 30
    ) {
        self.databaseManager = databaseManager
        self.maxDatabaseSize = maxDatabaseSize
        self.maxRetentionDays = maxRetentionDays
    }

    /// 执行轮转检查
    public func performRotationIfNeeded() {
        let currentSize = databaseManager.databaseSize()

        if currentSize > maxDatabaseSize {
            // 删除旧数据
            let cutoffDate = Calendar.current.date(
                byAdding: .day,
                value: -maxRetentionDays,
                to: Date()
            )!

            do {
                try databaseManager.deleteLogs(before: cutoffDate)
                print("✅ Database rotation completed. Size: \(currentSize / 1024)KB -> \(databaseManager.databaseSize() / 1024)KB")
            } catch {
                print("❌ Database rotation failed: \(error)")
            }
        }
    }

    /// 清理过期日志
    public func cleanupExpiredLogs() {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -maxRetentionDays,
            to: Date()
        )!

        do {
            try databaseManager.deleteLogs(before: cutoffDate)
            print("✅ Expired logs cleaned up (before \(cutoffDate))")
        } catch {
            print("❌ Cleanup failed: \(error)")
        }
    }
}
```

---

## 🔧 集成到现有代码

### 1. 修改 LoggerEngine

```swift
// Core/LoggerEngine.swift

// 添加属性
private var coreDataDestination: CoreDataDestination?
private var databaseManager: LogDatabaseManager?
private var rotationManager: LogDatabaseRotationManager?

// 修改 setupDestinations 方法
private func setupDestinations(_ configuration: LoggerEngineConfiguration) {
    // ... 现有的控制台配置 ...

    // 配置 CoreData 输出
    guard configuration.enableFile else { return }

    let coreDataDest = CoreDataDestination()
    coreDataDest.minLevel = configuration.level.swiftyBeaverLevel
    swiftyBeaver.addDestination(coreDataDest)

    self.coreDataDestination = coreDataDest

    // 创建数据库管理器
    let dbManager = LogDatabaseManager()
    self.databaseManager = dbManager

    // 创建轮转管理器
    self.rotationManager = LogDatabaseRotationManager(
        databaseManager: dbManager,
        maxDatabaseSize: 100 * 1024 * 1024,
        maxRetentionDays: 30
    )

    // 启动时执行一次清理
    rotationManager?.performRotationIfNeeded()
}

// 添加公共方法
public func getDatabaseManager() -> LogDatabaseManager? {
    return databaseManager
}

public func performDatabaseRotation() {
    rotationManager?.performRotationIfNeeded()
}

public func cleanupExpiredLogs() {
    rotationManager?.cleanupExpiredLogs()
}
```

### 2. 修改 LogDetailSceneState

```swift
// UI/LogDetailSceneState.swift

@MainActor
public class LogDetailSceneState: ObservableObject {

    @Published var displayEvents: [LogEvent] = []
    @Published var isLoading: Bool = false
    @Published var loadingProgress: String = ""
    @Published var error: Error?

    // 筛选状态
    @Published var selectedLevels: Set<LogEvent.Level> = [.verbose, .debug, .info, .warning, .error]
    @Published var searchText: String = ""
    @Published var selectedFunctions: Set<String> = []
    @Published var selectedFileNames: Set<String> = []
    @Published var selectedContexts: Set<String> = []
    @Published var selectedThreads: Set<String> = []

    // 分页
    private var currentPage = 0
    private let pageSize = 500

    // 数据库管理器
    private let databaseManager: LogDatabaseManager

    // 统计信息
    @Published var statistics: LogStatistics?

    public init(databaseManager: LogDatabaseManager) {
        self.databaseManager = databaseManager
    }

    /// 加载日志数据
    func loadLogs(resetPagination: Bool = true) async {
        if resetPagination {
            currentPage = 0
        }

        isLoading = true
        loadingProgress = "正在查询..."
        defer {
            isLoading = false
            loadingProgress = ""
        }

        do {
            let events = try await Task.detached { [weak self] in
                guard let self = self else { return [] }

                return try self.databaseManager.fetchEvents(
                    levels: self.selectedLevels,
                    functions: self.selectedFunctions,
                    fileNames: self.selectedFileNames,
                    contexts: self.selectedContexts,
                    threads: self.selectedThreads,
                    searchText: self.searchText,
                    limit: self.pageSize,
                    offset: self.currentPage * self.pageSize
                )
            }.value

            if resetPagination {
                self.displayEvents = events
            } else {
                self.displayEvents.append(contentsOf: events)
            }

            currentPage += 1
        } catch {
            self.error = error
            print("❌ Failed to load logs: \(error)")
        }
    }

    /// 加载更多
    func loadMore() async {
        await loadLogs(resetPagination: false)
    }

    /// 加载统计信息
    func loadStatistics() async {
        do {
            let stats = try await Task.detached { [weak self] in
                try self?.databaseManager.fetchStatistics()
            }.value

            self.statistics = stats
        } catch {
            print("❌ Failed to load statistics: \(error)")
        }
    }

    /// 重新查询
    func refresh() {
        Task {
            await loadLogs(resetPagination: true)
        }
    }

    /// 获取筛选选项
    func loadFilterOptions() async {
        do {
            let functions = try await Task.detached { [weak self] in
                try self?.databaseManager.fetchUniqueValues(for: "function") ?? []
            }.value

            let fileNames = try await Task.detached { [weak self] in
                try self?.databaseManager.fetchUniqueValues(for: "fileName") ?? []
            }.value

            let contexts = try await Task.detached { [weak self] in
                try self?.databaseManager.fetchUniqueValues(for: "context") ?? []
            }.value

            let threads = try await Task.detached { [weak self] in
                try self?.databaseManager.fetchUniqueValues(for: "thread") ?? []
            }.value

            // 更新可用选项
            // (可以保存到 @Published 属性中供 UI 使用)

        } catch {
            print("❌ Failed to load filter options: \(error)")
        }
    }
}
```

### 3. 添加 DateFormatters

```swift
// Utilities/DateFormatters.swift (添加)

public static let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    return formatter
}()
```

---

## 📁 文件结构

```
LoggerKit/
├── Sources/LoggerKit/
│   ├── Database/                          (新增)
│   │   ├── CoreDataStack.swift           (新增)
│   │   ├── LogEventEntity+CoreDataClass.swift (新增)
│   │   ├── LogEventEntity+CoreDataProperties.swift (新增)
│   │   ├── CoreDataDestination.swift     (新增)
│   │   ├── LogDatabaseManager.swift      (新增)
│   │   └── LogDatabaseRotationManager.swift (新增)
│   ├── Resources/                         (新增)
│   │   └── LoggerKit.xcdatamodeld/       (新增 - CoreData 模型文件)
│   │       └── LoggerKit.xcdatamodel/
│   │           └── contents
│   ├── Core/
│   │   └── LoggerEngine.swift            (修改)
│   ├── UI/
│   │   ├── LogDetailSceneState.swift     (修改)
│   │   └── LogDetailScene.swift          (修改)
│   └── Utilities/
│       └── DateFormatters.swift          (修改)
└── Package.swift                          (无需修改)
```

---

## 🚀 实施步骤

### 阶段 1: 创建 CoreData 模型

1. **创建 `.xcdatamodeld` 文件**
   - 在 Xcode 中: File → New → File → Data Model
   - 命名为 `LoggerKit.xcdatamodeld`
   - 位置: `LoggerKit/Sources/LoggerKit/Resources/`

2. **添加 LogEventEntity 实体**
   - 添加上述所有属性
   - 配置索引
   - 设置 Class Name: `LogEventEntity`
   - 设置 Module: `LoggerKit`

3. **生成 NSManagedObject 子类**
   - Editor → Create NSManagedObject Subclass
   - 或手动创建上述两个文件

### 阶段 2: 实现数据库层

4. **创建 CoreDataStack.swift**
   - 实现持久化容器
   - 配置 WAL 模式
   - 实现上下文管理

5. **创建 CoreDataDestination.swift**
   - 继承 SwiftyBeaver.BaseDestination
   - 实现批量写入
   - 实现定时刷新

6. **创建 LogDatabaseManager.swift**
   - 实现查询方法
   - 实现统计方法
   - 实现删除方法

7. **创建 LogDatabaseRotationManager.swift**
   - 实现轮转逻辑
   - 实现清理逻辑

### 阶段 3: 集成到现有代码

8. **修改 LoggerEngine.swift**
   - 添加 CoreDataDestination
   - 集成数据库管理器
   - 添加公共方法

9. **修改 LogDetailSceneState.swift**
   - 改用数据库查询
   - 实现分页加载
   - 实现筛选功能

10. **修改 DateFormatters.swift**
    - 添加 dateOnlyFormatter

### 阶段 4: 测试和验证

11. **单元测试**
    - 测试数据写入
    - 测试查询功能
    - 测试轮转功能

12. **性能测试**
    - 对比文件 vs CoreData 的性能
    - 测试大数据量场景

13. **内存测试**
    - 确认内存占用降低
    - 测试 OOM 问题是否解决

---

## ⚙️ CoreData 模型文件内容

创建 `LoggerKit.xcdatamodeld/LoggerKit.xcdatamodel/contents` 文件:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="22758" systemVersion="23G93" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
    <entity name="LogEventEntity" representedClassName="LogEventEntity" syncable="YES">
        <attribute name="context" optional="NO" attributeType="String"/>
        <attribute name="date" optional="NO" attributeType="String"/>
        <attribute name="file" optional="NO" attributeType="String"/>
        <attribute name="fileName" optional="NO" attributeType="String"/>
        <attribute name="function" optional="NO" attributeType="String"/>
        <attribute name="hour" optional="NO" attributeType="Integer 16" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="id" optional="NO" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="level" optional="NO" attributeType="Integer 16" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="line" optional="NO" attributeType="Integer 32" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="message" optional="NO" attributeType="String"/>
        <attribute name="thread" optional="NO" attributeType="String"/>
        <attribute name="timestamp" optional="NO" attributeType="Double" defaultValueString="0.0" usesScalarValueType="YES"/>

        <!-- 索引配置 -->
        <fetchIndex name="byTimestamp">
            <fetchIndexElement property="timestamp" type="Binary" order="descending"/>
        </fetchIndex>
        <fetchIndex name="byLevel">
            <fetchIndexElement property="level" type="Binary" order="ascending"/>
        </fetchIndex>
        <fetchIndex name="byDateHour">
            <fetchIndexElement property="date" type="Binary" order="ascending"/>
            <fetchIndexElement property="hour" type="Binary" order="ascending"/>
        </fetchIndex>
        <fetchIndex name="byFileName">
            <fetchIndexElement property="fileName" type="Binary" order="ascending"/>
        </fetchIndex>
        <fetchIndex name="byFunction">
            <fetchIndexElement property="function" type="Binary" order="ascending"/>
        </fetchIndex>
        <fetchIndex name="byContext">
            <fetchIndexElement property="context" type="Binary" order="ascending"/>
        </fetchIndex>
        <fetchIndex name="byThread">
            <fetchIndexElement property="thread" type="Binary" order="ascending"/>
        </fetchIndex>

        <uniquenessConstraints>
            <uniquenessConstraint>
                <constraint value="id"/>
            </uniquenessConstraint>
        </uniquenessConstraints>
    </entity>
</model>
```

---

## 📊 性能优化建议

### 1. 写入优化

```swift
// 批量写入配置
let batchSize = 50 // 每批 50 条

// 使用后台上下文
let backgroundContext = coreDataStack.newBackgroundContext()
backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

// 禁用撤销管理器
backgroundContext.undoManager = nil
```

### 2. 查询优化

```swift
// 使用 fetchLimit 和 fetchOffset 分页
fetchRequest.fetchLimit = 500
fetchRequest.fetchOffset = page * 500

// 只获取需要的属性
fetchRequest.propertiesToFetch = ["message", "timestamp", "level"]

// 使用批量获取
fetchRequest.fetchBatchSize = 50
```

### 3. 内存优化

```swift
// 刷新上下文释放内存
context.refreshAllObjects()

// 重置上下文
context.reset()

// 使用 faulting
context.shouldDeleteInaccessibleFaults = true
```

### 4. 存储优化

```swift
// 启用 WAL 模式 (已在 CoreDataStack 中配置)
// WAL 模式提升并发性能

// 定期清理
// 1. 删除过期数据
// 2. Vacuum (CoreData 自动处理)
```

---

## ⚠️ 注意事项

### 1. 数据迁移

如果已有旧的日志文件，需要提供迁移工具:

```swift
// 迁移旧日志文件到 CoreData
func migrateOldLogsToDatabase() async throws {
    let logFiles = // 获取旧日志文件列表

    for fileURL in logFiles {
        let events = try LogParser.parseJsonLinesFromFileToEvents(fileURL: fileURL)

        let context = CoreDataStack.shared.newBackgroundContext()
        context.performAndWait {
            for event in events {
                _ = LogEventEntity.create(from: event, in: context)
            }

            try? context.save()
        }
    }
}
```

### 2. 线程安全

- ✅ 写入使用后台上下文
- ✅ 查询使用 viewContext 或新上下文
- ✅ 不要跨上下文传递 NSManagedObject

### 3. 内存管理

- 定期调用 `context.refreshAllObjects()`
- 大批量操作后调用 `context.reset()`
- 使用 autoreleasepool 包裹循环

### 4. 错误处理

```swift
do {
    try context.save()
} catch let error as NSError {
    // 处理错误
    if error.domain == NSCocoaErrorDomain {
        switch error.code {
        case NSManagedObjectValidationError:
            // 验证错误
        case NSManagedObjectConstraintMergeError:
            // 约束冲突
        default:
            break
        }
    }
}
```

---

## 📈 预期效果

### 性能对比

| 指标 | 文件存储 | CoreData | 提升 |
|------|---------|---------|------|
| 加载 100MB 日志 | ~5-10 秒 | ~1-2 秒 | **5x** |
| 内存占用 (峰值) | ~500MB | ~50MB | **10x** |
| 搜索速度 | ~2-5 秒 | ~0.3-0.8 秒 | **7x** |
| 筛选速度 | ~1-3 秒 | ~0.1-0.3 秒 | **15x** |

### 功能增强

- ✅ 分页加载 (无需一次性加载所有数据)
- ✅ 复杂查询 (NSPredicate)
- ✅ 实时更新 (NSFetchedResultsController)
- ✅ 统计分析 (SQL 聚合函数)
- ✅ 自动轮转清理

---

## 🔍 调试技巧

### 1. 启用 CoreData 调试

在 Scheme 中添加启动参数:

```
-com.apple.CoreData.SQLDebug 1
-com.apple.CoreData.ConcurrencyDebug 1
```

### 2. 检查数据库大小

```swift
let size = databaseManager.databaseSize()
print("Database size: \(size / 1024 / 1024) MB")
```

### 3. 查看 SQL 语句

启用 SQL 调试后，控制台会显示所有 SQL 查询。

---

## 📚 参考资料

- [Apple CoreData Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/)
- [NSPredicate Cheat Sheet](https://academy.realm.io/posts/nspredicate-cheatsheet/)
- [CoreData Performance Best Practices](https://developer.apple.com/documentation/coredata/optimizing_core_data_performance)

---

## ✅ 检查清单

实施前确认:

- [ ] Xcode 版本 ≥ 14.0
- [ ] iOS 部署目标 ≥ 15.0
- [ ] 了解 CoreData 基本概念
- [ ] 备份现有日志文件

实施后验证:

- [ ] 日志可以正常写入数据库
- [ ] 日志可以正常查询和显示
- [ ] 筛选和搜索功能正常
- [ ] 内存占用明显降低
- [ ] 加载速度明显提升
- [ ] 轮转和清理功能正常
- [ ] 无崩溃和错误

---

## 🎯 总结

使用 CoreData 迁移后:

1. **内存占用降低 90%** - 不再将整个文件加载到内存
2. **加载速度提升 5-10x** - 分页查询 + 索引优化
3. **搜索性能提升 7-15x** - NSPredicate + 索引
4. **功能更强大** - 复杂查询、统计分析、实时更新
5. **维护更简单** - Apple 官方框架，无第三方依赖

**迁移时间估算: 4-6 小时**

---

*文档版本: 1.0*
*最后更新: 2025-11-25*
