//
//  LogEventEntity+CoreDataClass.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025/11/25.
//

import CoreData
import Foundation

@objc(LogEventEntity)
public class LogEventEntity: NSManagedObject {

    // 从 LogEvent 创建
    static func create(from event: LogEvent, in context: NSManagedObjectContext) -> LogEventEntity {
        let entity = LogEventEntity(context: context)
        entity.id = UUID()
        entity.timestamp = event.timestamp
        entity.level = Int16(event.level.rawValue)
        entity.message = event.message
        entity.thread = event.thread
        entity.function = event.function
        entity.file = event.file
        entity.line = Int32(event.line)
        entity.context = event.context
        entity.sessionId = event.sessionId
        entity.sessionStartTime = event.sessionStartTime

        // 提取文件名
        entity.fileName = event.fileName

        // 提取日期和小时
        let date = Date(timeIntervalSince1970: event.timestamp)
        entity.date = DateFormatters.dateOnlyFormatter.string(from: date)
        entity.hour = Int16(Calendar.current.component(.hour, from: date))

        return entity
    }

    // 转换为 LogEvent
    func toLogEvent() -> LogEvent {
        return LogEvent(
            thread: thread ?? "",
            function: function ?? "",
            line: Int(line),
            file: file ?? "",
            timestamp: timestamp,
            level: LogEvent.Level(rawValue: Int(level)) ?? .debug,
            message: message ?? "",
            context: context ?? "",
            sessionId: sessionId,
            sessionStartTime: sessionStartTime
        )
    }
}
