//
//  FilterOptionsCache.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025/12/11.
//

import Foundation

/// 过滤选项缓存
/// 使用并发安全的缓存管理器,避免手动管理多个缓存变量
final class FilterOptionsCache {

    // MARK: - Cache Keys
    private enum CacheKey: String {
        case functions
        case fileNames
        case contexts
        case threads
        case functionCounts
        case fileNameCounts
        case contextCounts
        case threadCounts
        case messageCounts
    }

    // MARK: - Storage
    private var storage: [CacheKey: Any] = [:]
    private let queue = DispatchQueue(label: "com.loggerkit.filter-cache", attributes: .concurrent)

    // MARK: - Public Methods

    /// 获取函数名列表
    func functions() -> [String]? {
        read(.functions)
    }

    /// 设置函数名列表
    func setFunctions(_ value: [String]) {
        write(.functions, value: value)
    }

    /// 获取文件名列表
    func fileNames() -> [String]? {
        read(.fileNames)
    }

    /// 设置文件名列表
    func setFileNames(_ value: [String]) {
        write(.fileNames, value: value)
    }

    /// 获取上下文列表
    func contexts() -> [String]? {
        read(.contexts)
    }

    /// 设置上下文列表
    func setContexts(_ value: [String]) {
        write(.contexts, value: value)
    }

    /// 获取线程列表
    func threads() -> [String]? {
        read(.threads)
    }

    /// 设置线程列表
    func setThreads(_ value: [String]) {
        write(.threads, value: value)
    }

    /// 获取函数名计数
    func functionCounts() -> [String: Int]? {
        read(.functionCounts)
    }

    /// 设置函数名计数
    func setFunctionCounts(_ value: [String: Int]) {
        write(.functionCounts, value: value)
    }

    /// 获取文件名计数
    func fileNameCounts() -> [String: Int]? {
        read(.fileNameCounts)
    }

    /// 设置文件名计数
    func setFileNameCounts(_ value: [String: Int]) {
        write(.fileNameCounts, value: value)
    }

    /// 获取上下文计数
    func contextCounts() -> [String: Int]? {
        read(.contextCounts)
    }

    /// 设置上下文计数
    func setContextCounts(_ value: [String: Int]) {
        write(.contextCounts, value: value)
    }

    /// 获取线程计数
    func threadCounts() -> [String: Int]? {
        read(.threadCounts)
    }

    /// 设置线程计数
    func setThreadCounts(_ value: [String: Int]) {
        write(.threadCounts, value: value)
    }

    /// 获取消息计数
    func messageCounts() -> [String: Int]? {
        read(.messageCounts)
    }

    /// 设置消息计数
    func setMessageCounts(_ value: [String: Int]) {
        write(.messageCounts, value: value)
    }

    /// 清除所有缓存 (使用同步 barrier)
    func invalidateAll() {
        queue.sync(flags: .barrier) { [weak self] in
            self?.storage.removeAll()
        }
    }

    /// 清除特定键的缓存 (使用同步 barrier)
    private func invalidate(_ key: CacheKey) {
        _ = queue.sync(flags: .barrier) { [weak self] in
            self?.storage.removeValue(forKey: key)
        }
    }

    // MARK: - Private Methods

    /// 并发安全的读取
    private func read<T>(_ key: CacheKey) -> T? {
        queue.sync {
            storage[key] as? T
        }
    }

    /// 并发安全的写入 (使用同步 barrier)
    private func write(_ key: CacheKey, value: Any) {
        queue.sync(flags: .barrier) { [weak self] in
            self?.storage[key] = value
        }
    }
}
