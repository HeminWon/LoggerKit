//
//  LoggerKitTests.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/21.
//

import Testing
import Foundation
@testable import LoggerKit

@Suite("Logger Tests")
struct LoggerTests {

    @Test("Logger initialization with default config")
    func testDefaultInitialization() {
        let logger = Logger()
        #expect(logger != nil)
    }

    @Test("Logger supports multiple instances")
    func testMultipleInstances() {
        let logger1 = Logger(level: .debug)
        let logger2 = Logger(level: .error)

        #expect(logger1 !== logger2)
    }

    @Test("Logger with custom configuration")
    func testCustomConfiguration() {
        let config = LogConfiguration(
            destinations: [],
            rotationPolicy: .size(5 * 1024 * 1024),
            maxLogFiles: 5
        )
        let logger = Logger(configuration: config)
        #expect(logger != nil)
    }
}

@Suite("MockLogger Tests")
struct MockLoggerTests {

    @Test("MockLogger captures calls")
    func testMockLoggerCapturesCalls() {
        let mock = MockLogger()

        mock.debug("Test message")
        mock.error("Error message")

        #expect(mock.calls.count == 2)
        #expect(mock.verify(level: "DEBUG", message: "Test message"))
        #expect(mock.verify(level: "ERROR", message: "Error message"))
    }

    @Test("MockLogger captures all log levels")
    func testAllLogLevels() {
        let mock = MockLogger()

        mock.verbose("Verbose")
        mock.debug("Debug")
        mock.info("Info")
        mock.warning("Warning")
        mock.error("Error")

        #expect(mock.callCount == 5)
        #expect(mock.verify(level: "VERBOSE", message: "Verbose"))
        #expect(mock.verify(level: "DEBUG", message: "Debug"))
        #expect(mock.verify(level: "INFO", message: "Info"))
        #expect(mock.verify(level: "WARNING", message: "Warning"))
        #expect(mock.verify(level: "ERROR", message: "Error"))
    }

    @Test("MockLogger reset clears all calls")
    func testReset() {
        let mock = MockLogger()

        mock.debug("Message 1")
        mock.info("Message 2")
        #expect(mock.callCount == 2)

        mock.reset()
        #expect(mock.callCount == 0)
    }

    @Test("MockLogger lastCall returns most recent")
    func testLastCall() {
        let mock = MockLogger()

        mock.debug("First")
        mock.info("Second")
        mock.error("Third")

        #expect(mock.lastCall?.message == "Third")
        #expect(mock.lastCall?.level == "ERROR")
    }

    @Test("MockLogger filters by level")
    func testFilterByLevel() {
        let mock = MockLogger()

        mock.debug("Debug 1")
        mock.info("Info 1")
        mock.debug("Debug 2")
        mock.error("Error 1")

        let debugCalls = mock.calls(forLevel: "DEBUG")
        #expect(debugCalls.count == 2)
    }

    @Test("MockLogger containsMessage works")
    func testContainsMessage() {
        let mock = MockLogger()

        mock.debug("Unique message")

        #expect(mock.containsMessage("Unique message"))
        #expect(!mock.containsMessage("Not found"))
    }
}

@Suite("ConcurrentCache Tests")
struct ConcurrentCacheTests {

    @Test("Sync write is immediately readable")
    func testSyncWrite() {
        let cache = ConcurrentCache<String, Int>()

        cache.setValue(42, for: "key")
        let value = cache.value(for: "key")

        #expect(value == 42)
    }

    @Test("Multiple values storage")
    func testMultipleValues() {
        let cache = ConcurrentCache<String, String>()

        cache.setValue("value1", for: "key1")
        cache.setValue("value2", for: "key2")
        cache.setValue("value3", for: "key3")

        #expect(cache.value(for: "key1") == "value1")
        #expect(cache.value(for: "key2") == "value2")
        #expect(cache.value(for: "key3") == "value3")
    }

    @Test("Clear removes all values")
    func testClear() {
        let cache = ConcurrentCache<String, Int>()

        cache.setValue(1, for: "a")
        cache.setValue(2, for: "b")
        cache.clear()

        #expect(cache.value(for: "a") == nil)
        #expect(cache.value(for: "b") == nil)
    }

    @Test("Thread safety with concurrent access")
    func testThreadSafety() async {
        let cache = ConcurrentCache<Int, String>()

        await withTaskGroup(of: Void.self) { group in
            // 100 concurrent writes
            for i in 0..<100 {
                group.addTask {
                    cache.setValue("value-\(i)", for: i)
                }
            }
        }

        // Verify all writes succeeded
        for i in 0..<100 {
            #expect(cache.value(for: i) == "value-\(i)")
        }
    }
}

@Suite("LogParser Tests")
struct LogParserTests {

