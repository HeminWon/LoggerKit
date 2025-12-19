//
//  SearchFeature.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - SearchFeature

/// Search Feature (搜索建议功能)
///
/// 这是一个独立的 TCA Feature，负责处理搜索建议功能:
/// - 在内存中的 allEventsForSearchPreview (最近10000条日志) 上进行客户端搜索
/// - 返回搜索建议 (SearchResultItem)，用于帮助用户快速添加到筛选器
/// - 结果分类为: message, fileName, function, context, thread
///
/// 设计原则:
/// - 独立性: 拥有自己的 State、Action、Reducer
/// - 可复用性: 可在多个场景使用
/// - 功能保持: 保持现有的搜索建议功能不变
public struct SearchFeature {

    // MARK: - State

    /// Search State
    public struct State: Equatable, Sendable {
        // MARK: - Search Input

        /// Current search text
        public var searchText: String = ""

        /// Selected search fields (message, function, fileName, etc.)
        public var searchFields: Set<SearchField> = [.message]

        // MARK: - Search Results (搜索建议)

        /// Categorized search results (建议列表)
        public var cachedSearchResults: CategorizedSearchResults = .init()

        // MARK: - Preview Data (用于内存搜索)

        /// All events for search preview (limited to recent 10000)
        public var allEventsForSearchPreview: [LogEvent] = []

        // MARK: - Computed Properties

        /// Whether search is active (has text)
        public var isSearchActive: Bool {
            !searchText.isEmpty
        }

        /// Total results count
        public var totalResultsCount: Int {
            cachedSearchResults.totalCount
        }

        /// Whether search can be executed (has text, fields, and data)
        public var canExecuteSearch: Bool {
            !searchText.isEmpty && !searchFields.isEmpty && !allEventsForSearchPreview.isEmpty
        }

        // MARK: - Initializer

        public init() {}

        // MARK: - State Mutations

        /// Clear search results
        public mutating func clearResults() {
            cachedSearchResults = .init()
        }

        // MARK: - Equatable

        /// Custom Equatable implementation (比较 count 而不是内容)
        public static func == (lhs: State, rhs: State) -> Bool {
            lhs.searchText == rhs.searchText &&
            lhs.searchFields == rhs.searchFields &&
            lhs.cachedSearchResults == rhs.cachedSearchResults &&
            lhs.allEventsForSearchPreview.count == rhs.allEventsForSearchPreview.count
        }
    }

    // MARK: - Action

    /// Search Actions
    public enum Action: Equatable {
        // MARK: - User Actions

        /// Update search text
        case updateSearchText(String)

        /// Toggle search field
        case toggleSearchField(SearchField)

        /// Execute search (在内存中搜索)
        case executeSearch

        /// All events for search preview loaded
        case allEventsLoaded([LogEvent])

        // MARK: - System Feedback

        /// Search completed with results
        case searchCompleted(CategorizedSearchResults)

        // MARK: - Equatable

