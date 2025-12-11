# 设计文档: 第一阶段性能优化

## Context

### 背景
LoggerKit 框架经过代码分析后发现了 18 个性能和代码质量问题,其中 6 个为高优先级问题,严重影响用户体验。这些问题主要集中在:
- UI 层的计算属性重复计算
- 数据库查询策略低效
- 并发安全隐患

### 约束
- 必须保持公开 API 兼容性(非破坏性变更)
- 不能修改 CoreData 模型(避免数据迁移)
- 必须保持线程安全
- 优先简洁实用的方案,避免过度设计

### 利益相关者
- **最终用户**: 获得更流畅的日志查看体验
- **开发者**: 维护更清晰、更安全的代码库
- **性能**: 减少 CPU 占用和内存压力

## Goals / Non-Goals

### Goals
1. ✅ 优化 UI 计算属性缓存机制,减少重复计算
2. ✅ 实现真正的分页加载,改善列表渲染性能
3. ✅ 合并数据库查询,减少 I/O 往返次数
4. ✅ 统一缓存管理,提升代码可维护性
5. ✅ 消除并发安全隐患
6. ✅ 优化启动时间

### Non-Goals
- ❌ 不涉及 UI 设计变更(仅内部优化)
- ❌ 不修改 CoreData 数据模型
- ❌ 不改变公开 API 接口
- ❌ 不引入新的外部依赖

## Decisions

### Decision 1: 将过滤逻辑下推到数据库层

**选择**: 在数据库层使用 NSPredicate 实现过滤,而非在内存中过滤

**理由**:
- 减少内存占用:只加载符合条件的数据,而非加载全部再过滤
- 提升查询性能:利用 CoreData 索引和 SQLite 优化
- 支持真正的分页:分页 offset 基于过滤后的结果集
- 架构清晰:数据层负责数据筛选,UI 层负责展示

**备选方案**:
- ❌ **内存中过滤 + 分页加载**: 会导致分页不准确(第一页加载 500 条但过滤后只剩 50 条)
- ❌ **手动缓存过滤结果**: 需要复杂的缓存失效逻辑,容易出错

**实现**:
```swift
// LogDatabaseManager.swift
func fetchEvents(
    in context: NSManagedObjectContext,  // 接受context参数支持后台查询
    sessionId: String? = nil,
    levels: Set<LogLevel>? = nil,
    searchText: String? = nil,
    offset: Int = 0,
    limit: Int = 500
) throws -> [LogEvent] {
    let request = LogEventEntity.fetchRequest()

    // 构建过滤条件
    var predicates: [NSPredicate] = []

    if let sessionId = sessionId {
        predicates.append(NSPredicate(format: "sessionId == %@", sessionId))
    }

    if let levels = levels, !levels.isEmpty {
        let levelValues = levels.map { $0.rawValue }
        predicates.append(NSPredicate(format: "level IN %@", levelValues))
    }

    if let searchText = searchText, !searchText.isEmpty {
        predicates.append(NSPredicate(
            format: "message CONTAINS[cd] %@ OR function CONTAINS[cd] %@",
            searchText, searchText
        ))
    }

    if !predicates.isEmpty {
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    // 排序和分页
    request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
    request.fetchOffset = offset
    request.fetchLimit = limit

    return try context.fetch(request).map { $0.toLogEvent() }
}
```

**索引策略**:
- `sessionId`: 添加索引(高频过滤字段)
- `level`: 添加索引(高频过滤字段)
- `timestamp`: 添加索引(排序字段)
- `message`和`function`: CONTAINS查询无法利用普通索引,需权衡性能
  - 选项1: 接受CONTAINS查询的性能损耗
  - 选项2: 考虑添加前缀索引或全文索引
  - 选项3: 限制搜索文本最小长度(如>=3个字符)

**性能分析**:
- 带索引的等值查询(sessionId, level): O(log n)
- 带索引的排序(timestamp): O(n log n) → O(n)
- CONTAINS查询: O(n) - 需要全表扫描
- 分页查询: 仅影响结果集大小,不影响查询时间复杂度

