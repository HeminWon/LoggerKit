//
//  CoreDataDestination.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025/11/25.
//

import Foundation
import SwiftyBeaver
import CoreData

/// CoreData 日志输出目标
public final class CoreDataDestination: BaseDestination {

    private let coreDataStack: CoreDataStack?
    private var pendingEvents: [LogEvent] = []
    private let queue = DispatchQueue(label: "com.loggerkit.coredata", qos: .utility)

    // MARK: - 写入策略配置

    /// 批量写入大小
    private let batchSize: Int

    /// 防抖延迟（秒）
    private let debounceInterval: TimeInterval

    /// 立即写入的日志级别
    private let immediateFlushLevels: Set<LogEvent.Level>

    /// 防抖任务
    private var debounceWorkItem: DispatchWorkItem?

    // MARK: - 会话信息

    private let sessionId: String
    private let sessionStartTime: TimeInterval

    public init(sessionId: String, sessionStartTime: TimeInterval,
                coreDataStack: CoreDataStack? = CoreDataStack.shared,
                batchSize: Int = 50, debounceInterval: TimeInterval = 2.0,
                immediateFlushLevels: Set<LogEvent.Level> = [.error, .warning]) {
        self.sessionId = sessionId
        self.sessionStartTime = sessionStartTime
        self.coreDataStack = coreDataStack
        self.batchSize = batchSize
        self.debounceInterval = debounceInterval
        self.immediateFlushLevels = immediateFlushLevels

        super.init()

        // 设置格式 (不需要格式化,直接存储结构化数据)
        self.format = ""

        // 启动时检查并警告
        if coreDataStack == nil {
            print("⚠️ CoreDataDestination: CoreDataStack 不可用，日志将不会持久化")
        }
    }

    override public func send(_ level: SwiftyBeaver.Level, msg: String, thread: String,
                              file: String, function: String, line: Int, context: Any? = nil) -> String? {
        guard let stack = coreDataStack else { return nil }
        // 构造日志事件,包含会话信息
        let logEvent = LogEvent(thread: thread,
                                function: function,
                                line: line,
                                file: file,
                                timestamp: Date().timeIntervalSince1970,
                                level: mapLevel(level),
                                message: msg,
                                context: (context as? String) ?? "",
                                sessionId: sessionId,
                                sessionStartTime: sessionStartTime)

        // 添加到待写入队列
        queue.async { [weak self] in
            self?.addEvent(logEvent)
        }

        return nil
    }

    private func addEvent(_ event: LogEvent) {
        pendingEvents.append(event)

        // 【策略 1】紧急级别触发 - Error/Warning 立即写入
        if immediateFlushLevels.contains(event.level) {
            flushPendingEvents()
            return
        }

        // 【策略 2】批量大小触发 - 达到批量大小立即写入
        if pendingEvents.count >= batchSize {
            flushPendingEvents()
            return
        }

        // 【策略 3】防抖触发 - 延迟写入
        scheduleDebounceFlush()
    }

    /// 调度防抖刷新
    private func scheduleDebounceFlush() {
        // 取消之前的防抖任务
        debounceWorkItem?.cancel()

        // 创建新的防抖任务
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPendingEvents()
        }

        // 延迟执行
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)

        self.debounceWorkItem = workItem
    }

    public func flush() {
        queue.async { [weak self] in
            self?.flushPendingEvents()
        }
    }

    private func flushPendingEvents() {
        // 取消防抖任务
        cancelDebounceTask()

        // 检查是否有待写入的日志
        guard !pendingEvents.isEmpty, let stack = coreDataStack else {
            return
        }

        // ⚠️ 检查 persistent store 是否可用，避免设备锁定时 crash
        guard stack.isStoreAvailable() else {
            #if DEBUG
            print("⚠️ Persistent store 不可用，丢弃 \(pendingEvents.count) 条日志")
            #endif
            return
        }

        let eventsToWrite = pendingEvents
        pendingEvents.removeAll()

        // 使用异步保存，避免阻塞和死锁
        let context = stack.newBackgroundContext()
        performBatchSave(events: eventsToWrite, context: context, debugPrefix: "CoreDataDestination.deinit")
    }

    private func mapLevel(_ level: SwiftyBeaver.Level) -> LogEvent.Level {
        switch level {
        case .verbose: return .verbose
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        case .fault: return .fault
        @unknown default: return .debug
        }
    }

    /// 检查是否是设备锁定导致的错误
    private func isDeviceLockedError(_ error: NSError) -> Bool {
        return error.domain == NSCocoaErrorDomain &&
               (error.code == NSPersistentStoreCoordinatorLockingError ||
                error.userInfo.values.contains(where: { "\($0)".contains("device locked") }))
    }

    /// 取消防抖任务
    private func cancelDebounceTask() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    /// 批量保存日志事件
    private func performBatchSave(events: [LogEvent], context: NSManagedObjectContext, debugPrefix: String = "") {
        context.perform {
            for event in events {
                _ = LogEventEntity.create(from: event, in: context)
            }

            do {
                try context.save()
                #if DEBUG
                if !debugPrefix.isEmpty {
                    print("✅ \(debugPrefix): 已保存 \(events.count) 条待写入日志")
                }
                #endif
            } catch let error as NSError {
                if self.isDeviceLockedError(error) {
                    print("⚠️ \(debugPrefix): 设备锁定导致保存失败\(debugPrefix.isEmpty ? "" : "，已跳过 \(events.count) 条日志")")
                } else {
                    print("❌ \(debugPrefix): 保存日志失败: \(error)")
                }
            }
        }
    }

    deinit {
        flushPendingEvents()
    }
}
