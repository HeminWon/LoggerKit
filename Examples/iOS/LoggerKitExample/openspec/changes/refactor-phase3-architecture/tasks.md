# Tasks: 阶段3架构重构

## 步骤1: 提取 FilterState

- [ ] 创建 `Sources/LoggerKit/UI/FilterState.swift`
- [ ] 实现 FilterState 类的完整功能
  - [ ] 定义 7 个 @Published 过滤字段
  - [ ] 实现 onFilterChanged 回调机制
  - [ ] 实现 activeFilterCount 计算属性
  - [ ] 实现 resetFilters() 方法
  - [ ] 实现 isInFilter()、addToFilter()、removeFromFilter() 方法
  - [ ] 实现 toggleFilter() 和 toggleLevel() 方法
  - [ ] 定义 FilterItem 枚举
- [ ] 修改 `Sources/LoggerKit/UI/LogDetailSceneState.swift`
  - [ ] 添加 `public let filterState: FilterState` 属性
  - [ ] 移除 7 个过滤字段的 @Published 声明
  - [ ] 更新 init 方法支持 filterState 注入
  - [ ] 实现 setupFilterStateBinding() 订阅变更
  - [ ] 更新所有引用过滤字段的地方(使用 filterState.xxx)
  - [ ] 更新 loadLogsFromDatabase() 等方法
- [ ] 更新 UI 层文件
  - [ ] 修改 `Sources/LoggerKit/UI/LogDetailScene.swift` 中的引用
  - [ ] 修改 `Sources/LoggerKit/UI/LogFilterSheet.swift` 中的引用
- [ ] 验证步骤1完成
  - [ ] swift build 成功,无警告
  - [ ] Example 项目运行
  - [ ] 过滤功能正常工作
  - [ ] 无性能回退

## 步骤2: 提取 DataLoaderService

- [ ] 创建目录 `Sources/LoggerKit/UI/DataLoader/`
- [ ] 创建 `LogDataLoaderProtocol.swift`
  - [ ] 定义 loadEvents() 方法签名
  - [ ] 定义 loadStatistics() 方法签名
  - [ ] 定义 cancelCurrentTask() 方法
- [ ] 创建 `LoadingState.swift`
  - [ ] 定义 LoadingState 枚举(idle/loading/loadingMore/loaded/failed)
  - [ ] 实现 Equatable 协议
- [ ] 创建 `LogDataLoader.swift`
  - [ ] 实现 LogDataLoaderProtocol
  - [ ] 实现 loadEvents() - 封装 performBackgroundTask
  - [ ] 实现 loadStatistics()
  - [ ] 实现 cancelCurrentTask()
  - [ ] 管理 currentTask 生命周期
- [ ] 修改 `Sources/LoggerKit/UI/LogDetailSceneState.swift`
  - [ ] 添加 `private let dataLoader: LogDataLoaderProtocol` 属性
  - [ ] 替换 `@Published var isLoading/isLoadingMore` 为 `loadingState: LoadingState`
  - [ ] 移除 `private var loadTask: Task<Void, Never>?`
  - [ ] 删除 loadLogsFromDatabase() 的复杂实现
  - [ ] 重写为简化的 loadLogs(resetPagination:) 调用 dataLoader
  - [ ] 重写 loadMore() 方法
  - [ ] 重写 refresh() 方法
  - [ ] 实现 loadStatisticsInternal() 私有方法
  - [ ] 更新 init 支持 dataLoader 注入
- [ ] 验证步骤2完成
  - [ ] swift build 成功,无警告
  - [ ] Example 项目运行
  - [ ] 数据加载正常
  - [ ] 分页加载正常
  - [ ] Task 取消逻辑正确
  - [ ] 无性能回退

## 步骤3: 依赖注入改造

- [ ] 创建 `Sources/LoggerKit/Database/LogDatabaseManagerProtocol.swift`
  - [ ] 定义 LogDatabaseManagerProtocol 协议
  - [ ] 声明 fetchEvents() 方法
  - [ ] 声明 fetchStatistics() 方法
  - [ ] 添加 extension LogDatabaseManager: LogDatabaseManagerProtocol {}
- [ ] 修改 `Sources/LoggerKit/UI/DataLoader/LogDataLoader.swift`
  - [ ] 将 databaseManager 类型改为 LogDatabaseManagerProtocol
  - [ ] 修改 init 强制要求协议注入
- [ ] 修改 `Sources/LoggerKit/UI/LogDetailSceneState.swift`
  - [ ] 创建完整 DI 的 init(dataLoader:filterState:)
  - [ ] 创建便利 init(prefix:identifier:) 使用默认依赖
  - [ ] 确保两个 init 都正确初始化所有属性
- [ ] 验证步骤3完成
  - [ ] swift build 成功,无警告
  - [ ] Example 项目使用便利初始化正常工作
  - [ ] 依赖可替换(代码审查确认)
  - [ ] 无功能回退

## 步骤4: 提取 SearchState (可选)

- [ ] 创建 `Sources/LoggerKit/UI/SearchState.swift`
  - [ ] 定义 SearchState 类
  - [ ] 添加 searchText 和 searchFields @Published 属性
  - [ ] 实现 onSearchChanged 回调
  - [ ] 实现 computeResults() - 单次遍历优化版本
  - [ ] 实现 toggleSearchField() 方法
- [ ] 修改 `Sources/LoggerKit/UI/LogDetailSceneState.swift`
  - [ ] 添加 `public let searchState: SearchState` 属性
  - [ ] 移除 @Published var searchText
  - [ ] 移除 @Published var searchFields
  - [ ] 删除 searchResults 复杂的计算属性实现
  - [ ] 重写为简单调用 searchState.computeResults(from: displayEvents)
  - [ ] 更新 init 支持 searchState 注入
  - [ ] 在 setupBindings() 中订阅 searchState.onSearchChanged
- [ ] 更新 UI 层搜索相关引用
  - [ ] 更新 LogDetailScene.swift 中的搜索相关代码
- [ ] 验证步骤4完成
  - [ ] swift build 成功,无警告
  - [ ] Example 项目搜索功能正常
  - [ ] 搜索性能提升(响应更快)
  - [ ] 无功能回退

## 最终验证

- [ ] 完整回归测试
  - [ ] 所有过滤维度正常工作
  - [ ] 搜索功能完整
  - [ ] 分页加载稳定
  - [ ] 统计信息准确
  - [ ] UI 交互流畅
- [ ] 性能基准测试
  - [ ] 初始加载时间 ≤ 重构前
  - [ ] 搜索响应时间(步骤4完成后应更快)
  - [ ] 滚动帧率 ≥ 60fps
  - [ ] 内存占用 ≤ 重构前
- [ ] 代码质量检查
  - [ ] LogDetailSceneState < 300 行
  - [ ] 无编译警告
  - [ ] 代码格式化正确
- [ ] 文档更新
  - [ ] 更新 PHASE3_REFACTORING_PLAN.md 标记完成状态
  - [ ] 更新 OPTIMIZATION_ROADMAP.md
  - [ ] 记录实际工作量和遇到的问题
