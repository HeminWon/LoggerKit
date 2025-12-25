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

    /// Search State (Deep Log Search)
    public struct State: Equatable, Sendable {
        // MARK: - Search Input

        /// Current search text
        public var searchText: String = ""

        /// Selected search fields (message, function, fileName, etc.)
        public var searchFields: Set<SearchField> = [.message]

        // MARK: - Progressive Search State

        /// 当前搜索阶段
        public var searchPhase: SearchPhase = .idle

        /// Preview 的缓存结果
        public var previewResults: [LogEvent] = []

        /// Full Search 的完整结果（有序维护）
        public var fullSearchResults: [LogEvent] = []

        /// 搜索快照（搜索开始时创建，保证整个搜索过程的一致性）
        public var searchSnapshot: SearchSnapshot? = nil

        /// 搜索结果的最大限制
        public var searchResultsLimit: Int = 5000

        /// Preview 搜索的 session 数量（固定为 3，无论用户选了多少）
        public let previewSessionCount: Int = 3

        // MARK: - Filter State Sync (通过 Action 同步，不直接访问外部)

        /// 当前选中的 session IDs（从 FilterFeature 同步）
        public var selectedSessionIds: Set<String> = []

        /// 所有可用的 session IDs（从外部同步）
        public var allAvailableSessionIds: Set<String> = []

        // MARK: - Timing

        /// Typing 防抖延迟（毫秒）
        public let typingDebounceDelay: Int = 300

        // MARK: - New Result Tracking

        /// 新结果的 IDs（用于 UI 高亮，通过 Effect 定时清除）
        public var newResultIds: Set<String> = []

        // MARK: - Computed Properties

        /// 所有搜索结果（供 UI 展示，优化: O(N) 合并算法）
        public var allSearchResults: [LogEvent] {
            let result: [LogEvent]
            switch searchPhase {
            case .idle, .typing:
                result = []

            case .previewSearching, .previewCompleted:
                result = previewResults

            case .fullSearching, .completed:
                // 合并 preview 和 full search 结果 (O(N) 双指针合并)
                result = mergeOrderedResults(previewResults, fullSearchResults)

            case .failed, .tooManyResults, .cancelled:
                result = []
            }

            #if DEBUG
            print("🖼️ [State.allSearchResults] 被访问 - searchPhase: \(searchPhase), 返回数量: \(result.count)")
            #endif
            return result
        }

        /// 搜索进度百分比 (0.0 - 1.0)
        public var searchProgress: Double {
            guard case .fullSearching(let currentIndex, let total, _, _) = searchPhase else {
                return 0.0
            }
            return total > 0 ? Double(currentIndex + 1) / Double(total) : 0.0
        }

        /// 是否正在搜索
        public var isSearching: Bool {
            switch searchPhase {
            case .typing, .previewSearching, .fullSearching:
                return true
            default:
                return false
            }
        }

        /// 是否正在完整搜索
        public var isFullSearching: Bool {
            if case .fullSearching = searchPhase {
                return true
            }
            return false
        }

        /// 分类搜索结果（用于向后兼容旧 UI，优化: 单次遍历算法）
        public var categorizedResults: CategorizedSearchResults {
            #if DEBUG
            print("🖼️ [categorizedResults] 被访问")
            print("   - searchText: '\(searchText)'")
            print("   - searchPhase: \(searchPhase)")
            print("   - previewResults.count: \(previewResults.count)")
            print("   - allSearchResults.count: \(allSearchResults.count)")
            #endif

            let result = computeCategorizedResults(allResults: allSearchResults)

            #if DEBUG
            print("   → 返回结果 - totalCount: \(result.totalCount)")
            #endif
            return result
        }

        /// 计算分类搜索结果（单次遍历优化）
        private func computeCategorizedResults(allResults: [LogEvent]) -> CategorizedSearchResults {
            // 如果没有搜索文本或者搜索为空，返回空结果
            guard !searchText.isEmpty, !allResults.isEmpty else {
                #if DEBUG
                print("   → 返回空结果（searchText 为空或 allSearchResults 为空）")
                #endif
                return CategorizedSearchResults()
            }

            // 按搜索字段分组统计
            var functionItems: [SearchResultItem] = []
            var fileNameItems: [SearchResultItem] = []
            var contextItems: [SearchResultItem] = []
            var threadItems: [SearchResultItem] = []
            var messageItems: [SearchResultItem] = []

            let searchTextLowercased = searchText.lowercased()

            // 统计每个字段的匹配项（单次遍历）
            var functionCounts: [String: Int] = [:]
            var fileNameCounts: [String: Int] = [:]
            var contextCounts: [String: Int] = [:]
            var threadCounts: [String: Int] = [:]
            var messageCount: Int = 0

            for event in allResults {
                if searchFields.contains(.function) && event.function.lowercased().contains(searchTextLowercased) {
                    functionCounts[event.function, default: 0] += 1
                }
                if searchFields.contains(.fileName) && event.fileName.lowercased().contains(searchTextLowercased) {
                    fileNameCounts[event.fileName, default: 0] += 1
                }
                if searchFields.contains(.context) && event.context.lowercased().contains(searchTextLowercased) {
                    contextCounts[event.context, default: 0] += 1
                }
                if searchFields.contains(.thread) && event.thread.lowercased().contains(searchTextLowercased) {
                    threadCounts[event.thread, default: 0] += 1
                }
                if searchFields.contains(.message) && event.message.lowercased().contains(searchTextLowercased) {
                    messageCount += 1
                }
            }

            // 构建 SearchResultItem 数组
            functionItems = functionCounts.map { SearchResultItem(field: .function, value: $0.key, matchCount: $0.value) }
                .sorted(by: { $0.matchCount > $1.matchCount })
            fileNameItems = fileNameCounts.map { SearchResultItem(field: .fileName, value: $0.key, matchCount: $0.value) }
                .sorted(by: { $0.matchCount > $1.matchCount })
            contextItems = contextCounts.map { SearchResultItem(field: .context, value: $0.key, matchCount: $0.value) }
                .sorted(by: { $0.matchCount > $1.matchCount })
            threadItems = threadCounts.map { SearchResultItem(field: .thread, value: $0.key, matchCount: $0.value) }
                .sorted(by: { $0.matchCount > $1.matchCount })

            // 消息匹配只显示一个示例
            if messageCount > 0 {
                if let firstMatch = allResults.first(where: {
                    searchFields.contains(.message) && $0.message.lowercased().contains(searchTextLowercased)
                }) {
                    messageItems = [SearchResultItem(field: .message, value: firstMatch.message, matchCount: messageCount)]
                }
            }

            var result = CategorizedSearchResults()
            result.function = functionItems
            result.fileName = fileNameItems
            result.context = contextItems
            result.thread = threadItems
            result.message = messageItems

            #if DEBUG
            print("   → 返回分类结果:")
            print("      - function: \(functionItems.count)")
            print("      - fileName: \(fileNameItems.count)")
            print("      - context: \(contextItems.count)")
            print("      - thread: \(threadItems.count)")
            print("      - message: \(messageItems.count)")
            print("      - totalCount: \(result.totalCount)")
            #endif

            return result
        }

        // MARK: - Initializer

        public init() {}

        // MARK: - State Mutations

        /// 清空搜索结果
        public mutating func clearSearchResults() {
            previewResults = []
            fullSearchResults = []
            searchSnapshot = nil
            newResultIds = []
        }

        // MARK: - Private Helpers

        /// 合并两个有序数组（按时间倒序）
        private func mergeOrderedResults(
            _ preview: [LogEvent],
            _ full: [LogEvent]
        ) -> [LogEvent] {
            var result: [LogEvent] = []
            var i = 0, j = 0

            while i < preview.count && j < full.count {
                if preview[i].timestamp > full[j].timestamp {
                    result.append(preview[i])
                    i += 1
                } else {
                    result.append(full[j])
                    j += 1
                }
            }

            result.append(contentsOf: preview[i...])
            result.append(contentsOf: full[j...])

            return result
        }

        // MARK: - Equatable

        /// Custom Equatable implementation
        public static func == (lhs: State, rhs: State) -> Bool {
            lhs.searchText == rhs.searchText &&
            lhs.searchFields == rhs.searchFields &&
            lhs.searchPhase == rhs.searchPhase &&
            lhs.previewResults.count == rhs.previewResults.count &&
            lhs.fullSearchResults.count == rhs.fullSearchResults.count &&
            lhs.selectedSessionIds == rhs.selectedSessionIds &&
            lhs.allAvailableSessionIds == rhs.allAvailableSessionIds &&
            lhs.newResultIds == rhs.newResultIds
        }
    }

    // MARK: - Action

    /// Search Actions (Deep Log Search)
    public enum Action: Equatable {
        // MARK: - User Actions

        /// Update search text
        case updateSearchText(String)

        /// Toggle search field
        case toggleSearchField(SearchField)

        /// User requested full search (点击"搜索更多"按钮)
        case userRequestedFullSearch

        // MARK: - Filter State Sync

        /// Sync filter state (FilterFeature 状态变化时触发)
        case syncFilterState(selectedSessionIds: Set<String>, allAvailableSessionIds: Set<String>)

        // MARK: - Progressive Search Actions

        /// Start preview search (typing 防抖完成后触发)
        case startPreviewSearch

        /// Preview search completed
        case previewSearchCompleted(
            snapshot: SearchSnapshot,
            matches: [LogEvent],
            searchedSessions: Int,
            hasMoreSessions: Bool
        )

        /// Preview search failed
        case previewSearchFailed(Error)

        /// Update full search progress
        case updateFullSearchProgress(
            currentSessionIndex: Int,
            totalSessions: Int,
            matchCount: Int,
            scannedEvents: Int
        )

        /// Full search batch completed (每个 session 完成时)
        case fullSearchBatchCompleted(
            newMatches: [LogEvent],
            currentSessionIndex: Int,
            totalSessions: Int
        )

        /// Full search completed
        case fullSearchCompleted(searchedSessions: Int)

        /// Full search failed
        case fullSearchFailed(Error)

        /// Full search cancelled
        case fullSearchCancelled

        /// Search results exceeded
        case searchResultsExceeded(currentCount: Int, stage: SearchStage)

        /// Cancel all searches
        case cancelAllSearches

        /// Clear new result badges (定时触发)
        case clearNewResultBadges(Set<String>)

        // MARK: - Helper Enum

        public enum SearchStage: Equatable {
            case preview
            case fullSearch
        }

        // MARK: - Equatable

        /// Custom Equatable implementation
        public static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.updateSearchText(let l), .updateSearchText(let r)):
                return l == r
            case (.toggleSearchField(let l), .toggleSearchField(let r)):
                return l == r
            case (.userRequestedFullSearch, .userRequestedFullSearch):
                return true
            case (.syncFilterState(let l1, let l2), .syncFilterState(let r1, let r2)):
                return l1 == r1 && l2 == r2
            case (.startPreviewSearch, .startPreviewSearch):
                return true
            case (.previewSearchCompleted(let l0, let l1, let l2, let l3), .previewSearchCompleted(let r0, let r1, let r2, let r3)):
                return l0 == r0 && l1.count == r1.count && l2 == r2 && l3 == r3
            case (.previewSearchFailed, .previewSearchFailed):
                return true
            case (.updateFullSearchProgress(let l1, let l2, let l3, let l4), .updateFullSearchProgress(let r1, let r2, let r3, let r4)):
                return l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4
            case (.fullSearchBatchCompleted(let l1, let l2, let l3), .fullSearchBatchCompleted(let r1, let r2, let r3)):
                return l1.count == r1.count && l2 == r2 && l3 == r3
            case (.fullSearchCompleted(let l), .fullSearchCompleted(let r)):
                return l == r
            case (.fullSearchFailed, .fullSearchFailed):
                return true
            case (.fullSearchCancelled, .fullSearchCancelled):
                return true
            case (.searchResultsExceeded(let l1, let l2), .searchResultsExceeded(let r1, let r2)):
                return l1 == r1 && l2 == r2
            case (.cancelAllSearches, .cancelAllSearches):
                return true
            case (.clearNewResultBadges(let l), .clearNewResultBadges(let r)):
                return l == r
            default:
                return false
            }
        }
    }

    // MARK: - Reducer

    /// Search Reducer (Deep Log Search - Database-based)
    public struct Reducer: ReducerProtocol {
        public typealias State = SearchFeature.State
        public typealias Action = SearchFeature.Action

        // 注入 DataLoader 依赖
        let dataLoader: LogDataLoaderProtocol

        public init(dataLoader: LogDataLoaderProtocol) {
            self.dataLoader = dataLoader
        }

        // Cancellation IDs
        private enum CancellationId: Hashable {
            case typingDebounce
            case previewSearch
            case fullSearch
            case newResultBadgeTimer
        }

        public func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
            switch action {
            // MARK: - User Actions

            case .updateSearchText(let text):
                let oldText = state.searchText
                #if DEBUG
                print("🔍 [SearchFeature] updateSearchText: '\(oldText)' -> '\(text)' (相同: \(oldText == text))")
                #endif

                // 如果文本没有变化，直接返回
                guard text != oldText else {
                    #if DEBUG
                    print("⚠️ [SearchFeature] 文本未变化，忽略此次更新")
                    #endif
                    return .none
                }

                state.searchText = text

                if text.isEmpty {
                    #if DEBUG
                    print("🔍 [SearchFeature] 搜索文本为空，清空搜索")
                    #endif
                    // 清空搜索
                    state.searchPhase = .idle
                    state.clearSearchResults()
                    return .merge(
                        .cancel(id: CancellationId.previewSearch),
                        .cancel(id: CancellationId.fullSearch),
                        .cancel(id: CancellationId.newResultBadgeTimer)
                    )
                }

                // 清空旧的搜索结果
                if state.searchPhase != .idle {
                    state.clearSearchResults()
                }

                // 直接开始搜索（UI 层已经做了防抖）
                #if DEBUG
                print("🔍 [SearchFeature] 立即开始 preview search（UI 层已防抖）")
                #endif
                state.searchPhase = .previewSearching(sessionCount: state.previewSessionCount)

                // 取消不相关的搜索任务
                // 注意：不需要 cancel previewSearch，因为 handlePreviewSearch 内部的 .stream 会自动处理
                return .merge(
                    .cancel(id: CancellationId.fullSearch),
                    .cancel(id: CancellationId.newResultBadgeTimer),
                    handlePreviewSearch(state: state)
                )

            case .toggleSearchField(let field):
                if state.searchFields.contains(field) {
                    // 至少保留一个字段
                    if state.searchFields.count > 1 {
                        state.searchFields.remove(field)
                    }
                } else {
                    state.searchFields.insert(field)
                }

                // 重新执行搜索（如果正在搜索）
                if !state.searchText.isEmpty {
                    switch state.searchPhase {
                    case .previewCompleted, .completed:
                        // 清空旧结果
                        state.clearSearchResults()
                        // 重新触发 Preview
                        return .send(.startPreviewSearch)

                    case .previewSearching, .fullSearching:
                        // 正在搜索中，取消并重新开始
                        return .merge(
                            .task { .cancelAllSearches },
                            .task {
                                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                                return .startPreviewSearch
                            }
                        )

                    default:
                        return .none
                    }
                }

                return .none

            case .userRequestedFullSearch:
                #if DEBUG
                print("🔍 [SearchFeature] userRequestedFullSearch 触发")
                #endif
                guard let snapshot = state.searchSnapshot else {
                    #if DEBUG
                    print("⚠️ [SearchFeature] searchSnapshot 为 nil，无法执行 full search")
                    #endif
                    return .none
                }

                guard !snapshot.fullSearchSessions.isEmpty else {
                    #if DEBUG
                    print("⚠️ [SearchFeature] 没有更多 session 需要搜索")
                    #endif
                    // 没有更多 session 需要搜索
                    return .none
                }

                #if DEBUG
                print("🔍 [SearchFeature] 开始 full search - 需要搜索 \(snapshot.fullSearchSessions.count) 个 sessions")
                #endif
                state.searchPhase = .fullSearching(
                    currentSessionIndex: 0,
                    totalSessions: snapshot.fullSearchSessions.count,
                    matchCount: state.previewResults.count,
                    scannedEvents: 0
                )

                return handleFullSearch(state: state, snapshot: snapshot)

            // MARK: - Filter State Sync

            case .syncFilterState(let selectedIds, let allIds):
                #if DEBUG
                print("🔍 [SearchFeature] syncFilterState - selected: \(selectedIds.count), all: \(allIds.count)")
                #endif
                state.selectedSessionIds = selectedIds
                state.allAvailableSessionIds = allIds

                // 如果正在搜索，且 filter 发生了重大变化，取消当前搜索
                if state.isSearching {
                    let snapshotIds = state.searchSnapshot?.selectedSessionIds ?? []
                    if snapshotIds != selectedIds {
                        #if DEBUG
                        print("⚠️ [SearchFeature] Filter 发生变化，取消当前搜索")
                        #endif
                        return .send(.cancelAllSearches)
                    }
                }

                return .none

            // MARK: - Preview Search

            case .startPreviewSearch:
                #if DEBUG
                print("🔍 [SearchFeature] startPreviewSearch 触发")
                #endif
                guard !state.searchText.isEmpty else {
                    #if DEBUG
                    print("⚠️ [SearchFeature] 搜索文本为空，忽略 startPreviewSearch")
                    #endif
                    return .none
                }

                #if DEBUG
                print("🔍 [SearchFeature] 进入 previewSearching 状态，预览 session 数: \(state.previewSessionCount)")
                #endif
                state.searchPhase = .previewSearching(sessionCount: state.previewSessionCount)

                return handlePreviewSearch(state: state)

            case .previewSearchCompleted(let snapshot, let matches, let sessions, let hasMore):
                #if DEBUG
                print("✅ [SearchFeature] previewSearchCompleted - 匹配数: \(matches.count), 已搜索 sessions: \(sessions), 还有更多: \(hasMore)")
                print("🔍 [SearchFeature] Snapshot - preview sessions: \(snapshot.previewSessions.count), full search sessions: \(snapshot.fullSearchSessions.count)")
                print("🔍 [SearchFeature] 当前 searchText: '\(state.searchText)'")
                print("🔍 [SearchFeature] Snapshot searchText: '\(snapshot.searchText)'")
                print("🔍 [SearchFeature] matches 详情: \(matches.map { "\($0.message.prefix(50))..." })")
                #endif

                state.searchSnapshot = snapshot
                state.previewResults = matches
                let newPhase: SearchPhase = .previewCompleted(
                    matchCount: matches.count,
                    searchedSessions: sessions,
                    hasMoreSessions: hasMore
                )
                #if DEBUG
                print("🔍 [SearchFeature] 更新 searchPhase: \(state.searchPhase) -> \(newPhase)")
                #endif
                state.searchPhase = newPhase
                #if DEBUG
                print("✅ [SearchFeature] State 更新完成:")
                print("   - previewResults.count: \(state.previewResults.count)")
                print("   - searchPhase: \(state.searchPhase)")
                print("   - searchText: '\(state.searchText)'")
                print("   - allSearchResults.count: \(state.allSearchResults.count)")

                // 测试：手动调用 categorizedResults 看看会发生什么
                let testResults = state.categorizedResults
                print("🧪 [测试] categorizedResults.totalCount: \(testResults.totalCount)")
                #endif

                return .none

            case .previewSearchFailed(let error):
                #if DEBUG
                print("❌ [SearchFeature] previewSearchFailed - 错误: \(error.localizedDescription)")
                #endif
                state.searchPhase = .failed(message: error.localizedDescription)
                state.searchSnapshot = nil
                return .none

            // MARK: - Full Search

            case .updateFullSearchProgress(let index, let total, let matches, let scanned):
                state.searchPhase = .fullSearching(
                    currentSessionIndex: index,
                    totalSessions: total,
                    matchCount: matches,
                    scannedEvents: scanned
                )
                return .none

            case .fullSearchBatchCompleted(let newMatches, let index, let total):
                // 按时间倒序插入
                state.fullSearchResults = insertOrderedMatches(
                    existing: state.fullSearchResults,
                    new: newMatches
                )

                // 标记新结果
                let newIds = Set(newMatches.map { $0.id.uuidString })
                state.newResultIds.formUnion(newIds)

                // 更新进度
                let totalMatches = state.previewResults.count + state.fullSearchResults.count

                // 检查是否超过限制
                if totalMatches > state.searchResultsLimit {
                    return .merge(
                        .send(.searchResultsExceeded(currentCount: totalMatches, stage: .fullSearch)),
                        .cancel(id: CancellationId.fullSearch)
                    )
                }

                state.searchPhase = .fullSearching(
                    currentSessionIndex: index,
                    totalSessions: total,
                    matchCount: totalMatches,
                    scannedEvents: state.fullSearchResults.count
                )

                // 使用 Effect 定时清除新标记
                return .task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒
                    return .clearNewResultBadges(newIds)
                }

            case .fullSearchCompleted(let sessions):
                let totalMatches = state.previewResults.count + state.fullSearchResults.count
                state.searchPhase = .completed(
                    totalMatches: totalMatches,
                    searchedSessions: (state.searchSnapshot?.previewSessions.count ?? 0) + sessions
                )
                return .none

            case .fullSearchFailed(let error):
                state.searchPhase = .failed(message: error.localizedDescription)
                state.searchSnapshot = nil
                return .none

            case .fullSearchCancelled:
                state.searchPhase = .cancelled
                state.searchSnapshot = nil
                return .none

            case .searchResultsExceeded(let count, _):
                state.searchPhase = .tooManyResults(currentCount: count, limit: state.searchResultsLimit)
                state.clearSearchResults()
                return .cancel(id: CancellationId.fullSearch)

            case .cancelAllSearches:
                state.searchPhase = .cancelled
                state.searchSnapshot = nil
                return .merge(
                    .cancel(id: CancellationId.typingDebounce),
                    .cancel(id: CancellationId.previewSearch),
                    .cancel(id: CancellationId.fullSearch),
                    .cancel(id: CancellationId.newResultBadgeTimer)
                )

            case .clearNewResultBadges(let ids):
                state.newResultIds.subtract(ids)
                return .none
            }
        }

        // MARK: - Private Handlers

        private func handlePreviewSearch(state: State) -> Effect<Action> {
            let searchText = state.searchText
            let searchFields = state.searchFields
            let selectedSessionIds = state.selectedSessionIds
            let allAvailableSessionIds = state.allAvailableSessionIds
            let previewSessionCount = state.previewSessionCount
            let resultsLimit = state.searchResultsLimit

            #if DEBUG
            print("🔍 [SearchFeature] handlePreviewSearch 开始")
            print("🔍 [SearchFeature] - searchText: '\(searchText)'")
            print("🔍 [SearchFeature] - searchFields: \(searchFields)")
            print("🔍 [SearchFeature] - selectedSessionIds: \(selectedSessionIds.count) 个")
            print("🔍 [SearchFeature] - allAvailableSessionIds: \(allAvailableSessionIds.count) 个")
            print("🔍 [SearchFeature] - previewSessionCount: \(previewSessionCount)")
            print("🔍 [SearchFeature] - resultsLimit: \(resultsLimit)")
            #endif

            return .stream(id: CancellationId.previewSearch) { [dataLoader = self.dataLoader] in
                AsyncStream { continuation in
                    Task { @MainActor in
                        do {
                            #if DEBUG
                            print("🔍 [SearchFeature] Task 开始执行 (MainActor)")
                            // 1. 创建搜索快照
                            print("🔍 [SearchFeature] 步骤 1: 创建搜索快照...")
                            #endif
                            let snapshot = try await createSearchSnapshot(
                                dataLoader: dataLoader,
                                searchText: searchText,
                                searchFields: searchFields,
                                selectedSessionIds: selectedSessionIds,
                                allAvailableSessionIds: allAvailableSessionIds,
                                previewSessionCount: previewSessionCount
                            )
                            #if DEBUG
                            print("✅ [SearchFeature] 快照创建完成 - preview sessions: \(snapshot.previewSessions.count), full search sessions: \(snapshot.fullSearchSessions.count)")

                            // 2. 查询 Preview sessions 的所有日志
                            print("🔍 [SearchFeature] 步骤 2: 查询 Preview sessions 的日志...")
                            #endif
                            let previewSessionIds = Set(snapshot.previewSessions.map { $0.id })
                            #if DEBUG
                            print("🔍 [SearchFeature] - 查询 session IDs: \(previewSessionIds)")
                            #endif
                            let matches = try await dataLoader.searchEvents(
                                sessionIds: previewSessionIds,
                                searchText: searchText,
                                searchFields: searchFields,
                                limit: resultsLimit
                            )
                            #if DEBUG
                            print("✅ [SearchFeature] 查询完成 - 找到 \(matches.count) 条匹配")
                            #endif

                            // 3. 检查结果数量
                            if matches.count > resultsLimit {
                                #if DEBUG
                                print("⚠️ [SearchFeature] 结果超过限制: \(matches.count) > \(resultsLimit)")
                                #endif
                                continuation.yield(.searchResultsExceeded(currentCount: matches.count, stage: .preview))
                                continuation.finish()
                                return
                            }

                            // 4. 完成 Preview
                            #if DEBUG
                            print("🔍 [SearchFeature] 步骤 4: 发送 previewSearchCompleted")
                            #endif
                            continuation.yield(.previewSearchCompleted(
                                snapshot: snapshot,
                                matches: matches,
                                searchedSessions: snapshot.previewSessions.count,
                                hasMoreSessions: !snapshot.fullSearchSessions.isEmpty
                            ))
                            continuation.finish()
                            #if DEBUG
                            print("✅ [SearchFeature] Preview Search 流程完成")
                            #endif

                        } catch {
                            #if DEBUG
                            print("❌ [SearchFeature] Preview Search 失败: \(error)")
                            #endif
                            continuation.yield(.previewSearchFailed(error))
                            continuation.finish()
                        }
                    }
                }
            }
        }

        private func handleFullSearch(state: State, snapshot: SearchSnapshot) -> Effect<Action> {
            let resultsLimit = state.searchResultsLimit
            let alreadyFoundCount = state.previewResults.count

            return .stream(id: CancellationId.fullSearch) { [dataLoader = self.dataLoader] in
                AsyncStream { continuation in
                    Task { @MainActor in
                        do {
                            let totalSessions = snapshot.fullSearchSessions.count

                            // 逐个 session 搜索
                            for (index, session) in snapshot.fullSearchSessions.enumerated() {
                                // 检查取消
                                try Task.checkCancellation()

                                // 更新进度
                                continuation.yield(.updateFullSearchProgress(
                                    currentSessionIndex: index,
                                    totalSessions: totalSessions,
                                    matchCount: alreadyFoundCount,
                                    scannedEvents: 0
                                ))

                                // 使用数据库搜索
                                let sessionMatches = try await dataLoader.searchEvents(
                                    sessionIds: [session.id],
                                    searchText: snapshot.searchText,
                                    searchFields: snapshot.searchFields,
                                    limit: resultsLimit
                                )

                                // 每个 session 完成后立即更新
                                continuation.yield(.fullSearchBatchCompleted(
                                    newMatches: sessionMatches,
                                    currentSessionIndex: index,
                                    totalSessions: totalSessions
                                ))
                            }

                            // 全部完成
                            continuation.yield(.fullSearchCompleted(searchedSessions: totalSessions))
                            continuation.finish()

                        } catch is CancellationError {
                            continuation.yield(.fullSearchCancelled)
                            continuation.finish()
                        } catch {
                            continuation.yield(.fullSearchFailed(error))
                            continuation.finish()
                        }
                    }
                }
            }
        }

        // MARK: - Helper Methods

        /// 创建搜索快照
        private func createSearchSnapshot(
            dataLoader: LogDataLoaderProtocol,
            searchText: String,
            searchFields: Set<SearchField>,
            selectedSessionIds: Set<String>,
            allAvailableSessionIds: Set<String>,
            previewSessionCount: Int
        ) async throws -> SearchSnapshot {
            #if DEBUG
            print("🔍 [createSearchSnapshot] 开始创建快照")
            print("🔍 [createSearchSnapshot] - selectedSessionIds: \(selectedSessionIds)")
            print("🔍 [createSearchSnapshot] - allAvailableSessionIds: \(allAvailableSessionIds)")
            #endif

            // 确定搜索范围
            let searchSessionIds: Set<String>
            if selectedSessionIds.isEmpty || selectedSessionIds.count == allAvailableSessionIds.count {
                // 未选或全选 → 搜索所有
                searchSessionIds = allAvailableSessionIds
                #if DEBUG
                print("🔍 [createSearchSnapshot] 使用所有 sessions: \(searchSessionIds.count) 个")
                #endif
            } else {
                // 选中特定 session → 只搜索这些
                searchSessionIds = selectedSessionIds
                #if DEBUG
                print("🔍 [createSearchSnapshot] 使用选中的 sessions: \(searchSessionIds.count) 个")
                #endif
            }

            // 获取所有 sessions（按时间倒序）
            #if DEBUG
            print("🔍 [createSearchSnapshot] 调用 dataLoader.getSessions...")
            #endif
            let allSessions = try await dataLoader.getSessions(
                sessionIds: searchSessionIds,
                sortOrder: .timeDescending
            )
            #if DEBUG
            print("✅ [createSearchSnapshot] 获取到 \(allSessions.count) 个 sessions")
            #endif

            // Preview 始终只取最新 N 个
            let previewSessions = Array(allSessions.prefix(previewSessionCount))
            let fullSearchSessions = Array(allSessions.dropFirst(previewSessionCount))

            return SearchSnapshot(
                searchText: searchText,
                searchFields: searchFields,
                selectedSessionIds: selectedSessionIds,
                allAvailableSessionIds: allAvailableSessionIds,
                allSessions: allSessions,
                previewSessions: previewSessions,
                fullSearchSessions: fullSearchSessions,
                createdAt: Date()
            )
        }

        /// 按时间倒序合并新结果（优化: O(N²) → O(N)）
        private func insertOrderedMatches(
            existing: [LogEvent],
            new: [LogEvent]
        ) -> [LogEvent] {
            // 先对新结果排序
            let sortedNew = new.sorted { $0.timestamp > $1.timestamp }

            // 预分配容量，避免多次重新分配
            var result: [LogEvent] = []
            result.reserveCapacity(existing.count + sortedNew.count)

            // 双指针合并（假设 existing 已经按时间倒序排列）
            var i = 0, j = 0
            while i < existing.count && j < sortedNew.count {
                if existing[i].timestamp > sortedNew[j].timestamp {
                    result.append(existing[i])
                    i += 1
                } else {
                    result.append(sortedNew[j])
                    j += 1
                }
            }

            // 添加剩余元素
            result.append(contentsOf: existing[i...])
            result.append(contentsOf: sortedNew[j...])

            return result
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
