# LoggerKit 优化路线图

## 📅 文档信息

- **创建日期**: 2025-12-12
- **最后更新**: 2025-12-12
- **当前分支**: feature/optimization_251210
- **整体进度**: 7/18 = 39%

---

## 🎯 优化总览

### 整体进度

```
✅ 阶段1 (性能优化):     7/7  = 100% ✅
⚠️  阶段2 (代码质量):     0/5  =   0% ⚠️
❌ 阶段3 (架构重构):     0/3  =   0% ❌

总计: 7/15 = 47%
预计剩余工作量: ~22小时
```

---

## ✅ 阶段1: 核心性能优化 (已完成)

**状态**: ✅ 完成
**完成日期**: 2025-12-12
**工作量**: ~8小时
**分支**: feature/optimization_251210

### 已完成任务

| # | 任务 | 状态 | 提交 | 收益 |
|---|------|------|------|------|
| 1.1 | 数据库查询合并 | ✅ | 0d812ea | 9次→2次，查询时间-80% |
| 1.2 | CoreDataStack资源优化 | ✅ | 0d812ea | 静态缓存，启动时间微幅改善 |
| 1.3 | 数据库层过滤实现 | ✅ | 84d7680 | 内存占用-70-90% |
| 1.4 | 并发安全修复 | ✅ | 84d7680 | 消除CoreData多线程风险 |
| 1.5 | 列表虚拟化渲染 | ✅ | 2e7aa0f | List + 分页加载 |
| 1.6 | 缓存管理重构 | ✅ | a563a52 | FilterOptionsCache统一管理 |
| 1.7 | 后续Bug修复 | ✅ | ea39cd7 | messageKeywords过滤等3个缺陷 |

### 关键成果

- **性能提升**: 数据库查询80%，过滤逻辑数据库层处理
- **内存优化**: 大数据集内存占用减少70-90%
- **并发安全**: 修复CoreData多线程访问隐患
- **代码质量**: 删除61行死代码，统一缓存管理

### 相关文件

- 📄 [PROGRESS.md](./Examples/iOS/LoggerKitExample/openspec/changes/archive/2025-12-12-optimize-phase1-performance/PROGRESS.md)
- 📋 提交历史: 0d812ea, 84d7680, 2e7aa0f, a563a52, ea39cd7

---

## ⚠️ 阶段2: 代码质量优化 (待开始)

**状态**: ⚠️ 待开始
**优先级**: 中-高
**预计工作量**: ~6小时
**建议时间**: 1-2周内完成

### 任务清单

#### 🔥 2.1 Timer 泄漏修复 (最高优先级)

**工作量**: 1小时
**优先级**: 🔥 高 (稳定性关键)

**问题描述**:
- 文件: `Sources/LoggerKit/Database/CoreDataDestination.swift:40-49`
- Timer 可能导致引用循环和内存泄漏
- 当前使用 Foundation.Timer，在 main thread 创建

**优化方案**:
```swift
// 当前代码
private var flushTimer: Timer?

private func setupFlushTimer() {
    DispatchQueue.main.async { [weak self] in
        self?.flushTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: true
        ) { [weak self] _ in
            self?.flush()
        }
    }
}
```

**修复代码**:
```swift
// 优化后 - 使用DispatchSourceTimer
private var flushTimer: DispatchSourceTimer?

private func setupFlushTimer() {
    let queue = DispatchQueue(label: "com.loggerkit.flush", qos: .utility)
    let timer = DispatchSource.makeTimerSource(queue: queue)

    timer.setEventHandler { [weak self] in
        self?.flush()
    }

    timer.schedule(deadline: .now(), repeating: 5.0)
    timer.resume()

    self.flushTimer = timer
}

deinit {
    flushTimer?.cancel()
    flushTimer = nil
    flush()  // 最后一次刷新
}
```

