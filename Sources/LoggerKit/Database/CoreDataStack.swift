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
        // 从正确的 bundle 加载模型
        let modelURL: URL

        // 尝试查找编译后的 .momd 文件
        if let momdURL = Bundle.module.url(forResource: "LoggerKit", withExtension: "momd") {
            modelURL = momdURL
        }
        // 如果找不到 .momd，尝试查找 .mom 文件（单个模型版本）
        else if let momURL = Bundle.module.url(forResource: "LoggerKit", withExtension: "mom") {
            modelURL = momURL
        }
        // 如果还找不到，尝试在 xcdatamodeld 目录中查找
        else if let xcdatamodeldURL = Bundle.module.url(forResource: "LoggerKit", withExtension: "xcdatamodeld"),
                let momURL = Bundle(url: xcdatamodeldURL)?.url(forResource: "LoggerKit", withExtension: "mom") {
            modelURL = momURL
        } else {
            // 打印调试信息
            print("❌ Bundle.module resourcePath: \(Bundle.module.resourcePath ?? "nil")")
            if let resourcePath = Bundle.module.resourcePath {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    print("❌ Bundle contents: \(contents)")
                } catch {
                    print("❌ Failed to list bundle contents: \(error)")
                }
            }
            fatalError("Failed to find LoggerKit CoreData model in bundle")
        }

        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load model from \(modelURL)")
        }

        let container = NSPersistentContainer(name: "LoggerKit", managedObjectModel: managedObjectModel)

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
