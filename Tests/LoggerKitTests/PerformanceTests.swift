//
//  PerformanceTests.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025/12/11.
//  性能基准测试 - 用于测量优化前后的性能对比
//

import Testing
import Foundation
import CoreData
@testable import LoggerKit

@Suite("Performance Benchmark Tests")
struct PerformanceBenchmarkTests {

    // MARK: - Helper Methods

    /// 测量代码块执行时间(毫秒)
    private func measure(_ name: String, block: () throws -> Void) rethrows -> TimeInterval {
        let start = Date()
        try block()
        let duration = Date().timeIntervalSince(start) * 1000 // 转换为毫秒
        print("📊 [\(name)] 执行时间: \(String(format: "%.2f", duration))ms")
        return duration
    }

    /// 获取共享的CoreDataStack用于测试
    /// 注意:测试使用共享实例,测试后需要清理数据
    private func getTestCoreDataStack() -> CoreDataStack {
        return CoreDataStack.shared
    }

    /// 生成测试日志数据
    private func generateTestLogs(count: Int, in context: NSManagedObjectContext) throws {
        let levels = [0, 1, 2, 3, 4, 5, 6] // 7个级别
        let functions = ["viewDidLoad()", "fetchData()", "processResult()", "updateUI()", "handleError()"]
        let files = ["ViewController.swift", "DataManager.swift", "NetworkService.swift"]
        let threads = ["main", "background", "network"]
        let contexts = ["App", "Network", "Database"]

        let batchSize = 1000
        var createdCount = 0

        while createdCount < count {
            let currentBatchSize = min(batchSize, count - createdCount)

            for i in 0..<currentBatchSize {
                let entity = LogEventEntity(context: context)
                entity.id = UUID()
                entity.timestamp = Date().timeIntervalSince1970 + Double(i)
                entity.level = Int16(levels[i % levels.count])
                entity.message = "Test log message \(createdCount + i)"
                entity.function = functions[i % functions.count]
                entity.fileName = files[i % files.count]
                entity.thread = threads[i % threads.count]
                entity.context = contexts[i % contexts.count]
                entity.line = Int32(i % 1000)
                entity.sessionId = "test-session"
                entity.sessionStartTime = Date().timeIntervalSince1970
                entity.date = "2025-12-11"
            }

            try context.save()
            createdCount += currentBatchSize

            // 重置context避免内存累积
            context.reset()
        }

        print("✅ 生成了 \(count) 条测试日志")
    }

    // MARK: - Baseline Performance Tests

    @Test("Baseline: fetchStatistics() performance")
    func testBaselineFetchStatistics() throws {
        // 注意:这个测试使用共享的CoreDataStack,测试的是已有数据的性能
        // 适合在有真实数据的Example项目中运行
        let manager = LogDatabaseManager()

        // 测量fetchStatistics性能
        var statistics: LogStatistics?
        let duration = measure("fetchStatistics") {
            statistics = try? manager.fetchStatistics()
        }

        // 验证结果正确性
        #expect(statistics != nil)
        if let stats = statistics {
            print("📊 总日志数: \(stats.totalCount)")
            print("📊 级别统计: \(stats.levelCounts)")
            print("📊 热门函数数: \(stats.topFunctions.count)")
        }

        // 记录基准性能(用于后续对比)
        print("📌 基准性能: \(String(format: "%.2f", duration))ms")
    }

    @Test("Baseline: fetchEvents() performance with filters")
    func testBaselineFetchEventsWithFilters() throws {
        let manager = LogDatabaseManager()

        // 测量过滤查询性能
        var events: [LogEvent]?
        let duration = measure("fetchEvents-filtered") {
            events = try? manager.fetchEvents(
                levels: [.debug, .info, .error],
                searchText: "Test",
                limit: 500
            )
        }

        // 验证结果
        if let events = events {
            print("📊 查询到 \(events.count) 条日志")
        }

        print("📌 基准性能(过滤查询): \(String(format: "%.2f", duration))ms")
    }

    @Test("Baseline: Database size measurement")
    func testBaselineDatabaseSize() throws {
        let manager = LogDatabaseManager()

        // 获取数据库大小
        let dbSize = manager.databaseSize()
        print("📊 当前数据库大小: \(dbSize) bytes (\(dbSize / 1024)KB)")
    }
}

@Suite("Performance Regression Tests")
struct PerformanceRegressionTests {

    // 这个套件将在优化后用于验证性能提升
    // 目前保持为空,等待优化实施后添加对比测试

    @Test("Placeholder for post-optimization tests")
    func testPlaceholder() {
        // 占位测试,优化后将添加性能对比测试
        #expect(true)
    }
}