**预期收益**:
- ✅ 消除内存泄漏隐患
- ✅ 更好的线程控制
- ✅ 自动清理机制

**风险**: 低

---

#### 🚀 2.2 搜索结果单次遍历优化

**工作量**: 2小时
**优先级**: 🚀 中-高 (性能提升)

**问题描述**:
- 文件: `Sources/LoggerKit/UI/LogDetailSceneState.swift:296-360`
- 每个搜索字段独立遍历 events 数组
- 如果有5个字段，就遍历5次，复杂度 O(n*m)

**当前代码**:
```swift
var searchResults: SearchResults {
    var results = SearchResults()

    // 遍历1: message
    for event in events {
        if event.message.contains(searchText) {
            results.message.insert(event.message)
        }
    }

    // 遍历2: function
    for event in events {
        if event.function.contains(searchText) {
            results.function.insert(event.function)
        }
    }

    // ... 其他字段也各自遍历一次
}
```

**优化方案**:
```swift
var searchResults: SearchResults {
    var results = SearchResults()
    let lowercased = searchText.lowercased()

    var messageCounts: [String: Int] = [:]
    var functionCounts: [String: Int] = [:]
    // ... 其他计数器

    // 单次遍历
    for event in events {
        if searchFields.contains(.message) && event.message.lowercased().contains(lowercased) {
            messageCounts[event.message, default: 0] += 1
        }

        if searchFields.contains(.function) && event.function.lowercased().contains(lowercased) {
            functionCounts[event.function, default: 0] += 1
        }

        // ... 其他字段
    }

    // 构建结果
    results.message = messageCounts.map {
        SearchResultItem(field: .message, value: $0.key, matchCount: $0.value)
    }
    // ... 其他字段

    return results
}
```

**预期收益**:
- ✅ 搜索响应时间减少 50-70%
- ✅ 减少临时对象分配
- ✅ 添加匹配计数信息

**风险**: 低

---

#### 🛠️ 2.3 错误处理统一化

**工作量**: 1-2小时
**优先级**: 🛠️ 中 (可观测性)

**问题描述**:
- 多个文件使用 `print()` 进行错误处理
- 生产环境难以追踪和调试
- 缺乏统一的日志级别管理

**影响文件**:
- `LogDatabaseManager.swift`: 309, 312, 340, 343, 367, 370行
- `LogDetailSceneState.swift`: 558, 584, 643, 663, 699行
- `CoreDataStack.swift`: 89行

**当前代码**:
```swift
do {
    try context.save()
} catch {
    print("Failed to save: \(error)")  // ❌ 使用print
}
```

**优化方案**:
```swift
do {
    try context.save()
} catch {
    Logger(context: "CoreData").error("Failed to save logs: \(error)")  // ✅
    throw LoggerKitError.databaseWriteFailed(underlying: error)
}
```

**实施步骤**:
1. 全局搜索 `print(` 找到所有位置
2. 根据错误类型选择合适的日志级别 (error/warning)
3. 使用 Logger 替换 print
4. 考虑是否需要抛出异常

**预期收益**:
- ✅ 生产环境错误可追踪
- ✅ 统一日志格式
- ✅ 支持日志级别过滤

**风险**: 极低

---

#### 📦 2.4 fileName 计算优化 (可选)

**工作量**: 1小时
**优先级**: ⭕ 中-低 (性能微优化)

**问题描述**:
- 文件: `Sources/LoggerKit/Parser/LogParser.swift:80-86`
- `fileName` 是计算属性，每次访问都重新计算
- 字符串 split 操作被重复执行

**当前代码**:
```swift
public struct LogEvent {
    public let file: String

    var fileName: String {
        if let lastPart = file.components(separatedBy: "/").last,
           let fileName = lastPart.components(separatedBy: ".").first {
            return fileName
        }
        return ""
    }
}
```

