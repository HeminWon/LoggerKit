//
//  SearchTypes.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - Search Field

/// Fields that can be searched
public enum SearchField: String, CaseIterable, Identifiable, Sendable {
    case message = "message"
    case fileName = "fileName"
    case function = "function"
    case context = "context"
    case thread = "thread"

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .message:
            return String(localized: "search_field_message", bundle: .module)
        case .fileName:
            return String(localized: "search_field_file", bundle: .module)
        case .function:
            return String(localized: "search_field_function", bundle: .module)
        case .context:
            return String(localized: "search_field_context", bundle: .module)
        case .thread:
            return String(localized: "search_field_thread", bundle: .module)
        }
    }

    public var icon: String {
        switch self {
        case .message: return "text.bubble"
        case .fileName: return "doc"
        case .function: return "function"
        case .context: return "square.stack.3d.up"
        case .thread: return "arrow.triangle.branch"
        }
    }
}

// MARK: - Search Result Item

/// Single search result item (suggestion)
public struct SearchResultItem: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let field: SearchField
    public let value: String
    public let matchCount: Int

    public init(field: SearchField, value: String, matchCount: Int) {
        self.field = field
        self.value = value
        self.matchCount = matchCount
    }

    // Equatable: 比较时忽略 id
    public static func == (lhs: SearchResultItem, rhs: SearchResultItem) -> Bool {
        return lhs.field == rhs.field &&
            lhs.value == rhs.value &&
            lhs.matchCount == rhs.matchCount
    }
}

// MARK: - Categorized Search Results

/// Categorized search results (suggestions grouped by field)
public struct CategorizedSearchResults: Equatable, Sendable {
    public var message: [SearchResultItem] = []
    public var fileName: [SearchResultItem] = []
    public var function: [SearchResultItem] = []
    public var context: [SearchResultItem] = []
    public var thread: [SearchResultItem] = []

    public var totalCount: Int {
        message.count + fileName.count + function.count + context.count + thread.count
    }

    public var isEmpty: Bool {
        totalCount == 0
    }

    public init() {}
}
