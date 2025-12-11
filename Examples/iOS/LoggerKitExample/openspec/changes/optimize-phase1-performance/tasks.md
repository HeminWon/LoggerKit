# 实施任务清单

## 阶段 1A: 准备工作

### 1. 环境准备
- [ ] 1.1 创建特性分支 `feature/optimize-phase1-performance`
- [ ] 1.2 在 CI 中启用 Thread Sanitizer
- [ ] 1.3 准备测试数据集
  - [ ] 生成 1 万条测试日志
  - [ ] 生成 5 万条测试日志
  - [ ] 生成 10 万条测试日志
  - [ ] 生成包含特殊字符的测试日志(SQL注入测试)
  - [ ] 生成边界条件测试数据(0条、500条、501条)

### 2. 建立性能基准测试框架
- [ ] 2.1 创建性能测试目标(PerformanceTests)
- [ ] 2.2 编写数据库查询性能测试
  - [ ] 测量 fetchStatistics() 查询时间
  - [ ] 测量 fetchEvents() 查询时间
- [ ] 2.3 编写 UI 渲染性能测试
  - [ ] 测量列表滚动帧率
  - [ ] 测量初始加载时间
- [ ] 2.4 编写内存占用测试
  - [ ] 测量加载不同数量日志的内存占用
- [ ] 2.5 记录优化前的基准数据到文档

## 阶段 1A: 低风险优化实施

### 3. 合并数据库统计查询
- [ ] 3.1 在 `LogDatabaseManager.swift` 中重构 `fetchStatistics()` 方法
- [ ] 3.2 实现单次分组查询获取级别统计
  - [ ] 使用 `NSExpressionDescription` 定义聚合表达式
  - [ ] 设置 `propertiesToGroupBy = ["level"]`
  - [ ] 设置 `propertiesToFetch = ["level", countDescription]`
  - [ ] 解析分组查询结果,构建 `levelCounts` 字典
  - [ ] 通过级别计数求和计算总数
- [ ] 3.3 保留热门函数查询为独立方法 `fetchTopFunctions()`
  - [ ] 处理函数名为空的情况
  - [ ] 限制返回Top 100
- [ ] 3.4 编写单元测试验证统计结果准确性
  - [ ] 对比优化前后的统计结果
  - [ ] 验证总数等于各级别之和
  - [ ] 验证热门函数排序正确
  - [ ] 测试空数据集情况
  - [ ] 测试单条日志情况
- [ ] 3.5 运行性能测试,记录查询时间改善
  - [ ] 测量1万、5万、10万条数据的查询时间
  - [ ] 验证达到50-100ms目标

### 4. 优化 CoreDataStack 资源初始化
- [ ] 4.1 在 `CoreDataStack.swift` 中创建静态属性 `modelURL`
- [ ] 4.2 将模型文件查找逻辑移到静态属性初始化块
- [ ] 4.3 使用循环遍历候选路径,避免重复代码
- [ ] 4.4 在 `persistentContainer` 的 lazy 初始化中使用 `Self.modelURL`
- [ ] 4.5 优化错误信息,包含查找路径和文件类型
- [ ] 4.6 代码审查和清理

### 5. 阶段 1A 测试验证
- [ ] 5.1 运行完整的单元测试套件
- [ ] 5.2 运行性能基准测试并对比结果
  - [ ] 数据库查询时间对比
- [ ] 5.3 运行 Thread Sanitizer 验证
- [ ] 5.4 提交阶段 1A 代码(独立可回滚)

## 阶段 1B: 架构改进实施

### 6. 实现数据库层过滤和分页
- [ ] 6.1 验证或添加数据库索引
  - [ ] 检查sessionId、level、timestamp字段是否已有索引
  - [ ] 如需要,在.xcdatamodeld中添加索引
  - [ ] 评估是否需要轻量级迁移
