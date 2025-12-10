//
//  LogEventEntity+CoreDataProperties.swift
//  LoggerKit
//
//  Created by LoggerKit on 2025/11/25.
//

import CoreData
import Foundation

extension LogEventEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LogEventEntity> {
        return NSFetchRequest<LogEventEntity>(entityName: "LogEventEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Double
    @NSManaged public var level: Int16
    @NSManaged public var message: String?
    @NSManaged public var thread: String?
    @NSManaged public var function: String?
    @NSManaged public var file: String?
    @NSManaged public var fileName: String?
    @NSManaged public var line: Int32
    @NSManaged public var context: String?
    @NSManaged public var date: String?
    @NSManaged public var hour: Int16
    @NSManaged public var sessionId: String
    @NSManaged public var sessionStartTime: Double
}

extension LogEventEntity: Identifiable {}