    @Test("Parse valid JSON lines")
    func testValidParsing() {
        let json = """
        {"thread":"main","function":"test()","line":10,"file":"/path/File.swift","timestamp":1234567890.0,"level":1,"message":"Test","context":"Module"}
        {"thread":"bg","function":"background()","line":20,"file":"/path/Other.swift","timestamp":1234567891.0,"level":2,"message":"Info","context":"Module"}
        """

        let events = LogParser.parseJsonLinesToEvents(json)

        #expect(events.count == 2)
        #expect(events[0].message == "Test")
        #expect(events[1].message == "Info")
    }

    @Test("Skip invalid lines gracefully")
    func testInvalidLineSkipping() {
        let json = """
        {"thread":"main","function":"test()","line":10,"file":"/path/File.swift","timestamp":1234567890.0,"level":1,"message":"Valid","context":"Module"}
        {invalid json line}
        {"thread":"bg","function":"background()","line":20,"file":"/path/Other.swift","timestamp":1234567891.0,"level":2,"message":"Valid2","context":"Module"}
        """

        let events = LogParser.parseJsonLinesToEvents(json)

        // 应该跳过中间的无效行
        #expect(events.count == 2)
        #expect(events[0].message == "Valid")
        #expect(events[1].message == "Valid2")
    }

    @Test("Parse empty content returns empty array")
    func testEmptyContent() {
        let events = LogParser.parseJsonLinesToEvents("")
        #expect(events.isEmpty)
    }

    @Test("Parse content with only whitespace")
    func testWhitespaceOnly() {
        let events = LogParser.parseJsonLinesToEvents("   \n   \n   ")
        #expect(events.isEmpty)
    }
}

@Suite("LogRotation Tests")
struct LogRotationTests {

    @Test("Size-based rotation triggers correctly")
    func testSizeRotation() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let logFile = tempDir.appendingPathComponent("test_rotation.log")

        // 创建超过限制的文件（15MB）
        let largeContent = String(repeating: "x", count: 15 * 1024 * 1024)
        try largeContent.write(to: logFile, atomically: true, encoding: .utf8)

        let manager = LogRotationManager(fileURL: logFile, policy: .size(10 * 1024 * 1024))

        #expect(manager.shouldRotate() == true)

        // 清理
        try? FileManager.default.removeItem(at: logFile)
    }

    @Test("Size-based rotation does not trigger for small files")
    func testNoRotationForSmallFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let logFile = tempDir.appendingPathComponent("test_small.log")

        // 创建小于限制的文件（1MB）
        let smallContent = String(repeating: "x", count: 1 * 1024 * 1024)
        try smallContent.write(to: logFile, atomically: true, encoding: .utf8)

        let manager = LogRotationManager(fileURL: logFile, policy: .size(10 * 1024 * 1024))

        #expect(manager.shouldRotate() == false)

        // 清理
        try? FileManager.default.removeItem(at: logFile)
    }

    @Test("Never rotation policy always returns false")
    func testNeverRotation() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let logFile = tempDir.appendingPathComponent("test_never.log")

        // 创建大文件
        let largeContent = String(repeating: "x", count: 20 * 1024 * 1024)
        try largeContent.write(to: logFile, atomically: true, encoding: .utf8)

        let manager = LogRotationManager(fileURL: logFile, policy: .never)

        #expect(manager.shouldRotate() == false)

        // 清理
        try? FileManager.default.removeItem(at: logFile)
    }
}

@Suite("Constants Tests")
struct ConstantsTests {

    @Test("Log directory name is correct")
    func testLogDirectoryName() {
        #expect(Constants.logDirectoryName == "LoggerKit")
    }

    @Test("UserDefaults key is correct")
    func testUserDefaultsKey() {
        #expect(Constants.UserDefaultsKeys.logIdentifier == "com.loggerkit.identifier")
    }
}

@Suite("DateFormatters Tests")
struct DateFormattersTests {

    @Test("File name formatter produces expected format")
    func testFileNameFormatter() {
        let date = Date(timeIntervalSince1970: 0) // 1970-01-01 00:00:00 UTC
        let formatted = DateFormatters.fileNameFormatter.string(from: date)

        // 格式应该是 yyyyMMdd-HHmmss.SSSZ
        #expect(formatted.contains("-"))
        #expect(formatted.count > 15)
    }

    @Test("Display formatter produces expected format")
    func testDisplayFormatter() {
        let date = Date(timeIntervalSince1970: 0)
        let formatted = DateFormatters.displayFormatter.string(from: date)

        // 格式应该是 yyyy-MM-dd HH:mm:ss.SSS
        #expect(formatted.contains("-"))
        #expect(formatted.contains(":"))
    }
}
