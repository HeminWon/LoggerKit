# log-ui-display Specification Delta

## MODIFIED Requirements

### Requirement: 过滤状态管理重构

系统 SHALL 将过滤条件管理从 LogDetailSceneState 提取为独立的 FilterState 组件。

FilterState MUST 统一管理所有 7 个过滤维度(levels, functions, fileNames, contexts, threads, messageKeywords, sessionId)。

FilterState MUST 提供统一的 onFilterChanged 回调,消除重复的 didSet 代码。

FilterState MUST 提供类型安全的过滤器操作方法(isInFilter, addToFilter, removeFromFilter, toggleFilter)。

FilterState MUST 计算激活的过滤器数量(activeFilterCount)。

LogDetailSceneState MUST 通过组合 FilterState 而非继承实现过滤功能。

#### Scenario: 创建默认 FilterState

- **WHEN** 初始化 LogDetailSceneState
- **THEN** 自动创建 FilterState 实例
- **AND** 默认选中所有日志级别(verbose, debug, info, warning, error)
- **AND** 其他过滤条件为空

#### Scenario: 过滤条件变更触发重新加载

- **WHEN** 用户修改任何过滤条件(如选择函数名)
- **THEN** FilterState 触发 onFilterChanged 回调
- **AND** LogDetailSceneState 取消当前加载任务
- **AND** 自动重新加载日志
- **AND** 仅触发一次重新加载(而非多次)

#### Scenario: 统一的过滤器操作

- **WHEN** 用户通过 UI 添加过滤条件
- **THEN** 调用 filterState.addToFilter(.function("test"))
- **AND** selectedFunctions 更新
- **AND** UI 自动刷新(@Published 机制)
- **AND** 触发 onFilterChanged 回调

#### Scenario: 检查过滤状态

- **WHEN** UI 需要判断某项是否已过滤
- **THEN** 调用 filterState.isInFilter(.function("test"))
- **AND** 返回布尔值
- **AND** 无需直接访问 selectedFunctions Set

#### Scenario: 重置过滤器

- **WHEN** 用户点击"重置过滤器"
- **THEN** 调用 filterState.resetFilters()
- **AND** 清空所有过滤条件(级别和会话ID除外)
- **AND** 触发 onFilterChanged 回调
- **AND** 自动重新加载日志

#### Scenario: 计算激活过滤器数量

- **WHEN** UI 需要显示激活的过滤器数量
- **THEN** 访问 filterState.activeFilterCount
- **AND** 返回非空过滤条件的数量
- **AND** 不计算级别(级别始终有值)

#### Scenario: 依赖注入 FilterState

- **WHEN** 需要自定义 FilterState(如测试)
- **THEN** 可通过 init 参数注入
- **AND** LogDetailSceneState 使用注入的实例
- **AND** 默认情况下自动创建新实例

---

### Requirement: 数据加载服务重构

系统 SHALL 将数据加载逻辑从 LogDetailSceneState 提取为独立的 DataLoader 组件。

DataLoader MUST 封装所有数据库查询逻辑(loadEvents, loadStatistics)。

DataLoader MUST 统一管理 Task 生命周期(创建、取消、追踪)。

DataLoader MUST 使用 performBackgroundTask 确保线程安全。

DataLoader MUST 通过协议定义接口,支持依赖注入和测试 Mock。

LogDetailSceneState MUST 使用 LoadingState 枚举替代多个布尔标志(isLoading, isLoadingMore)。

#### Scenario: 通过 DataLoader 加载日志

- **WHEN** LogDetailSceneState 需要加载日志
- **THEN** 调用 dataLoader.loadEvents()
- **AND** DataLoader 在后台线程执行数据库查询
- **AND** 查询完成后返回 [LogEvent]
- **AND** LogDetailSceneState 在主线程更新 displayEvents

#### Scenario: 统一的加载状态管理

- **WHEN** 开始加载日志
- **THEN** loadingState 设置为 .loading(progress: "加载中...")
- **WHEN** 加载更多日志
- **THEN** loadingState 设置为 .loadingMore
- **WHEN** 加载完成
- **THEN** loadingState 设置为 .loaded
- **WHEN** 加载失败
- **THEN** loadingState 设置为 .failed(Error)

#### Scenario: Task 取消机制

- **WHEN** 用户快速切换过滤条件
- **THEN** DataLoader 取消当前正在执行的 Task
- **AND** 启动新的加载 Task
- **AND** 旧 Task 不会继续执行
- **AND** 不会出现数据竞争

#### Scenario: 后台线程查询

- **WHEN** DataLoader 执行 loadEvents()
- **THEN** 使用 performBackgroundTask 创建后台 context
- **AND** 在后台 context 中执行数据库查询
- **AND** 使用 continuation 协调异步操作
- **AND** 返回结果时不持有 context 引用

#### Scenario: 加载统计信息

- **WHEN** 需要加载统计信息
- **THEN** 调用 dataLoader.loadStatistics(sessionId)
- **AND** 在后台线程查询统计数据
- **AND** 返回 LogStatistics 对象
- **AND** LogDetailSceneState 更新 statistics 属性

#### Scenario: 依赖注入 DataLoader

- **WHEN** 需要自定义 DataLoader(如测试)
- **THEN** 可通过 init 参数注入 LogDataLoaderProtocol
- **AND** LogDetailSceneState 使用注入的实例
- **AND** 默认情况下创建标准 LogDataLoader

---

## ADDED Requirements

### Requirement: 依赖注入架构

系统 SHALL 支持完整的依赖注入,提升可测试性和灵活性。

LogDatabaseManager MUST 定义 LogDatabaseManagerProtocol 协议。

