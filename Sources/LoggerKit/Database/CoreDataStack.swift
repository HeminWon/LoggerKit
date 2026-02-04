//
//  CoreDataStack.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025/11/25.
//

import CoreData
import Foundation

public final class CoreDataStack {

    public private(set) static var shared: CoreDataStack?

    /// 线程安全锁，用于保护单例初始化
    private static let lock = NSLock()

    /// 初始化 CoreDataStack 单例
    /// 必须在应用启动时调用此方法
    /// - Note: 线程安全，可以在任何线程调用
    /// - Warning: 此方法会阻塞调用线程直到初始化完成，建议在应用启动早期调用
    public static func initialize() {
        // 快速路径检查，避免不必要的锁竞争
        if shared != nil { return }

        lock.lock()
        // 双重检查锁定模式
        if shared != nil {
            lock.unlock()
            return
        }

        // 直接在当前线程初始化，避免 sync 嵌套阻塞
        do {
            shared = try CoreDataStack()
        } catch {
            print("⚠️ CoreDataStack 初始化失败，日志持久化功能将不可用: \(error)")
            shared = nil
        }

        lock.unlock()
    }

    private init() throws {
        self.persistentContainer = try Self.createPersistentContainer()
    }

    // MARK: - Core Data Stack

    /// 获取 CoreData 模型文件 URL
    /// - Throws: CoreDataError.modelNotFound 如果找不到模型文件
    /// - Returns: 模型文件的 URL
    private static func getModelURL() throws -> URL {
        // 定义候选路径列表
        let candidatePaths: [(resource: String, extension: String)] = [
            ("LoggerKit", "momd"),      // 编译后的模型文件
            ("LoggerKit", "mom"),       // 单个模型版本
            ("LoggerKit", "xcdatamodeld") // 开发时的模型文件
        ]

        // 遍历候选路径查找模型文件
        for (resource, ext) in candidatePaths {
            if let url = Bundle.loggerKit.url(forResource: resource, withExtension: ext) {
                return url
            }
        }

        // 如果都找不到,打印调试信息
        print("❌ Bundle.loggerKit resourcePath: \(Bundle.loggerKit.resourcePath ?? "nil")")
        if let resourcePath = Bundle.loggerKit.resourcePath {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("❌ Bundle contents: \(contents)")
            } catch {
                print("❌ Failed to list bundle contents: \(error)")
            }
        }

        throw CoreDataError.modelNotFound
    }

    internal var persistentContainer: NSPersistentContainer

    /// 创建 NSPersistentContainer
    /// - Throws: CoreDataError 如果创建失败
    /// - Returns: 配置好的 NSPersistentContainer
    private static func createPersistentContainer() throws -> NSPersistentContainer {
        // 获取模型 URL
        let modelURL = try getModelURL()

        // 加载模型
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            throw CoreDataError.modelLoadFailed(modelURL)
        }

        let container = NSPersistentContainer(name: "LoggerKit", managedObjectModel: managedObjectModel)

        // 安全获取存储路径
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CoreDataError.storeURLUnavailable
        }

        let storeURL = documentsURL
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

        #if os(iOS)
        // 使用 completeUntilFirstUserAuthentication 允许后台访问
        // 避免设备锁定时 CoreData 不可用导致 crash
        description.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
                             forKey: NSPersistentStoreFileProtectionKey)
        #endif

        // 启用 WAL 模式 (Write-Ahead Logging)
        description.setOption(["journal_mode": "WAL"] as NSDictionary,
                             forKey: NSSQLitePragmasOption)

        container.persistentStoreDescriptions = [description]

        // 使用信号量同步等待异步加载完成
        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                loadError = error
            } else {
                print("✅ CoreData 存储加载成功: \(storeDescription.url?.path ?? "")")
            }
            semaphore.signal()
        }

        semaphore.wait()  // 等待异步加载完成

        if let error = loadError {
            throw CoreDataError.storeLoadFailed(error as NSError)
        }

        // 配置视图上下文
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }

    // 主线程上下文 (用于 UI)
    public var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    // 后台上下文 (用于批量写入)
    public func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }

    // MARK: - Store Availability

    /// 检查 persistent store 是否可用
    /// - Returns: true 表示可用，false 表示不可用（例如设备锁定）
    public func isStoreAvailable() -> Bool {
        return !persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty
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

// MARK: - Error Types

enum CoreDataError: Error {
    case modelNotFound
    case modelLoadFailed(URL)
    case storeURLUnavailable
    case storeLoadFailed(NSError)

    var localizedDescription: String {
        switch self {
        case .modelNotFound:
            return "CoreData 模型文件未找到"
        case .modelLoadFailed(let url):
            return "无法从 \(url.path) 加载模型"
        case .storeURLUnavailable:
            return "无法获取存储路径"
        case .storeLoadFailed(let error):
            return "存储加载失败: \(error.localizedDescription)"
        }
    }
}
