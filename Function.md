This document describes LoggerKit core capabilities and provides a post-refactor functional validation checklist.

### List Rendering
- Pagination: thread-safe offset/limit queries
- Real-time stats: background aggregation for level, function, file, context, thread, and session
- Smart cache: prefer aggregated stats and search preview data to reduce repeated queries

### Search
- **Data source**: load up to 10,000 records from database for preview cache, independent from currently loaded list items
- **Multi-field search**: message, file name, function, context, and thread; keep at least one active field
- **Realtime debounce**: 100ms debounce for responsive interactions
- **Background execution**: asynchronous search runs off the main thread
- **Categorized results**: return grouped results in 5 dimensions with de-duplicated counts
- **Smart limits**: message dimension returns top 5; other dimensions return all matches

### Filtering
- **7-dimension filtering**:
  - **Level** (`selectedLevels`): exact match, multi-select, default all selected (verbose/debug/info/warning/error)
  - **Function** (`selectedFunctions`): exact match, multi-select, `IN` predicate
  - **File name** (`selectedFileNames`): exact match, multi-select, `IN` predicate
  - **Context** (`selectedContexts`): exact match, multi-select, `IN` predicate
  - **Thread** (`selectedThreads`): exact match, multi-select, `IN` predicate
  - **Message keywords** (`selectedMessageKeywords`): fuzzy match via `CONTAINS[cd]`, multi-keyword OR logic
  - **Session** (`selectedSessionIds`): exact match, multi-select, `IN` predicate; empty means all sessions, and at least one session must be selected when filtering by session
- **Set operations**: add/remove/toggle filter values
- **Active count**: show number of active filters
- **Quick reset**: one-click clear all filters; levels reset to default all-selected
- **Debounced callback**: trigger `onFilterChanged` with 100ms debounce to avoid frequent queries

### Export
- **Streaming export**: batched query + append write, 1,000 records per batch, peak memory < 10MB, supports million-scale exports
- **LOG format**:
  - **Without thread**: `{datetime} [{first8SessionId}] [{level}] - ({function} at {file}:{line}) - {message}`
  - **With thread**: `{datetime} [{first8SessionId}] [{level}] <{context}> {thread} - ({function} at {file}:{line}) - {message}`
  - Datetime format: from `DateFormatters.displayFormatter`
  - Encoding: UTF-8, extension: `.log`
- **Smart filename**: `logs_{session}_{date}.log` (for example `logs_all_20251217.log` or `logs_abc12345_20251217.log`)
- **Data source strategy**: choose optimal source based on loaded data volume and active filters
- **Progress callback**: report written count and total count in real time

### Deletion
- **Two-level deletion strategy**:
  - **Delete all**: remove all logs in one action
  - **Delete by session**: remove selected sessions (single/multi-select)
- **Single/multi-session deletion**: support `deleteLogs(forSession:)` and `deleteLogs(forSessions:)`
- **Confirmation flow**: double confirmation to prevent accidental deletion
- **Background execution**: run on background context to keep UI responsive

### Performance Optimizations
- Predicate reuse: centralize query predicate building to remove duplication
- Query optimization: reduce stats queries from 9 to 2 (grouped query + popular function query)
- Thread safety: all database operations use background context
- Task cancellation: allow cancellation for running search/load tasks