LogDataLoader MUST 通过协议依赖 LogDatabaseManagerProtocol。

LogDetailSceneState MUST 提供两种初始化方式:
- 完整 DI 初始化: 接受所有依赖参数(用于测试)
- 便利初始化: 使用默认依赖(用于生产环境)

所有依赖 MUST 通过 init 参数注入,而非使用单例。

#### Scenario: 协议定义数据库接口

- **WHEN** 定义 LogDatabaseManagerProtocol
- **THEN** 包含 fetchEvents() 和 fetchStatistics() 方法签名
- **AND** LogDatabaseManager 遵循该协议
- **AND** 现有功能不受影响(extension 方式遵循)

#### Scenario: DataLoader 使用协议依赖

- **WHEN** 创建 LogDataLoader
- **THEN** init 参数类型为 LogDatabaseManagerProtocol
- **AND** 不直接依赖 LogDatabaseManager.shared
- **AND** 支持传入 Mock 实现

#### Scenario: 生产环境便利初始化

- **WHEN** 在生产环境创建 LogDetailSceneState
- **THEN** 使用便利 init(prefix:identifier:)
- **AND** 内部自动创建标准依赖
- **AND** 使用 LogDatabaseManager.shared
- **AND** 使用默认 FilterState

#### Scenario: 测试环境完整 DI

- **WHEN** 在测试环境创建 LogDetailSceneState
- **THEN** 使用完整 init(dataLoader:filterState:)
- **AND** 传入 Mock DataLoader
- **AND** 传入自定义 FilterState
- **AND** 完全控制依赖行为

#### Scenario: 依赖可替换性

- **WHEN** 需要替换数据加载实现
- **THEN** 创建新的 LogDataLoaderProtocol 实现
- **AND** 注入到 LogDetailSceneState
- **AND** 无需修改 LogDetailSceneState 代码
- **AND** 功能正常工作

---

### Requirement: 搜索状态管理重构

系统 SHALL 支持将搜索逻辑从 LogDetailSceneState 提取为独立的 SearchState 组件(可选实施)。

SearchState MUST 管理 searchText 和 searchFields 属性。

SearchState MUST 实现单次遍历的 computeResults() 方法。

SearchState MUST 使用字典统计匹配计数,而非多次遍历。

搜索性能 MUST 提升至少 50%(响应时间减少)。

#### Scenario: 单次遍历计算搜索结果

- **WHEN** 用户输入搜索文本
- **THEN** SearchState.computeResults(from: events) 被调用
- **AND** 仅遍历 events 数组一次
- **AND** 同时计算所有搜索字段的匹配结果
- **AND** 返回包含匹配计数的 CategorizedSearchResults

#### Scenario: 搜索性能优化

- **WHEN** 搜索 10000 条日志
- **AND** 搜索 5 个字段(message, function, fileName, context, thread)
- **THEN** 优化前: 遍历 5 次(每字段 1 次),共 50000 次迭代
- **AND** 优化后: 遍历 1 次,共 10000 次迭代
- **AND** 响应时间减少 50-70%

#### Scenario: 搜索范围切换

- **WHEN** 用户切换搜索范围
- **THEN** 调用 searchState.toggleSearchField(.message)
- **AND** searchFields 更新
- **AND** 触发 onSearchChanged 回调
- **AND** 搜索结果自动重新计算

#### Scenario: 依赖注入 SearchState

- **WHEN** 需要自定义 SearchState
- **THEN** 可通过 init 参数注入
- **AND** LogDetailSceneState 使用注入的实例
- **AND** 默认情况下自动创建新实例

---

### Requirement: 架构质量保障

系统 MUST 确保重构后满足以下质量标准。

LogDetailSceneState 行数 MUST < 300 行。

LogDetailSceneState 职责数量 MUST ≤ 2 个(UI协调 + 分页管理)。

@Published 属性数量 MUST ≤ 6 个。

didSet 重复代码 MUST = 0 (通过 FilterState 统一管理)。

所有现有功能 MUST 保持正常工作(无回归)。

性能 MUST 无回退(初始加载、搜索、滚动)。

#### Scenario: 代码行数验证

- **WHEN** 重构完成
- **THEN** 统计 LogDetailSceneState.swift 行数
- **AND** 总行数(包含注释) < 300
- **AND** 相比重构前(767行)减少 > 60%

#### Scenario: 职责清晰性验证

- **WHEN** 审查 LogDetailSceneState 代码
- **THEN** 仅包含以下职责:
  - UI 状态协调(整合 FilterState, SearchState, DataLoader)
  - 分页状态管理(currentPage, hasMoreData, pageSize)
- **AND** 过滤逻辑在 FilterState
- **AND** 数据加载在 DataLoader
- **AND** 搜索逻辑在 SearchState(可选)

#### Scenario: 无功能回退验证

- **WHEN** 在 Example 项目运行重构后的代码
- **THEN** 所有过滤维度正常工作
- **AND** 搜索功能完整
- **AND** 分页加载稳定
- **AND** 统计信息准确
- **AND** 无新增 bug

#### Scenario: 性能基准验证

- **WHEN** 测量重构后的性能指标
- **THEN** 初始加载时间 ≤ 重构前
- **AND** 搜索响应时间 ≤ 重构前(SearchState 实现后应更快)
- **AND** 滚动帧率 ≥ 60fps
- **AND** 内存占用 ≤ 重构前

#### Scenario: 编译质量验证

- **WHEN** 执行 swift build
- **THEN** 编译成功
- **AND** 0 个编译警告
- **AND** 0 个类型错误
- **AND** 编译时间无明显增加