**影响**: filteredEvents 计算属性可能不再需要,或改为简单的 @Published 数组

---

### Decision 2: 使用 List 替代 ScrollView + LazyVStack

**选择**: 使用 SwiftUI 的 `List` 组件实现真正的虚拟化列表

**理由**:
- `List` 内置高效的虚拟化机制,仅渲染可见区域
- 原生支持滚动性能优化
- API 简洁,代码量更少

**备选方案**:
- **LazyVStack + ScrollView**: 当前方案,虚拟化效果不佳
- **UIKit UITableView 桥接**: 过度复杂,维护成本高
- **自定义虚拟化列表**: 重复造轮子,不推荐

**实现**:
```swift
List(sceneState.displayEvents, id: \.id) { logEvent in
    LogRowView(event: logEvent)
        .id(logEvent.id)
}
.listStyle(.plain)
.onAppear {
    Task { await sceneState.loadInitialLogs() }
}
```

**依赖**: 需要先实现 Decision 1(数据库层过滤)

---

### Decision 3: 使用 NSExpressionDescription 合并数据库查询

**选择**: 使用 CoreData 的 `NSExpressionDescription` 和分组查询合并统计操作

**理由**:
- CoreData 原生支持,无需额外依赖
- 单次查询获取所有级别统计,减少 I/O
- 性能提升显著(9次查询 → 2次查询)

**备选方案**:
- **原生 SQL 查询**: 绕过 CoreData 抽象层,维护性差,失去类型安全
- **分批查询**: 仍需多次 I/O,性能提升有限
- **缓存统计结果**: 需要复杂的缓存失效逻辑,容易出现数据不一致

**实现**:
```swift
// 单次分组查询获取所有级别统计
let levelExpression = NSExpression(forKeyPath: "level")
let countExpression = NSExpression(forFunction: "count:", arguments: [levelExpression])
let countDescription = NSExpressionDescription()
countDescription.name = "levelCount"
countDescription.expression = countExpression

request.propertiesToGroupBy = ["level"]
request.propertiesToFetch = ["level", countDescription]
```

---

### Decision 4: 创建专用 FilterOptionsCache 类(强类型 + 同步 barrier)

**选择**: 创建独立的 `FilterOptionsCache` 类,使用强类型存储和同步 barrier 写入

**理由**:
- 单一职责原则,分离缓存管理逻辑
- 强类型存储,避免类型转换错误
- 同步 barrier 写入,避免竞态条件
- 易于扩展和测试

**备选方案**:
- ❌ **保持现状**: 8 个独立缓存变量,维护性差
- ❌ **使用 Dictionary[String: Any]**: 失去类型安全
- ❌ **异步 barrier**: 可能导致 set 后立即 get 返回旧值

**实现(方案 A:强类型存储)**:
```swift
private class FilterOptionsCache {
    private struct Storage {
        var functions: [String]?
        var fileNames: [String]?
        var contexts: [String]?
        var threads: [String]?
        var functionCounts: [String: Int]?
        var fileNameCounts: [String: Int]?
        var contextCounts: [String: Int]?
        var threadCounts: [String: Int]?
    }

    private var storage = Storage()
    private let queue = DispatchQueue(label: "cache.queue", attributes: .concurrent)

    func getFunctions() -> [String]? {
        queue.sync { storage.functions }
    }

    func setFunctions(_ value: [String]) {
        queue.sync(flags: .barrier) { storage.functions = value }
    }

    func invalidateAll() {
        queue.sync(flags: .barrier) { storage = Storage() }
    }

    // ... 其他属性的 get/set 方法
}
```

**实现(方案 B:泛型 + 同步 barrier)**:
```swift
private class FilterOptionsCache {
    private var storage: [String: Any] = [:]
    private let queue = DispatchQueue(label: "cache.queue", attributes: .concurrent)

    func value<T>(for key: String) -> T? {
        queue.sync { storage[key] as? T }
    }

    func set<T>(_ value: T, for key: String) {
        queue.sync(flags: .barrier) { storage[key] = value }  // 改为同步
    }

    func invalidate() {
        queue.sync(flags: .barrier) { storage.removeAll() }  // 改为同步
    }
}
```

