//
//  ExportTypes.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - Export Format

/// 导出格式选项
public enum ExportFormat: String, Equatable, CaseIterable, Sendable {
    case log    // 纯文本日志格式
    // case json   // JSON 格式 (第三阶段扩展功能)

    public var displayName: String {
        switch self {
        case .log: return String(localized: "export_format_log", bundle: .loggerKit)
        }
    }
}

// MARK: - Export Feature Error

/// 导出功能错误
public enum ExportFeatureError: Error, LocalizedError, Equatable {
    case emptyData
    case exportError(ExportError)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .emptyData:
            return String(localized: "export_no_data", bundle: .loggerKit)
        case .exportError(let error):
            return error.errorDescription
        case .cancelled:
            return String(localized: "export_cancelled_by_user", bundle: .loggerKit)
        }
    }
}

// MARK: - Export Filter Options

/// 导出过滤选项 (用于导出筛选后的结果)
public struct ExportFilterOptions: Equatable, Sendable {
    public var levels: Set<LogEvent.Level> = []
    public var functions: Set<String> = []
    public var fileNames: Set<String> = []
    public var contexts: Set<String> = []
    public var threads: Set<String> = []
    public var messageKeywords: Set<String> = []
    public var sessionIds: Set<String> = []

    public init(
        levels: Set<LogEvent.Level> = [],
        functions: Set<String> = [],
        fileNames: Set<String> = [],
        contexts: Set<String> = [],
        threads: Set<String> = [],
        messageKeywords: Set<String> = [],
        sessionIds: Set<String> = []
    ) {
        self.levels = levels
        self.functions = functions
        self.fileNames = fileNames
        self.contexts = contexts
        self.threads = threads
        self.messageKeywords = messageKeywords
        self.sessionIds = sessionIds
    }

    /// 转换为 FilterFeature.State
    public func toFilterState() -> FilterFeature.State {
        var state = FilterFeature.State()

        if !isEmpty {
            state.selectedLevels = levels
            state.selectedFunctions = functions
            state.selectedFileNames = fileNames
            state.selectedContexts = contexts
            state.selectedThreads = threads
            state.selectedMessageKeywords = messageKeywords
            state.selectedSessionIds = sessionIds
        }

        return state
    }

    /// 是否为空
    public var isEmpty: Bool {
        levels.isEmpty && functions.isEmpty && fileNames.isEmpty &&
        contexts.isEmpty && threads.isEmpty && messageKeywords.isEmpty &&
        sessionIds.isEmpty
    }
}

// MARK: - FilterFeature.State Extension

extension FilterFeature.State {
    /// 转换为 ExportFilterOptions
    public func toExportFilterOptions() -> ExportFilterOptions {
        ExportFilterOptions(
            levels: selectedLevels,
            functions: selectedFunctions,
            fileNames: selectedFileNames,
            contexts: selectedContexts,
            threads: selectedThreads,
            messageKeywords: selectedMessageKeywords,
            sessionIds: selectedSessionIds
        )
    }
}
