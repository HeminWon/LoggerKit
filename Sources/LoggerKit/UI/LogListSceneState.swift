//
//  LogListSceneState.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/9/10.
//

import SwiftUI
import Combine

public class LogListSceneState: ObservableObject {
    @Published var logFiles: [URL] = []
    var prefix: String = ""
    var identifier: String = ""
    
    public init(prefix: String? = nil, identifier: String? = nil) {
        if let prefix = prefix {
            self.prefix = prefix
        } else {
            let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
            self.prefix = bundleId
        }
        if let identifier = identifier {
            self.identifier = identifier
        } else {
            let logIdentifier: String = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.logIdentifier) ?? String(UUID().uuidString.prefix(8))
            self.identifier = logIdentifier
            UserDefaults.standard.set(logIdentifier, forKey: Constants.UserDefaultsKeys.logIdentifier)
        }
    }
    
    func loadLogFiles() {
        let fileManager = FileManager.default
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logFiles = []
            return
        }
        let loggerKitDirectory = documentsURL.appendingPathComponent(Constants.logDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: loggerKitDirectory.path) {
            // 目录不存在，可能是还没有写过日志
            logFiles = []
            return
        }
        
        do {
            // 获取所有的文件，预取创建日期属性以提升性能
            let files = try fileManager.contentsOfDirectory(at: loggerKitDirectory, includingPropertiesForKeys: [.creationDateKey])
            // 过滤出以 .log 结尾的文件
            let logs = files.filter { $0.pathExtension == "log" }

            let sortedLogs = try logs.sorted {
                let date1 = try $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                let date2 = try $1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                return date1 > date2 // 新创建的在前面
            }

            logFiles = sortedLogs
        } catch {
            print("❌ Error loading log files: \(error.localizedDescription)")
            logFiles = []
        }
    }
    
    func deleteLogFile(at offsets: IndexSet) {
        let fileManager = FileManager.default

        for index in offsets {
            let logFileURL = logFiles[index]
            do {
                try fileManager.removeItem(at: logFileURL)
            } catch {
                print("Error deleting log file: \(error)")
            }
        }

        // 重新加载日志文件
        loadLogFiles()
    }
    
    func deleteLogFiles() {
        let fileManager = FileManager.default

        for logFile in logFiles {
            do {
                try fileManager.removeItem(at: logFile)
            } catch {
                print("Error deleting log file: \(error)")
            }
        }

        // 重新加载日志文件
        loadLogFiles()
    }
}