**决策**: 优先使用方案 A(强类型),代码稍长但类型安全性更好

---

### Decision 5: 使用 performBackgroundTask 确保 CoreData 线程安全

**选择**: 移除 `nonisolated(unsafe)`,使用 CoreData 的 `performBackgroundTask` 处理后台查询

**理由**:
- ✅ CoreData 线程安全:每个 task 有独立的后台 context
- ✅ 自动线程管理:无需手动切换线程
- ✅ 符合 CoreData 最佳实践
- ✅ 避免数据竞争

**备选方案**:
- ❌ **DispatchQueue.global + viewContext**: 违反 CoreData 线程规则,viewContext 只能在主线程访问
- ⚠️ **使用 async/await**: 需要将整个调用链改为 async,影响范围大(可作为未来改进)
- ❌ **保持 nonisolated(unsafe)**: 存在数据竞争风险

**实现(方案 A:performBackgroundTask - 推荐)**:
```swift
@MainActor
public class LogDetailSceneState: ObservableObject {
    @Published var databaseManager: LogDatabaseManager?  // 移除 nonisolated(unsafe)

    func loadAllLogsFromDatabase() {
        // ⚠️ 关键：在进入闭包前捕获必要的值，避免在闭包中访问@Published属性
        guard let dbManager = databaseManager else { return }
        let sessionId = selectedSessionId
        let levels = selectedLevels

        isLoading = true

        // 使用 performBackgroundTask 确保线程安全
        dbManager.persistentContainer.performBackgroundTask { [weak self] context in
            do {
                // 在后台 context 中执行查询
                let events = try dbManager.fetchEvents(
                    in: context,  // 传入后台 context
                    sessionId: sessionId,  // 使用捕获的值
                    levels: levels,  // 使用捕获的值
                    offset: 0,
                    limit: 500
                )

                // 切换到主线程更新 UI
                DispatchQueue.main.async { [weak self] in
                    self?.events = events
                    self?.isLoading = false
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.error = error
                    self?.isLoading = false
                }
            }
        }
    }
}
```

**实现(方案 B:async/await,未来改进)**:
```swift
@MainActor
func loadAllLogsFromDatabase() async {
    guard let dbManager = databaseManager else { return }

    isLoading = true

    do {
        // 使用 async/await 模式
        let events = try await dbManager.fetchEventsAsync(
            sessionId: selectedSessionId,
            levels: selectedLevels,
            offset: 0,
            limit: 500
        )

        self.events = events
        self.isLoading = false
    } catch {
        self.error = error
        self.isLoading = false
    }
}
```

**决策**: 第一阶段使用方案 A(performBackgroundTask),未来可迁移到方案 B

---

### Decision 7: 错误处理和重试策略

**选择**: 实现分层错误处理,包括UI反馈、日志记录和可选的重试机制

**理由**:
- 提升用户体验,避免静默失败
- 便于调试和问题定位
- 提高系统容错能力

**实现**:
```swift
// 错误类型定义
enum LogDatabaseError: LocalizedError {
    case fetchFailed(reason: String)
    case invalidContext
    case queryTimeout

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let reason):
            return "数据库查询失败: \(reason)"
        case .invalidContext:
            return "数据库上下文无效"
        case .queryTimeout:
            return "查询超时"
        }
    }
}

// UI层错误处理
@MainActor
func loadAllLogsFromDatabase(retry: Bool = false) {
    guard let dbManager = databaseManager else {
        self.error = LogDatabaseError.invalidContext
        return
    }

    let sessionId = selectedSessionId
    let levels = selectedLevels

    isLoading = true

    dbManager.persistentContainer.performBackgroundTask { [weak self] context in
        do {
            let events = try dbManager.fetchEvents(
                in: context,
                sessionId: sessionId,
                levels: levels,
                offset: 0,
                limit: 500
            )

            DispatchQueue.main.async { [weak self] in
                self?.events = events
                self?.isLoading = false
                self?.error = nil  // 清除错误
            }
        } catch {
            print("❌ 数据库查询失败: \(error)")  // 日志记录

            DispatchQueue.main.async { [weak self] in
                self?.error = error
                self?.isLoading = false

                // 可选：自动重试一次
                if !retry {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.loadAllLogsFromDatabase(retry: true)
                    }
                }
            }
        }
    }
}
```

