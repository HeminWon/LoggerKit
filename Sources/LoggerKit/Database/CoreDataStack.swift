//
//  CoreDataStack.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025/11/25.
//

import CoreData
import Foundation

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

        #if os(iOS)
        description.setOption(FileProtectionType.complete as NSObject,
                             forKey: NSPersistentStoreFileProtectionKey)
        #endif

        // 启用 WAL 模式 (Write-Ahead Logging)
        description.setOption(["journal_mode": "WAL"] as NSDictionary,
                             forKey: NSSQLitePragmasOption)

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
