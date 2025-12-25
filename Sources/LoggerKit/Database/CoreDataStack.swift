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

    /// 静态缓存的模型URL
    /// 优化:仅在首次访问时查询Bundle,后续访问直接使用缓存
    private static let modelURL: URL = {
        // 定义候选路径列表
        let candidatePaths: [(resource: String, extension: String)] = [
            ("LoggerKit", "momd"),      // 编译后的模型文件
            ("LoggerKit", "mom"),       // 单个模型版本
            ("LoggerKit", "xcdatamodeld") // 开发时的模型文件
        ]

        // 遍历候选路径查找模型文件
        for (resource, ext) in candidatePaths {
            if let url = Bundle.module.url(forResource: resource, withExtension: ext) {
                return url
            }
        }

        // 如果都找不到,打印调试信息并抛出错误
        print("❌ Bundle.module resourcePath: \(Bundle.module.resourcePath ?? "nil")")
        if let resourcePath = Bundle.module.resourcePath {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("❌ Bundle contents: \(contents)")
            } catch {
                print("❌ Failed to list bundle contents: \(error)")
            }
        }

        fatalError("Failed to find LoggerKit CoreData model in bundle. Tried extensions: \(candidatePaths.map { $0.extension }.joined(separator: ", "))")
    }()

    lazy var persistentContainer: NSPersistentContainer = {
        // 使用静态缓存的模型URL
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: Self.modelURL) else {
            fatalError("Failed to load model from \(Self.modelURL)")
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