- [ ] 6.2 重构 `LogDatabaseManager.swift` 的 `fetchEvents()` 方法签名
  ```swift
  func fetchEvents(
      in context: NSManagedObjectContext,  // 新增:支持后台 context
      sessionId: String? = nil,
      levels: Set<LogLevel>? = nil,
      searchText: String? = nil,
      offset: Int = 0,
      limit: Int = 500
  ) throws -> [LogEvent]
  ```
- [ ] 6.3 实现 NSPredicate 构建逻辑
  - [ ] 会话 ID 过滤
  - [ ] 级别过滤(支持多选)
  - [ ] 搜索文本过滤(message 和 function 字段,CONTAINS[cd])
  - [ ] 使用 NSCompoundPredicate 组合多个条件
  - [ ] 验证特殊字符转义
- [ ] 6.4 实现排序和分页
  - [ ] 设置 `sortDescriptors` 按时间戳降序
  - [ ] 设置 `fetchOffset` 和 `fetchLimit`
- [ ] 6.5 编写全面的单元测试
  - [ ] 测试单一条件过滤(级别、会话、搜索)
  - [ ] 测试多条件组合过滤
  - [ ] 测试空条件情况
  - [ ] 测试空结果集
  - [ ] **边界条件测试**:
    - [ ] 空数据库(0条日志)
    - [ ] 过滤结果为空
    - [ ] 数据量刚好等于pageSize(500条)
    - [ ] 数据量为pageSize+1(501条)
    - [ ] 最后一页不足pageSize
  - [ ] **特殊字符测试**:
    - [ ] searchText包含SQL特殊字符(%, _, ', ")
    - [ ] 验证NSPredicate正确转义
    - [ ] SQL注入防护测试
  - [ ] 测试分页逻辑(第一页、后续页、最后一页)
  - [ ] 对比数据库过滤和内存过滤的结果一致性
- [ ] 6.6 **索引性能验证**
  - [ ] 对比有索引和无索引的查询性能
  - [ ] 测量sessionId过滤查询时间(应<50ms)
  - [ ] 测量level过滤查询时间
  - [ ] 测量CONTAINS查询时间(评估是否需要优化)
  - [ ] 测量索引对写入性能的影响(应<20%)
- [ ] 6.7 **CONTAINS查询优化**(如果6.6发现性能问题)
  - [ ] 实现searchText最小长度限制(>=3字符)
  - [ ] 或接受性能损耗,文档化已知限制

### 7. 修复并发安全问题
- [ ] 7.1 在 `LogDetailSceneState` 中移除 `nonisolated(unsafe)` 修饰符
- [ ] 7.2 将 `databaseManager` 改为 `@Published var`(在主 actor 上)
- [ ] 7.3 重构 `loadAllLogsFromDatabase()` 方法
  - [ ] **在进入闭包前捕获必要的值**(避免闭包中访问@Published)
  - [ ] 使用 `persistentContainer.performBackgroundTask`
  - [ ] 在后台 context 中调用 `fetchEvents(in: context, ...)`
  - [ ] 使用 `DispatchQueue.main.async { [weak self] in }` 更新 UI
  - [ ] 使用 `[weak self]` 避免循环引用
  - [ ] 实现错误处理和日志记录
  - [ ] 实现可选的自动重试机制(retry: Bool参数)
- [ ] 7.4 实现错误类型定义
  - [ ] 创建 `LogDatabaseError` 枚举
  - [ ] 实现 LocalizedError 协议
  - [ ] 提供清晰的错误描述
- [ ] 7.5 重构其他异步数据库操作方法
  - [ ] `loadLogsFromDatabase()`
  - [ ] `fetchStatistics()` 调用
  - [ ] `loadMore()` 分页加载
  - [ ] 其他可能的数据库查询
- [ ] 7.6 实现数据一致性策略
  - [ ] 在过滤条件didSet中实现重置逻辑
  - [ ] 实现 `cancelPendingLoads()` 方法
  - [ ] 过滤条件变化时重置分页状态
- [ ] 7.7 编写并发测试
  - [ ] 测试多线程同时查询
  - [ ] 测试多次快速触发加载
  - [ ] 测试过滤条件快速切换
  - [ ] 测试加载中切换条件
  - [ ] 验证无崩溃和数据竞争
- [ ] 7.8 运行 Thread Sanitizer 验证
- [ ] 7.9 代码审查确保没有遗漏的 viewContext 后台访问

### 8. 优化列表渲染
- [ ] 8.1 在 `LogDetailSceneState` 中添加分页状态
  - [ ] `@Published var displayEvents: [LogEvent] = []` (替代 filteredEvents)
  - [ ] `private(set) var currentPage: Int = 0`
  - [ ] `private(set) var hasMorePages: Bool = true`
  - [ ] `private let pageSize: Int = 500`
  - [ ] `private var loadingTask: Task<Void, Never>?` (用于取消)
- [ ] 8.2 实现 `loadInitialLogs()` 方法
  - [ ] 重置分页状态(currentPage = 0, displayEvents = [])
  - [ ] 调用 `fetchEvents(offset: 0, limit: pageSize)`
  - [ ] 更新 `displayEvents` 和 `hasMorePages`
- [ ] 8.3 实现 `loadMore()` 方法
  - [ ] 检查 `hasMorePages` 和 `isLoading`
  - [ ] 调用 `fetchEvents(offset: currentPage * pageSize, limit: pageSize)`
  - [ ] 追加新数据到 `displayEvents`
  - [ ] 更新 `currentPage` 和 `hasMorePages`
- [ ] 8.4 实现 `cancelPendingLoads()` 方法
  - [ ] 取消 loadingTask
  - [ ] 重置加载状态
- [ ] 8.5 实现过滤条件变化时的分页重置
  - [ ] 在 searchText、selectedLevels、sessionId 的 didSet 中:
    - [ ] 调用 `cancelPendingLoads()`
    - [ ] 调用 `loadInitialLogs()`
  - [ ] 为 searchText 添加 300ms debounce
- [ ] 8.6 在 `LogDetailScene.swift` 中替换为 `List`
  - [ ] 将 `ScrollView` + `LazyVStack` 替换为 `List`
  - [ ] 配置 `List` 使用 `.plain` 样式
  - [ ] 确保每个 `LogRowView` 设置 `.id(logEvent.id)`
  - [ ] 添加 `.refreshable` 支持下拉刷新
- [ ] 8.7 实现滚动到底部检测
  - [ ] 在最后一个元素的 `.onAppear` 中触发 `loadMore()`
  - [ ] 添加防抖,避免重复触发
- [ ] 8.8 UI 测试验证
  - [ ] 初始加载第一页
  - [ ] 滚动到底部自动加载更多
  - [ ] 加载完全部日志后不再触发
  - [ ] 过滤条件变化时重置分页
  - [ ] 下拉刷新功能
  - [ ] **边界UI测试**:
    - [ ] 空数据显示空状态
    - [ ] 过滤结果为空显示提示
    - [ ] 加载失败显示错误和重试按钮
- [ ] 8.9 性能测试对比
  - [ ] 帧率测试(真机,使用Instruments)
  - [ ] 初始加载时间对比
  - [ ] 内存占用对比(1万、5万、10万条)
  - [ ] 验证达到60fps目标(或记录实际帧率)

### 9. 重构缓存管理
- [ ] 9.1 创建 `FilterOptionsCache.swift` 文件
- [ ] 9.2 实现强类型存储方案(方案 A)
  - [ ] 定义内部 `Storage` 结构体
  - [ ] 创建 concurrent DispatchQueue
  - [ ] 实现各属性的 get 方法(使用 sync)
  - [ ] 实现各属性的 set 方法(使用 sync + barrier)
  - [ ] 实现 `invalidateAll()` 方法
- [ ] 9.3 在 `LogDetailSceneState` 中集成
  - [ ] 创建 `private let filterCache = FilterOptionsCache()`
  - [ ] 替换 8 个独立缓存变量为缓存类调用
  - [ ] 删除旧的缓存变量
- [ ] 9.4 编写单元测试
  - [ ] 测试类型安全的缓存读写
  - [ ] 测试并发访问安全性(多线程读写)
  - [ ] 测试缓存失效
  - [ ] 测试 get 未设置的值返回 nil
- [ ] 9.5 运行 Thread Sanitizer 验证

## 阶段 1B: 测试验证

### 10. 全面测试
- [ ] 10.1 运行完整的单元测试套件
- [ ] 10.2 运行性能基准测试并对比结果
  - [ ] 过滤计算时间对比
  - [ ] 列表渲染性能对比
  - [ ] 数据库查询时间对比
  - [ ] 内存占用对比(与阶段 1A 后对比)
- [ ] 10.3 真机测试(iPhone, iPad)
  - [ ] 测试大数据量场景(1万、5万、10万条日志)
  - [ ] 测试滚动流畅度
  - [ ] 测试过滤响应速度
  - [ ] 测试快速切换过滤条件
- [ ] 10.4 使用 Instruments 分析性能
  - [ ] Time Profiler 检查热点函数
  - [ ] Allocations 检查内存占用
  - [ ] Leaks 检查内存泄漏
- [ ] 10.5 Thread Sanitizer 验证无数据竞争
- [ ] 10.6 并发压力测试
  - [ ] 多线程同时查询
  - [ ] 快速连续切换过滤条件
  - [ ] 在加载中切换条件
- [ ] 10.7 记录优化后的性能数据并与基准对比
- [ ] 10.8 提交阶段 1B 代码(独立可回滚)

## 阶段 1C: 评估和决策

### 11. 性能评估
- [ ] 11.1 分析阶段 1B 后的性能数据
- [ ] 11.2 评估是否仍存在性能瓶颈
- [ ] 11.3 决定是否需要实施 filteredEvents 优化
  - [ ] 如需要,设计具体方案(Combine 响应式 vs 简化为 @Published)
  - [ ] 估算实施时间和收益
- [ ] 11.4 更新文档说明最终决策

## 阶段 2: 发布

### 12. 代码质量和文档
- [ ] 12.1 代码审查
  - [ ] 检查所有 CoreData 访问是否线程安全
  - [ ] 检查所有过滤逻辑是否正确
  - [ ] 检查错误处理是否完善
- [ ] 12.2 更新相关代码注释
- [ ] 12.3 更新 CHANGELOG 或性能文档
  - [ ] 记录性能提升数据
  - [ ] 说明架构变更
  - [ ] 列出潜在的破坏性变更(如有)

### 13. 准备交付
- [ ] 13.1 确认所有测试通过
- [ ] 13.2 准备性能对比数据报告
- [ ] 13.3 等待用户验收

## 回滚检查点

- ✅ **检查点 1A**: 阶段 1A 提交(低风险优化)
- ✅ **检查点 1B**: 阶段 1B 提交(架构改进)
- ✅ **最终检查点**: 阶段 2 发布

每个检查点都应独立可回滚,保留完整的测试数据用于对比。

## 预估工作量

- **阶段 1A**: 7 小时(准备 2h + 实施 3h + 索引验证 2h)
- **阶段 1B**: 28 小时
  - 数据库层过滤和分页: 6-7h (新增索引验证和边界测试)
  - 并发安全修复: 4h (新增错误处理和数据一致性)
  - 列表渲染优化: 4h (新增下拉刷新和边界UI)
  - 缓存重构: 2h
  - 全面测试: 6-7h (新增边界条件、错误处理、索引性能测试)
  - 性能评估: 1h
  - Code review和返工预留: 3-5h
- **阶段 2**: 2 小时(文档更新和准备交付)
- **总计**: 37-42 小时(不含用户验收和发布)

**时间增加原因**:
- ✅ 数据库索引验证和性能测试: +2-3h
- ✅ 边界条件全面测试: +2h
- ✅ 错误处理实现和测试: +2-3h
- ✅ 数据一致性策略实现: +1-2h
- ✅ Code review和返工预留: +3-5h