**优化方案**:
```swift
public struct LogEvent {
    public let file: String
    public let fileName: String  // 改为存储属性

    public init(..., file: String, ...) {
        self.file = file

        // 初始化时计算一次
        if let lastPart = file.components(separatedBy: "/").last,
           let name = lastPart.components(separatedBy: ".").first {
            self.fileName = name
        } else {
            self.fileName = ""
        }
    }
}
```

**预期收益**:
- ✅ 减少重复字符串操作
- ✅ 微幅改善内存效率

**风险**: 低 (需要修改 LogEvent 结构体，确保所有初始化路径都更新)

**注意**: 需要更新所有创建 LogEvent 的地方

---

#### 📝 2.5 Magic Numbers 提取 (可选)

**工作量**: 1小时
**优先级**: ⭕ 低 (可维护性)

**问题描述**:
- 硬编码数值散落在代码中
- 修改时需要在多处查找替换
- 不便于全局调整

**当前硬编码位置**:
```swift
// LogDetailSceneState.swift
let pageSize = 500                    // 第 103 行
let limit: Int = 10000                // 第 551 行

// CoreDataDestination.swift
batchSize: Int = 50                   // 第 25 行

// LogFilterSheet.swift
.fetchLimit = 100                     // 第 197 行

// LoggerEngineConfiguration
maxDatabaseSize: Int64 = 100 * 1024 * 1024
maxRetentionDays: Int = 30
```

**优化方案**:
```swift
// 新增文件: Sources/LoggerKit/Utilities/LoggerKitConstants.swift
public enum LoggerKitConstants {
    public enum Database {
        public static let maxDatabaseSize: Int64 = 100 * 1024 * 1024  // 100MB
        public static let maxRetentionDays: Int = 30
        public static let defaultPageSize: Int = 500
        public static let batchWriteSize: Int = 50
        public static let topFunctionsLimit: Int = 100
    }

    public enum UI {
        public static let searchPreviewLimit: Int = 5
        public static let initialLogLoadLimit: Int = 10000
    }

    public enum Performance {
        public static let flushInterval: TimeInterval = 5.0
    }
}

// 使用
let pageSize = LoggerKitConstants.Database.defaultPageSize
let batchSize = LoggerKitConstants.Database.batchWriteSize
```

**预期收益**:
- ✅ 提升可维护性
- ✅ 便于全局调整参数
- ✅ 代码意图更清晰

**风险**: 极低

---

### 阶段2总结

**推荐优先级排序**:
1. 🔥 2.1 Timer 泄漏修复 (必须 - 稳定性)
2. 🚀 2.2 搜索结果单次遍历 (推荐 - 性能)
3. 🛠️ 2.3 错误处理统一化 (推荐 - 可观测性)
4. ⭕ 2.4 fileName 优化 (可选 - 微优化)
5. ⭕ 2.5 Magic Numbers (可选 - 维护性)

**最小必做集**: 2.1 + 2.2 + 2.3 = ~4小时

---

## ❌ 阶段3: 架构重构 (计划中)

**状态**: ❌ 未开始
**优先级**: 中-低
**预计工作量**: ~16小时
**建议时间**: 1-2个月内完成

### 任务清单

#### 3.1 单元测试框架搭建

**工作量**: 4-6小时
**优先级**: 中 (为后续重构建立安全网)

**目标**:
- 为核心业务逻辑添加测试覆盖
- 建立重构保护机制
- 提升代码质量信心

**测试范围**:

1. **LogDatabaseManager 测试**
   - fetchEvents() 各种过滤条件
   - fetchStatistics() 统计准确性
   - deleteOldLogs() 清理逻辑
   - 分页功能验证

2. **LogParser 测试**
   - 日志解析正确性
   - 边界条件处理
   - 错误输入容错

3. **FilterOptionsCache 测试**
   - 并发读写安全性
   - 缓存失效逻辑
   - 类型安全验证

**测试工具**:
- XCTest
- 可能需要 CoreData in-memory store

