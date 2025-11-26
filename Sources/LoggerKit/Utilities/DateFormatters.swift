//
//  DateFormatters.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/21.
//

import Foundation

/// DateFormatter 单例池，避免重复创建
public enum DateFormatters {
    /// 文件名格式：20250915-151628.474+0800
    public static let fileNameFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyyMMdd-HHmmss.SSSZ"
        return df
    }()

    /// 日志显示格式：yyyy-MM-dd HH:mm:ss.SSS
    public static let displayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return df
    }()

    /// 仅日期格式：yyyy-MM-dd (用于 CoreData 日期索引)
    public static let dateOnlyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