**错误处理策略**:
1. **数据库查询失败**: 显示错误提示,提供重试按钮
2. **并发冲突**: 自动重试一次,如仍失败则提示用户
3. **内存警告**: 减少pageSize,释放缓存
4. **查询超时**: 提示用户检查数据量,建议清理旧日志

---

### Decision 8: 数据一致性和刷新策略

**选择**: 采用"快照式分页"模式,接受短暂的数据不一致

**问题场景**:
- 用户正在查看第二页时,数据库新增了日志
- 用户在加载过程中切换了过滤条件
- 多个线程同时修改数据库

**解决方案**:

1. **分页加载期间的数据变化**:
   - 采用快照模式:每次分页查询基于timestamp排序,新日志不影响已加载页
   - 不实时刷新已显示的数据
   - 用户可以手动"下拉刷新"重新加载

2. **过滤条件变化时的处理**:
```swift
// 在过滤条件的didSet中
var selectedLevels: Set<LogLevel> = [] {
    didSet {
        if selectedLevels != oldValue {
            // 重置分页状态
            currentPage = 0
            displayEvents = []
            hasMorePages = true

            // 取消正在进行的加载
            cancelPendingLoads()

            // 重新加载
            loadInitialLogs()
        }
    }
}
```

3. **并发写入冲突**:
   - CoreData的performBackgroundTask自动处理context隔离
   - 读取操作使用独立的后台context,不影响主线程
   - 写入操作使用另一个后台context,通过NSManagedObjectContextDidSave通知同步

4. **刷新策略**:
   - 初始加载:显示最新数据
   - 分页加载:追加数据,不刷新已有数据
   - 手动刷新:清空现有数据,重新加载第一页
   - 数据库写入通知:仅更新统计数据,不影响列表显示

**取舍**:
- ✅ 优先保证性能和用户体验
- ✅ 接受短暂的数据不一致(几秒到几分钟)
- ❌ 不实现实时同步(会影响性能)
- ✅ 提供手动刷新机制

---

### Decision 6: 静态缓存 Bundle 模型 URL

**选择**: 将模型 URL 查询提取为静态 computed property

**理由**:
- 仅在第一次访问时查询,后续访问使用缓存
- 代码更清晰,易于测试
- 性能提升(虽然微小,但无负面影响)

**备选方案**:
- **保持现状**: 每次初始化都查询,虽然 lazy 仅初始化一次,但逻辑可以更简洁
- **使用 lazy 变量**: 需要额外存储属性,不如静态属性简洁

**实现**:
```swift
private static let modelURL: URL = {
    let candidatePaths: [(resource: String, extension: String)] = [
        ("LoggerKit", "momd"),
        ("LoggerKit", "mom"),
        ("LoggerKit", "xcdatamodeld")
    ]

    for (resource, ext) in candidatePaths {
        if let url = Bundle.module.url(forResource: resource, withExtension: ext) {
            return url
        }
    }

    fatalError("Failed to find LoggerKit CoreData model in bundle")
}()
```

## Risks / Trade-offs

### Risk 1: CoreData 线程安全(已修复)

**原风险**: 在后台线程访问 viewContext 违反 CoreData 线程规则

**修复方案**: 使用 `performBackgroundTask` 创建后台 context

**剩余风险**: 低,但需要确保所有数据库操作都迁移到新模式

**缓解措施**:
- 使用 Thread Sanitizer 检测数据竞争
- 并发压力测试(多线程同时查询)
- 代码审查确保没有遗漏的 viewContext 后台访问

---

### Risk 2: 数据库层过滤逻辑复杂度

**风险**: 将所有过滤条件转换为 NSPredicate 可能遗漏边界情况

**缓解措施**:
- 编写全面的单元测试覆盖各种过滤组合:
  - 单一条件过滤(级别、会话、搜索文本)
  - 多条件组合过滤
  - 空条件、空结果集
  - 特殊字符搜索(转义、大小写)