**预期收益**:
- ✅ 测试覆盖率 0% → 60%+
- ✅ 为重构建立安全网
- ✅ 防止功能回归

**前置条件**: 无

---

#### 3.2 LogDetailSceneState 职责拆分

**工作量**: 6-8小时
**优先级**: 中 (长期可维护性)

**问题描述**:
- 文件: `Sources/LoggerKit/UI/LogDetailSceneState.swift` (700+行)
- 单个类承担太多职责:
  - UI 状态管理
  - 数据加载
  - 过滤逻辑
  - 缓存管理
  - 数据库交互

**重构方案**:

```
LogDetailSceneState (700+行)
    ↓
    ↓ 拆分
    ↓
├─ LogDetailSceneState (200行)       - UI状态管理
├─ LogDataRepository (150行)         - 数据加载
└─ LogFilterService (100行)          - 过滤逻辑
```

**详细设计**:

```swift
// 1. 数据仓库 - 负责数据加载
protocol LogDataRepositoryProtocol {
    func fetchEvents(
        sessionId: String,
        levels: Set<LogEvent.Level>,
        search: String,
        filters: LogFilters,
        offset: Int,
        limit: Int
    ) async throws -> [LogEvent]

    func fetchStatistics(sessionId: String) async throws -> LogStatistics
}

final class LogDataRepository: LogDataRepositoryProtocol {
    private let databaseManager: LogDatabaseManager

    // 实现数据加载逻辑
}

// 2. 过滤服务 - 负责过滤逻辑
protocol LogFilterServiceProtocol {
    func applyFilters(
        events: [LogEvent],
        search: String,
        levels: Set<LogEvent.Level>,
        filters: LogFilters
    ) -> [LogEvent]
}

final class LogFilterService: LogFilterServiceProtocol {
    // 实现过滤逻辑（如果需要内存过滤）
}

// 3. 简化的 State - 只负责UI状态
@MainActor
public class LogDetailSceneState: ObservableObject {
    // UI状态
    @Published public var selectedLevels: Set<LogEvent.Level>
    @Published public var searchText: String = ""
    @Published public var displayEvents: [LogEvent] = []

    // 依赖注入
    private let repository: LogDataRepositoryProtocol
    private let filterService: LogFilterServiceProtocol

    // 简化的业务逻辑
    public func loadLogs() async {
        // 调用 repository
    }
}
```

**实施步骤**:
1. 创建 LogDataRepository，迁移数据加载逻辑
2. 创建 LogFilterService，迁移过滤逻辑
3. 简化 LogDetailSceneState，只保留 UI 状态
4. 使用单元测试验证功能不变
5. 更新 UI 层调用

**预期收益**:
- ✅ 代码行数减少 60%
- ✅ 单一职责原则
- ✅ 易于单元测试
- ✅ 提升可维护性

**前置条件**: 3.1 完成 (有测试保护)

---

#### 3.3 依赖注入实现

**工作量**: 4-6小时
**优先级**: 中 (提升灵活性)

**目标**:
- 使用协议抽象依赖
- 支持单元测试 mock
- 降低组件耦合

**重构范围**:

```swift
// 1. 定义协议
protocol LogDatabaseManagerProtocol {
    func fetchEvents(...) async throws -> [LogEvent]
    func fetchStatistics(...) async throws -> LogStatistics
}

// 2. LogDatabaseManager 遵循协议
extension LogDatabaseManager: LogDatabaseManagerProtocol {
    // 已有实现
}

// 3. 依赖注入
public class LogDetailSceneState: ObservableObject {
    private let databaseManager: LogDatabaseManagerProtocol

    public init(
        sessionId: String,
        databaseManager: LogDatabaseManagerProtocol = LogDatabaseManager.shared
    ) {
        self.databaseManager = databaseManager
        // ...
    }
}

// 4. 测试时使用 Mock
class MockDatabaseManager: LogDatabaseManagerProtocol {
    var mockEvents: [LogEvent] = []

    func fetchEvents(...) async throws -> [LogEvent] {
        return mockEvents
    }
}

// 测试
func testLoadLogs() async {
    let mock = MockDatabaseManager()
    mock.mockEvents = [/* test data */]

    let state = LogDetailSceneState(
        sessionId: "test",
        databaseManager: mock
    )

    await state.loadLogs()

    XCTAssertEqual(state.displayEvents.count, mock.mockEvents.count)
}
```

