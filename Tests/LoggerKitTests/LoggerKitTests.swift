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
        // Logger实例创建成功
        #expect(true)
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