- 对比数据库过滤和内存过滤的结果一致性
- 性能测试验证索引是否生效

---

### Risk 3: 数据库查询结果准确性

**风险**: 合并查询后的统计结果可能与之前不一致

**缓解措施**:
- 编写单元测试对比优化前后的查询结果
- 验证总数等于各级别之和
- 使用小数据集手动验证
- 在测试环境充分验证后再发布

---

### Risk 4: 分页加载与过滤条件变化的交互

**风险**: 用户在加载第二页时改变过滤条件,可能导致数据重复或缺失

**缓解措施**:
- 当过滤条件变化时,重置分页状态(currentPage = 0, displayEvents = [])
- 在 UI 层添加加载指示器,防止用户在加载中快速切换条件
- 使用防抖(debounce)延迟搜索文本输入

---

### Risk 5: FilterOptionsCache 线程安全

**风险**: 虽然使用了 concurrent queue + barrier,但仍需验证无竞态条件

**缓解措施**:
- 编写并发测试:多线程同时读写缓存
- 使用 Thread Sanitizer 检测
- 考虑使用方案 A(强类型存储)减少类型转换错误

---

### Risk 6: List 渲染兼容性

**风险**: `List` 在某些 iOS 版本上可能表现不一致

**缓解措施**:
- 在最低支持版本 iOS 15 上进行测试
- 保持简单的 List 配置,避免复杂嵌套
- 如遇问题,可回退到优化后的 LazyVStack 方案

## Migration Plan

### 阶段 1A: 准备(2小时)
1. 创建特性分支 `feature/optimize-phase1-performance`
2. **建立性能基准测试框架**:
   - 编写性能测试代码(测量查询时间、渲染时间、内存占用)
   - 记录优化前的基准数据
3. 准备测试数据集(1万、5万、10万条日志)
4. 在 CI 中启用 Thread Sanitizer

### 阶段 1A: 低风险优化实施(3小时)
1. **合并数据库统计查询** (2小时)
   - 重构 fetchStatistics() 方法
   - 单元测试对比结果准确性
   - 性能测试验证提升效果

2. **优化 Bundle 资源查询** (30分钟)
   - 提取静态缓存属性
   - 代码清理

3. **测试验证** (30分钟)
   - 运行单元测试
   - 性能基准对比
   - Thread Sanitizer 验证

### 阶段 1B: 架构改进实施(12-15小时)
1. **实现数据库层过滤和分页** (4-5小时)
   - 重构 fetchEvents() 方法支持过滤参数
   - 实现 NSPredicate 构建逻辑
   - 支持 offset/limit 分页
   - 单元测试覆盖各种过滤组合
   - 性能测试验证

2. **优化列表渲染** (3小时)
   - 替换为 List 组件
   - 实现分页加载 UI 逻辑
   - 处理过滤条件变化时的分页重置
   - UI 测试验证

3. **修复并发安全** (3小时)
   - 移除 nonisolated(unsafe)
   - 使用 performBackgroundTask
   - 修改 fetchEvents() 接受 context 参数
   - 并发测试 + Thread Sanitizer 验证

4. **重构缓存管理** (2小时)
   - 创建 FilterOptionsCache 类(强类型存储)
   - 迁移现有缓存逻辑
   - 并发测试验证

### 阶段 1B: 测试验证(4-6小时)
1. 完整的单元测试套件
2. 性能基准测试对比(与阶段 1A 后对比)
3. 真机测试(iPhone, iPad,大数据量场景)
4. 并发压力测试(多线程快速切换过滤条件)
5. Instruments 分析(Time Profiler, Allocations, Leaks)
6. Thread Sanitizer 验证

### 阶段 1C: 评估和决策(1小时)
1. 评估阶段 1B 后的性能数据
2. 决定是否需要实施 filteredEvents 优化
3. 如需要,设计具体方案(数据库过滤 vs Combine 响应式)

### 阶段 2: 准备交付(1小时)
1. 代码审查
2. 更新文档和注释
3. 准备性能对比数据报告
4. 等待用户验收

