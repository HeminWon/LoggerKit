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
    private var flushTimer: Timer?

    public init(coreDataStack: CoreDataStack = .shared, batchSize: Int = 50) {
        self.coreDataStack = coreDataStack
        self.batchSize = batchSize

        super.init()

        // 设置格式 (不需要格式化,直接存储结构化数据)
        self.format = ""

        // 启动定时刷新 (每 5 秒刷新一次)
        setupFlushTimer()
    }

    private func setupFlushTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.flushTimer = Timer.scheduledTimer(
                withTimeInterval: 5.0,
                repeats: true
            ) { [weak self] _ in
                self?.flush()
            }
        }
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
        // 构造日志事件
        let logEvent = LogEvent(
            thread: thread,
            function: function,
            line: line,
            file: file,
            timestamp: Date().timeIntervalSince1970,
            level: mapLevel(level),
            message: msg,
            context: (context as? String) ?? ""
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
        flushTimer?.invalidate()
        flush()
    }
}
