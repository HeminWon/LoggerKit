//
//  FilterTypes.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - Filter Error

/// Filter-related errors
public enum FilterError: Error, LocalizedError, Equatable {
    case loadingOptionsFailed
    case emptyFilterResult

    public var errorDescription: String? {
        switch self {
        case .loadingOptionsFailed:
            return String(localized: "filter_load_options_failed", bundle: .loggerKit)
        case .emptyFilterResult:
            return String(localized: "filter_empty_result", bundle: .loggerKit)
        }
    }
}

// MARK: - Filter Statistics

/// Filter statistics (用于 UI 展示)
public struct FilterStatistics: Equatable, Sendable {
    /// Total number of logs before filtering
    public let totalCount: Int

    /// Number of logs after filtering
    public let filteredCount: Int

    /// Filter efficiency (0.0 to 1.0)
    public var efficiency: Double {
        guard totalCount > 0 else { return 0 }
        return Double(filteredCount) / Double(totalCount)
    }

    public init(totalCount: Int, filteredCount: Int) {
        self.totalCount = totalCount
        self.filteredCount = filteredCount
    }
}