**预期收益**:
- ✅ 单元测试更容易
- ✅ 降低耦合度
- ✅ 支持替换实现

**前置条件**: 3.2 完成

---

### 阶段3总结

**推荐执行顺序**:
1. 3.1 单元测试 (先建立安全网)
2. 3.2 职责拆分 (有测试保护)
3. 3.3 依赖注入 (进一步解耦)

**注意事项**:
- 建议分3个独立 PR 提交
- 每个 PR 都要确保测试通过
- 重构前后功能保持一致

---

## 📈 整体时间规划

### 近期 (1-2周)

**目标**: 完成阶段2核心任务

```
Week 1:
  Day 1-2: 2.1 Timer 泄漏修复 (1h)
  Day 3-4: 2.2 搜索单次遍历 (2h)
  Day 5:   2.3 错误处理统一化 (1-2h)

Week 2:
  Day 1-2: 验证和测试
  Day 3-5: (可选) 2.4, 2.5
```

**里程碑**: 阶段2完成，性能和稳定性进一步提升

### 中期 (1-2月)

**目标**: 启动阶段3架构重构

```
Month 1:
  Week 1-2: 3.1 单元测试框架 (4-6h)
  Week 3-4: 规划详细重构方案

Month 2:
  Week 1-2: 3.2 职责拆分 (6-8h)
  Week 3-4: 3.3 依赖注入 (4-6h)
```

**里程碑**: 架构重构完成，可测试性和可维护性显著提升

---

## 🎯 关键指标追踪

### 性能指标

| 指标 | 优化前 | 阶段1后 | 阶段2目标 |
|------|--------|---------|-----------|
| 数据库查询次数 | 9次 | 2次 ✅ | - |
| 列表渲染 | 全量 | 虚拟化+分页 ✅ | - |
| 搜索响应时间 | 300ms | - | <150ms |
| 内存占用 | 80-100MB | 20-30MB ✅ | - |

### 代码质量指标

| 指标 | 当前 | 阶段2目标 | 阶段3目标 |
|------|------|-----------|-----------|
| LogDetailSceneState 行数 | 700+ | - | 200-300 |
| 测试覆盖率 | 0% | - | 60%+ |
| print() 错误处理 | 15+ | 0 | - |
| Timer 泄漏风险 | 存在 | 消除 | - |

---

## 📚 相关文档

- 📊 [分析总结](./ANALYSIS_SUMMARY.txt) - 整体分析结果
- 📝 [详细分析报告](./CODE_ANALYSIS_REPORT.md) - 所有问题详情
- 🚀 [阶段1进度](./Examples/iOS/LoggerKitExample/openspec/changes/archive/2025-12-12-optimize-phase1-performance/PROGRESS.md) - 已完成工作
- 🔍 [快速参考](./OPTIMIZATION_QUICK_REFERENCE.md) - 快速查找代码片段

---

## 🔄 更新历史

| 日期 | 版本 | 变更 |
|------|------|------|
| 2025-12-12 | 1.0 | 初始创建，阶段1完成后重新规划 |

---

**总结**: 阶段1的核心性能优化已成功完成，剩余工作分为阶段2(代码质量)和阶段3(架构重构)两个清晰的阶段。建议优先完成阶段2的关键任务(Timer修复、搜索优化、错误处理)，然后根据实际需求决定是否启动阶段3的架构重构。
