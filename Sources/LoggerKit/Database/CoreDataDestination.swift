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

    private let coreDataStack: CoreDataStack
    private var pendingEvents: [LogEvent] = []
    private let queue = DispatchQueue(label: "com.loggerkit.coredata", qos: .utility)

    // MARK: - 写入策略配置

    /// 批量写入大小
    private let batchSize: Int

    /// 防抖延迟（秒）
    private let debounceInterval: TimeInterval

    /// 立即写入的日志级别
    private let immediateFlushLevels: Set<LogEvent.Level>

    /// 防抖定时器
    private var debounceTimer: DispatchSourceTimer?

    // MARK: - 会话信息

    private let sessionId: String
    private let sessionStartTime: TimeInterval

    public init(
        sessionId: String,
        sessionStartTime: TimeInterval,
        coreDataStack: CoreDataStack = .shared,
        batchSize: Int = 50,
        debounceInterval: TimeInterval = 2.0,
        immediateFlushLevels: Set<LogEvent.Level> = [.error, .warning]
    ) {
        self.sessionId = sessionId
        self.sessionStartTime = sessionStartTime
        self.coreDataStack = coreDataStack
        self.batchSize = batchSize
        self.debounceInterval = debounceInterval
        self.immediateFlushLevels = immediateFlushLevels

        super.init()

        // 设置格式 (不需要格式化,直接存储结构化数据)
        self.format = ""
    }

    override public func send(
        _ level: SwiftyBeaver.Level,
        msg: String,
        thread: String,
        file: String,
        function: String,
        line: Int,
        context: Any? = nil
    ) -> String? {
        // 构造日志事件,包含会话信息
        let logEvent = LogEvent(
            thread: thread,
            function: function,
            line: line,
            file: file,
            timestamp: Date().timeIntervalSince1970,
            level: mapLevel(level),
            message: msg,
            context: (context as? String) ?? "",
            sessionId: sessionId,
            sessionStartTime: sessionStartTime
        )

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
        // 取消之前的防抖计时器
        debounceTimer?.cancel()

        // 创建新的防抖计时器
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.setEventHandler { [weak self] in
            self?.flushPendingEvents()
        }

        // 延迟执行
        timer.schedule(deadline: .now() + debounceInterval)
        timer.resume()

        self.debounceTimer = timer
    }

    public func flush() {
        queue.async { [weak self] in
            self?.flushPendingEvents()
        }
    }

    private func flushPendingEvents() {
        // 取消防抖定时器
        debounceTimer?.cancel()
        debounceTimer = nil

        guard !pendingEvents.isEmpty else { return }

        let eventsToWrite = pendingEvents
        pendingEvents.removeAll(keepingCapacity: true)

        // 后台上下文批量写入
        let context = coreDataStack.newBackgroundContext()

        context.perform {
            for event in eventsToWrite {
                _ = LogEventEntity.create(from: event, in: context)
            }

            do {
                try context.save()
            } catch {
                print("❌ CoreDataDestination: Failed to save logs: \(error)")
            }
        }
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

    deinit {
        // 取消防抖定时器
        debounceTimer?.cancel()
        debounceTimer = nil

        // 同步刷新，确保数据不丢失
        // 注意：必须使用 sync 而非 async，避免对象销毁后闭包才执行
        queue.sync {
            flushPendingEvents()
        }
    }
}
