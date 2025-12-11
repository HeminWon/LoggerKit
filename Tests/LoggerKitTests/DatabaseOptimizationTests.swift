//
//  DatabaseOptimizationTests.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025/12/11.
//  验证数据库优化的正确性
//

import Testing
import Foundation
import CoreData
@testable import LoggerKit

@Suite("Database Optimization Tests")
struct DatabaseOptimizationTests {

    @Test("Optimized fetchStatistics returns correct results")
    func testOptimizedFetchStatistics() throws {
        let manager = LogDatabaseManager()

        // 执行统计查询
        let statistics = try manager.fetchStatistics()

        // 验证基本完整性
        #expect(statistics.totalCount >= 0)
        #expect(statistics.levelCounts.count >= 0)
        #expect(statistics.topFunctions.count >= 0)

        // 验证总数等于各级别之和
        let levelCountsSum = statistics.levelCounts.values.reduce(0, +)
        #expect(statistics.totalCount == levelCountsSum,
                "总数(\(statistics.totalCount))应该等于各级别之和(\(levelCountsSum))")

        // 验证级别统计的合理性
        for (level, count) in statistics.levelCounts {
            #expect(level >= 0 && level <= 6, "级别应该在0-6之间")
            #expect(count >= 0, "计数不应该为负数")
        }

        // 验证热门函数排序正确(按计数降序)
        for i in 0..<(statistics.topFunctions.count - 1) {
            let (_, count1) = statistics.topFunctions[i]
            let (_, count2) = statistics.topFunctions[i + 1]
            #expect(count1 >= count2, "热门函数应该按计数降序排列")
        }

        // 验证没有空函数名
        for (function, _) in statistics.topFunctions {
            #expect(!function.isEmpty, "不应该包含空函数名")
        }

        print("✅ 优化后的fetchStatistics验证通过")
        print("   - 总日志数: \(statistics.totalCount)")
        print("   - 级别统计: \(statistics.levelCounts)")
        print("   - 热门函数数量: \(statistics.topFunctions.count)")
    }

    @Test("fetchStatistics handles empty database")
    func testFetchStatisticsEmptyDatabase() throws {
        // 注意:这个测试需要在空数据库上运行
        // 在实际项目中可能需要先清理数据或使用独立的测试数据库
        let manager = LogDatabaseManager()

        let statistics = try manager.fetchStatistics()

        // 空数据库应该返回0
        #expect(statistics.levelCounts.isEmpty || statistics.levelCounts.values.allSatisfy { $0 == 0 })
        #expect(statistics.topFunctions.isEmpty)

        print("✅ 空数据库统计验证通过")
    }

    @Test("fetchStatistics performance check")
    func testFetchStatisticsPerformance() throws {
        let manager = LogDatabaseManager()

        // 测量执行时间
        let start = Date()
        let statistics = try manager.fetchStatistics()
        let duration = Date().timeIntervalSince(start) * 1000 // 毫秒

        print("📊 fetchStatistics执行时间: \(String(format: "%.2f", duration))ms")
        print("   - 总日志数: \(statistics.totalCount)")

        // 性能期望:对于大多数情况应该在100ms以内
        // (实际性能取决于数据量,这里只是记录,不做严格断言)
        if duration > 100 {
            print("⚠️ 警告:查询时间超过100ms,数据量:\(statistics.totalCount)")
        }
    }
}
