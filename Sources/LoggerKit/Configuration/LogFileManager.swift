//
//  LogFileManager.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/21.
//

import Foundation

/// Log file generation policy
public enum FileGenerationPolicy: Sendable {
    case perLaunch                      // Create new file on each app launch
    case daily                          // Create new file daily, reuse within same day
    case reuseUntilRotation             // Reuse until rotation condition is met
    case session(maxAge: TimeInterval)  // Create new file after specified time
}

/// Log file manager
public final class LogFileManager: @unchecked Sendable {
    private let directory: URL
    private let generationPolicy: FileGenerationPolicy
    private let rotationPolicy: RotationPolicy
    private let maxFiles: Int
    private let fileManager = FileManager.default

    public init(
        directory: URL,
        generationPolicy: FileGenerationPolicy = .daily,
        rotationPolicy: RotationPolicy = .size(10 * 1024 * 1024),
        maxFiles: Int = 10
    ) {
        self.directory = directory
        self.generationPolicy = generationPolicy
        self.rotationPolicy = rotationPolicy
        self.maxFiles = maxFiles

        // Ensure directory exists
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// Get current log file URL based on generation policy
    public func currentLogFileURL() -> URL {
        // Perform rotation check first
        performRotationIfNeeded()

        switch generationPolicy {
        case .perLaunch:
            return createNewLogFile()

        case .daily:
            if let todayFile = findTodayLogFile() {
                return todayFile
            }
            return createNewLogFile()

        case .reuseUntilRotation:
            if let usableFile = findLatestUsableFile() {
                return usableFile
            }
            return createNewLogFile()

        case .session(let maxAge):
            if let recentFile = findRecentFile(maxAge: maxAge) {
                return recentFile
            }
            return createNewLogFile()
        }
    }

    /// Perform rotation if needed
    public func performRotationIfNeeded() {
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
                .filter { $0.pathExtension == "log" }

            for file in files {
                let manager = LogRotationManager(
                    fileURL: file,
                    policy: rotationPolicy,
                    maxFiles: maxFiles
                )

                if manager.shouldRotate() {
                    try manager.rotate()
                }
            }
        } catch {
            print("Log rotation check failed: \(error)")
        }
    }

    /// Cleanup old files
    public func cleanupOldFiles() {
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "log" }

            // Sort by creation date (newest first)
            let sortedFiles = try files.sorted {
                let date1 = try $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                let date2 = try $1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                return date1 > date2
            }

            // Delete files exceeding limit
            if sortedFiles.count > maxFiles {
                for file in sortedFiles[maxFiles...] {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Log cleanup failed: \(error)")
        }
    }

    // MARK: - Private Methods

    private func createNewLogFile() -> URL {
        let fileName = generateFileName()
        let fileURL = directory.appendingPathComponent(fileName)

        // Ensure file exists
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }

        return fileURL
    }

    private func generateFileName() -> String {
        return DateFormatters.fileNameFormatter.string(from: Date()) + ".log"
    }

    /// Find today's log file
    private func findTodayLogFile() -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else {
            return nil
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for file in files where file.pathExtension == "log" {
            if let values = try? file.resourceValues(forKeys: [.creationDateKey]),
               let creationDate = values.creationDate,
               calendar.isDate(creationDate, inSameDayAs: today) {
                return file
            }
        }

        return nil
    }

    /// Find latest usable file (not yet reached rotation condition)
    private func findLatestUsableFile() -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]) else {
            return nil
        }

        let logFiles = files.filter { $0.pathExtension == "log" }

        // Sort by creation date (newest first)
        let sortedFiles = logFiles.sorted {
            let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }

        // Find first file not yet reached rotation condition
        for file in sortedFiles {
            let manager = LogRotationManager(
                fileURL: file,
                policy: rotationPolicy,
                maxFiles: maxFiles
            )

            if !manager.shouldRotate() {
                return file
            }
        }

        return nil
    }

    /// Find recent file (within maxAge)
    private func findRecentFile(maxAge: TimeInterval) -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else {
            return nil
        }

        let logFiles = files.filter { $0.pathExtension == "log" }
        let cutoffDate = Date().addingTimeInterval(-maxAge)

        // Sort by creation date (newest first)
        let sortedFiles = logFiles.sorted {
            let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }

        // Find first file within time range
        if let latestFile = sortedFiles.first,
           let values = try? latestFile.resourceValues(forKeys: [.creationDateKey]),
           let creationDate = values.creationDate,
           creationDate > cutoffDate {
            return latestFile
        }

        return nil
    }
}