### 回滚计划
- 按阶段提交,每个阶段独立可回滚
- Git revert 回滚提交
- 保留性能测试数据用于对比
- 如遇严重问题,可只保留阶段 1A 的优化

**总时间估计**: 35-40 小时(不含用户验收和发布)

**时间调整理由**:
- 数据库索引验证和性能测试: +2-3小时
- 边界条件测试覆盖: +2小时
- 错误处理实现和测试: +2-3小时
- 数据一致性策略实现: +1-2小时
- Code review和返工预留: +3-5小时

## Open Questions

### Q1: 数据库层过滤 vs 内存层过滤的最终架构(已决策)

**决策**: 将过滤逻辑下推到数据库层

**理由**: 减少内存占用,支持真正的分页,架构更清晰

**影响**: filteredEvents 计算属性可能不再需要

---

### Q2: CoreData 并发模式选择(已决策)

**决策**: 第一阶段使用 performBackgroundTask,未来可迁移到 async/await

**理由**: performBackgroundTask 是 CoreData 标准做法,稳定可靠

**后续改进**: 当项目全面支持 Swift Concurrency 时,可迁移到 async/await

---

### Q3: filteredEvents 优化是否仍需要?(待评估)

**当前决策**: 先实施阶段 1B(数据库层过滤),再决定

**待验证**:
- 数据库层过滤后,UI 层是否还有性能瓶颈?
- 如果需要,应该使用 Combine 响应式还是简单的 @Published 数组?

**建议**: 基于阶段 1B 的性能数据再决定

---

### Q4: FilterOptionsCache 实现方案选择

**当前倾向**: 使用强类型存储(方案 A)

**待讨论**:
- 强类型存储代码量更大,但类型安全
- 泛型 + 同步 barrier 代码简洁,但需要类型转换

**建议**: 优先使用方案 A,如果代码量成为问题再考虑方案 B

---

### Q5: 是否需要配置化的分页大小?

**当前决策**: 使用固定的 pageSize = 500

**待讨论**:
- 是否应该根据设备性能动态调整?
- 是否应该暴露给用户配置?

**建议**: 暂时使用固定值,根据实际反馈再决定

---

### Q6: 缓存是否需要持久化?

**当前决策**: 缓存仅在内存中,App 重启后清空

**理由**: 避免引入数据一致性问题

**建议**: 第一阶段不持久化

---

### Q7: 是否需要添加性能监控?

**当前决策**: 第一阶段建立性能基准测试,不引入 Metrics 框架

**待讨论**:
- 是否应该在生产环境记录关键操作的耗时?
- 是否应该集成 MetricKit 进行性能追踪?

**建议**: 第一阶段专注于优化,性能监控作为后续改进项

---

### Q8: List vs LazyVStack 的最终选择?

**当前倾向**: 使用 List

**待验证**:
- 在 iOS 15-17 各版本的表现
- 自定义样式的灵活性
- 性能提升是否显著

**备选**: 如果 List 存在兼容性问题,退而使用 LazyVStack

---

### Q9: 数据库索引的具体实现方式?

**当前决策**: 在CoreData模型中添加索引

**待确认**:
- 是否需要修改.xcdatamodeld文件添加索引?
- 是否需要创建轻量级迁移?
- 索引对数据库文件大小的影响?

**建议**: 第一阶段先测试无索引的性能,如果CONTAINS查询成为瓶颈再考虑添加索引

---

### Q10: 是否需要动态pageSize?

**当前决策**: 使用固定pageSize = 500

**待讨论**:
- 是否应该根据设备性能调整(iPhone vs iPad)?
- 是否应该根据可用内存动态调整?
- 是否暴露给用户配置?

**建议**: 第一阶段使用固定值,根据真机测试数据再决定

---

### Q11: 搜索文本最小长度限制?

**当前决策**: 不限制

**待讨论**:
- CONTAINS查询在大数据量下可能很慢
- 是否限制searchText最小长度(如>=2或3个字符)?
- 是否在UI层添加debounce延迟?

**建议**: UI层添加300ms debounce,暂不限制最小长度
