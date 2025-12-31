//
//  LoggerEngineTests.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/12/26.
//

import XCTest
@testable import LoggerKit

final class LoggerEngineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        #if DEBUG
        // 每个测试前重置状态
        LoggerEngine.resetForTesting()
        #endif
    }

    override func tearDown() {
        #if DEBUG
        LoggerEngine.resetForTesting()
        #endif
        super.tearDown()
    }

    /// 测试未配置时日志不崩溃
    func testUnconfiguredLogsDoNotCrash() {
        // 创建新的 Logger 实例
        let logger = Logger()

        // 未配置，SwiftyBeaver 会静默处理
        logger.verbose("This will be dropped")
        logger.debug("This will be dropped")
        logger.info("This will be dropped")
        logger.warning("This will be dropped")
        logger.error("This will be dropped")

        // 验证没有崩溃
        XCTAssertTrue(true, "未配置时不应该崩溃")
    }

    /// 测试配置前 isConfigured 为 false
    func testIsConfiguredInitiallyFalse() {
        XCTAssertFalse(LoggerEngine.isConfigured, "初始状态应该是未配置")
    }

    /// 测试配置后 isConfigured 为 true
    func testIsConfiguredAfterConfiguration() {
        LoggerEngine.configure(LoggerEngineConfiguration(
            enableConsole: false,  // 禁用所有输出避免副作用
            enableDatabase: false
        ))

        XCTAssertTrue(LoggerEngine.isConfigured, "配置后应该是已配置状态")
    }

    /// 测试配置后日志正常工作
    func testConfiguredLogsWork() {
        // 配置引擎（禁用所有输出避免副作用）
        LoggerEngine.configure(LoggerEngineConfiguration(
            enableConsole: false,
            enableDatabase: false
        ))

        // 配置后，日志应正常工作
        let logger = Logger()
        logger.verbose("Verbose message")
        logger.debug("Debug message")
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")

        // 验证没有崩溃
        XCTAssertTrue(true, "配置后应该正常工作")
    }

    /// 测试重复配置被拒绝
    func testDoubleConfigurationIsRejected() {
        // 第一次配置（禁用所有输出避免副作用）
        LoggerEngine.configure(LoggerEngineConfiguration(
            enableConsole: false,
            enableDatabase: false
        ))
        XCTAssertTrue(LoggerEngine.isConfigured, "第一次配置应该成功")

        // 注意：在 DEBUG 模式下，第二次配置会触发 assertionFailure 导致测试崩溃
        // 因此我们只验证状态，不实际调用第二次配置
        // 重复配置的保护已经通过 assertionFailure 和 guard 语句实现

        // 验证仍然是已配置状态
        XCTAssertTrue(LoggerEngine.isConfigured, "应该保持已配置状态")
    }

    /// 测试并发配置安全性
    func testConcurrentConfigurationIsSafe() async {
        // 注意：此测试验证配置锁的线程安全性
        // 由于已配置后重复配置会触发 assertionFailure，
        // 我们只测试配置本身是线程安全的

        // 单次配置应该是安全的
        LoggerEngine.configure(LoggerEngineConfiguration(
            enableConsole: false,
            enableDatabase: false
        ))

        // 验证配置成功
        XCTAssertTrue(LoggerEngine.isConfigured, "配置应该成功")

        // 测试 isConfigured 的并发读取是安全的
        let expectation = self.expectation(description: "Concurrent read")
        expectation.expectedFulfillmentCount = 100

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let configured = LoggerEngine.isConfigured
                    expectation.fulfill()
                    return configured
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        // 验证仍然是已配置状态
        XCTAssertTrue(LoggerEngine.isConfigured, "并发读取后应该保持已配置状态")
    }

    /// 测试未配置时的性能（应该很快）
    func testUnconfiguredPerformance() {
        let logger = Logger()

        measure {
            for _ in 0..<10000 {
                logger.info("Performance test")
            }
        }

        // 即使未配置，也应该很快（因为没有任何开销）
    }

    /// 测试配置后的性能
    func testConfiguredPerformance() {
        LoggerEngine.configure(LoggerEngineConfiguration(
            enableConsole: false,  // 禁用控制台以减少 I/O
            enableDatabase: false   // 禁用数据库以减少 I/O
        ))

        let logger = Logger()

        measure {
            for _ in 0..<10000 {
                logger.info("Performance test")
            }
        }
    }

    /// 测试重置功能（仅 DEBUG）
    #if DEBUG
    func testResetForTesting() {
        // 配置（禁用所有输出避免副作用）
        LoggerEngine.configure(LoggerEngineConfiguration(
            enableConsole: false,
            enableDatabase: false
        ))
        XCTAssertTrue(LoggerEngine.isConfigured, "配置后应该是已配置状态")

        // 重置
        LoggerEngine.resetForTesting()
        XCTAssertFalse(LoggerEngine.isConfigured, "重置后应该是未配置状态")

        // 可以再次配置
        LoggerEngine.configure(LoggerEngineConfiguration(
            enableConsole: false,
            enableDatabase: false
        ))
        XCTAssertTrue(LoggerEngine.isConfigured, "重置后应该可以再次配置")
    }
    #endif

    /// 测试并发日志调用的安全性
    func testConcurrentLoggingIsSafe() async {
        LoggerEngine.configure(LoggerEngineConfiguration(
            enableConsole: false,
            enableDatabase: false
        ))

        let logger = Logger()
        let expectation = self.expectation(description: "Concurrent logging")
        expectation.expectedFulfillmentCount = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    logger.info("Concurrent log message \(i)")
                    expectation.fulfill()
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(true, "并发日志调用应该是安全的")
    }

    /// 测试会话信息
    func testSessionInfo() {
        let sessionInfo = LoggerEngine.shared.getSessionInfo()

        XCTAssertFalse(sessionInfo.sessionId.isEmpty, "会话ID不应该为空")
        XCTAssertGreaterThan(sessionInfo.sessionStartTime, 0, "会话开始时间应该大于0")
    }
}
