//
//  ConcurrentCache.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/9/11.
//

import Foundation

/// 线程安全的缓存容器（多读单写）
final class ConcurrentCache<Key: Hashable, Value>: @unchecked Sendable {
    private var storage = [Key: Value]()
    private let queue = DispatchQueue(label: "concurrent.cache.queue", attributes: .concurrent)

    /// 读取缓存（线程安全）
    func value(for key: Key) -> Value? {
        queue.sync {
            storage[key]
        }
    }

    /// 同步设置缓存（线程安全，立即可读）
    func setValue(_ value: Value, for key: Key) {
        queue.sync(flags: .barrier) {  // 改为同步
            self.storage[key] = value
        }
    }

    /// 异步设置缓存（性能优先，但可能存在读写延迟）
    func setValueAsync(_ value: Value, for key: Key) {
        queue.async(flags: .barrier) {
            self.storage[key] = value
        }
    }

    /// 清空缓存
    func clear() {
        queue.sync(flags: .barrier) {
            storage.removeAll()
        }
    }
}

