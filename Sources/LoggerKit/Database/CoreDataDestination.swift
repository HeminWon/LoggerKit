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
    private let batchSize: Int
    private var pendingEvents: [LogEvent] = []
    private let queue = DispatchQueue(label: "com.loggerkit.coredata", qos: .utility)
    private var flushTimer: DispatchSourceTimer?

    // 会话信息
    private let sessionId: String
    private let sessionStartTime: TimeInterval

    public init(sessionId: String, sessionStartTime: TimeInterval, coreDataStack: CoreDataStack = .shared, batchSize: Int = 50) {
        self.sessionId = sessionId
        self.sessionStartTime = sessionStartTime
        self.coreDataStack = coreDataStack
        self.batchSize = batchSize

        super.init()

        // 设置格式 (不需要格式化,直接存储结构化数据)
        self.format = ""

        // 启动定时刷新 (每 5 秒刷新一次)
        setupFlushTimer()
    }

    private func setupFlushTimer() {
        // 使用 DispatchSourceTimer 替代 Foundation.Timer
        // 优势: 1) 不依赖 RunLoop, 避免引用循环 2) 更好的线程控制
        let timer = DispatchSource.makeTimerSource(queue: queue)

        timer.setEventHandler { [weak self] in
            self?.flushPendingEvents()
        }

        // 每 5 秒触发一次
        timer.schedule(deadline: .now() + 5.0, repeating: 5.0)
        timer.resume()

        self.flushTimer = timer
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

        // 达到批量大小时立即写入
        if pendingEvents.count >= batchSize {
            flushPendingEvents()
        }
    }

    public func flush() {
        queue.async { [weak self] in
            self?.flushPendingEvents()
        }
    }

    private func flushPendingEvents() {
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
        @unknown default: return .debug
        }
    }

    deinit {
        // 取消定时器并最后一次刷新,确保数据不丢失
        flushTimer?.cancel()
        flushTimer = nil
        flush()
    }
}