        /// Custom Equatable implementation (比较 LogEvent count 而不是内容)
        public static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.updateSearchText(let l), .updateSearchText(let r)):
                return l == r
            case (.toggleSearchField(let l), .toggleSearchField(let r)):
                return l == r
            case (.executeSearch, .executeSearch):
                return true
            case (.allEventsLoaded(let l), .allEventsLoaded(let r)):
                return l.count == r.count
            case (.searchCompleted(let l), .searchCompleted(let r)):
                return l == r
            default:
                return false
            }
        }
    }

    // MARK: - Reducer

    /// Search Reducer (在内存中搜索，返回建议)
    public struct Reducer: ReducerProtocol {
        public typealias State = SearchFeature.State
        public typealias Action = SearchFeature.Action

        public init() {}

        public func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            // MARK: - Update Search Input

            case .updateSearchText(let text):
                state.searchText = text

                // Clear results if text is empty
                if text.isEmpty {
                    state.clearResults()
                    return .none
                }

                // Trigger search if we have preview data
                print("🔵 [SearchFeature] updateSearchText: '\(text)', dataReady=\(!state.allEventsForSearchPreview.isEmpty), count=\(state.allEventsForSearchPreview.count)")
                if !state.allEventsForSearchPreview.isEmpty {
                    return .send(.executeSearch)
                }

                return .none

            case .toggleSearchField(let field):
                if state.searchFields.contains(field) {
                    // Keep at least one field
                    if state.searchFields.count > 1 {
                        state.searchFields.remove(field)
                    }
                } else {
                    state.searchFields.insert(field)
                }

                // Re-execute search if active
                if !state.searchText.isEmpty && !state.allEventsForSearchPreview.isEmpty {
                    return .send(.executeSearch)
                }

                return .none

            // MARK: - Execute Search (在内存中搜索)

            case .executeSearch:
                return handleExecuteSearch(state: state)

            case .searchCompleted(let results):
                state.cachedSearchResults = results
                return .none

            case .allEventsLoaded(let events):
                state.allEventsForSearchPreview = events
                print("🟢 [SearchFeature] allEventsLoaded: \(events.count) events, currentSearchText='\(state.searchText)'")
                // Trigger search if we have search text
                if !state.searchText.isEmpty {
                    print("🔵 [SearchFeature] Auto-triggering search after data load")
                    return .send(.executeSearch)
                }
                return .none
            }
        }

        // MARK: - Private Handlers

        private func handleExecuteSearch(state: State) -> Effect<Action> {
            guard state.canExecuteSearch else {
                return .task { .searchCompleted(.init()) }
            }

            let searchText = state.searchText
            let searchFields = state.searchFields
            let allEvents = state.allEventsForSearchPreview

            return .task {
                let results = await performSearch(
                    searchText: searchText,
                    searchFields: searchFields,
                    events: allEvents
                )
                return .searchCompleted(results)
            }
        }

        /// Perform in-memory search (返回搜索建议)
        private func performSearch(
            searchText: String,
            searchFields: Set<SearchField>,
            events: [LogEvent]
        ) async -> CategorizedSearchResults {
            var results = CategorizedSearchResults()
            let lowercasedSearch = searchText.lowercased()

            print("🔎 [SearchFeature] Searching: '\(searchText)' in \(events.count) events, fields: \(searchFields)")

            // Sets for deduplication
            var messageSet = Set<String>()
            var fileNameSet = Set<String>()
            var functionSet = Set<String>()
            var contextSet = Set<String>()
            var threadSet = Set<String>()

            // Single pass to collect all matches
            for event in events {
                // Message matches (limit to first 5 unique messages)
                if searchFields.contains(.message) && results.message.count < 5 {
                    if event.message.lowercased().contains(lowercasedSearch) {
                        if !messageSet.contains(event.message) {
                            messageSet.insert(event.message)
                            results.message.append(
                                SearchResultItem(field: .message, value: event.message, matchCount: 1)
                            )
                        }
                    }
                }

                // File name matches
                if searchFields.contains(.fileName) {
                    if event.fileName.lowercased().contains(lowercasedSearch) {
                        fileNameSet.insert(event.fileName)
                    }
                }

                // Function matches
                if searchFields.contains(.function) {
                    if event.function.lowercased().contains(lowercasedSearch) {
                        functionSet.insert(event.function)
                    }
                }

                // Context matches
                if searchFields.contains(.context) {
                    if !event.context.isEmpty && event.context.lowercased().contains(lowercasedSearch) {
                        contextSet.insert(event.context)
                    }
                }

                // Thread matches
                if searchFields.contains(.thread) {
                    if !event.thread.isEmpty && event.thread.lowercased().contains(lowercasedSearch) {
                        threadSet.insert(event.thread)
                    }
                }
            }

            // Build results for other fields (sorted)
            results.fileName = fileNameSet.sorted().map { fileName in
                SearchResultItem(field: .fileName, value: fileName, matchCount: 1)
            }

            results.function = functionSet.sorted().map { function in
                SearchResultItem(field: .function, value: function, matchCount: 1)
            }

            results.context = contextSet.sorted().map { context in
                SearchResultItem(field: .context, value: context, matchCount: 1)
            }

            results.thread = threadSet.sorted().map { thread in
                SearchResultItem(field: .thread, value: thread, matchCount: 1)
            }

            print("📊 [SearchFeature] Results: message=\(results.message.count), fileName=\(results.fileName.count), function=\(results.function.count), context=\(results.context.count), thread=\(results.thread.count)")

            return results
        }
    }
}

// MARK: - Effect Extension

extension Effect where Action == SearchFeature.Action {
    /// Send an action immediately
    static func send(_ action: Action) -> Effect<Action> {
        return .task { action }
    }
}
