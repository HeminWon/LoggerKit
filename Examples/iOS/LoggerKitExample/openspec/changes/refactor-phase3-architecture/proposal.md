# Change: 阶段3架构重构 - LogDetailSceneState 职责拆分

## Why

LogDetailSceneState 当前存在严重的架构问题,影响代码可维护性和扩展性:

1. **职责过载**: 单个类承担 8 个不同职责
   - UI 状态管理(16个 @Published 属性)
   - 过滤条件管理(7个过滤字段,各自 didSet)
   - 数据加载逻辑(数据库查询、分页控制)
   - Task 生命周期管理(创建、取消、追踪)
   - 缓存管理(8个缓存变量)
   - 搜索逻辑(5次独立遍历计算结果)
   - 导出配置
   - 统计信息加载

2. **代码规模失控**: 767 行代码集中在单个类中
   - 违反单一职责原则
   - 修改风险高(牵一发动全身)
   - 难以理解和维护

3. **可测试性差**:
   - 无法单独测试各个职责
   - 依赖难以替换(直接使用单例)
   - 缺少测试覆盖(当前 0%)

4. **性能隐患**:
   - searchResults 计算属性重复遍历(5次)
   - 7个过滤字段各自触发 didSet 重新加载

5. **并发复杂度**:
   - Task 管理散落各处
   - 生命周期控制不清晰

这些问题导致:
- 代码维护成本高,修改困难
- 无法进行有效的单元测试
- 团队协作困难(大文件冲突多)
- 新功能开发受阻
- 技术债务累积

## What Changes

采用**渐进式重构**策略,将 LogDetailSceneState 拆分为职责清晰、可测试的组件:

### 重构目标

**架构层面**:
- LogDetailSceneState 职责数量: 8个 → 2个(UI协调)
- 代码行数: 767行 → ~250行(-67%)
- @Published 属性: 16个 → 6个(-63%)
- 依赖注入: 无 → 完整支持

**质量层面**:
- 可测试性: 困难 → 容易
- 职责划分: 混杂 → 清晰
- 组件耦合: 高 → 低

### 重构步骤

#### 步骤1: 提取 FilterState (2-3小时)

**新建组件**: `Sources/LoggerKit/UI/FilterState.swift`

**职责**: 统一管理所有过滤条件
- 迁移 7 个过滤字段(@Published)
- 提供统一的 onFilterChanged 回调
- 实现过滤器操作方法(add/remove/toggle/reset)
- 计算激活的过滤器数量

**迁移的属性**:
```swift
// 从 LogDetailSceneState 移除,迁移到 FilterState
- selectedLevels: Set<LogEvent.Level>
- selectedFunctions: Set<String>
- selectedFileNames: Set<String>
- selectedContexts: Set<String>
- selectedThreads: Set<String>
- selectedMessageKeywords: Set<String>
- selectedSessionId: String?
```

**集成方式**:
```swift
// LogDetailSceneState 中
public let filterState: FilterState

// 订阅变更
filterState.onFilterChanged = { [weak self] in
    self?.refresh()
}
```

**预期收益**:
- 消除 7 个 didSet 重复代码
- 代码减少 ~100 行
- 过滤逻辑独立可测

**风险**: 低
- 仅重构内部实现
- 对外API保持兼容(通过 filterState.selectedLevels 访问)

---

#### 步骤2: 提取 DataLoaderService (3-4小时)

**新建组件**:
- `Sources/LoggerKit/UI/DataLoader/LogDataLoaderProtocol.swift`
- `Sources/LoggerKit/UI/DataLoader/LogDataLoader.swift`
- `Sources/LoggerKit/UI/DataLoader/LoadingState.swift`

**职责**: 统一数据加载和 Task 管理
- 封装数据库查询逻辑
- 统一 Task 创建、取消、追踪
- 管理后台线程和 CoreData context
- 提供 loadEvents() 和 loadStatistics() 接口

**迁移的逻辑**:
```swift
// 从 LogDetailSceneState 移除,迁移到 DataLoader
- loadLogsFromDatabase() - 复杂的查询逻辑
- loadStatistics() - 统计查询
- loadTask: Task<Void, Never>? - Task 管理
- performBackgroundTask 调用封装
```

**新增状态枚举**:
```swift
public enum LoadingState: Equatable {
    case idle
    case loading(progress: String?)
    case loadingMore
    case loaded
    case failed(Error)
}
```

**集成方式**:
```swift
// LogDetailSceneState 中
private let dataLoader: LogDataLoaderProtocol

public func loadLogs(resetPagination: Bool) async {
    let events = try await dataLoader.loadEvents(
        sessionId: filterState.selectedSessionId,
        filterState: filterState,
        searchText: searchText,
        offset: currentPage * pageSize,
        limit: pageSize
    )
    // 更新 displayEvents
}
```

**预期收益**:
- Task 管理统一化
- 数据加载逻辑独立
- 代码再减少 ~100 行
- 支持协议注入(可测试)

**风险**: 中
- 需要确保线程安全
- Task 取消逻辑要正确

---

#### 步骤3: 依赖注入改造 (2-3小时)

**新建协议**:
- `Sources/LoggerKit/Database/LogDatabaseManagerProtocol.swift`

**改造内容**:
1. 定义 LogDatabaseManagerProtocol
2. LogDatabaseManager 遵循协议
3. DataLoader 使用协议依赖
4. LogDetailSceneState 支持依赖注入

**依赖注入模式**:
```swift
@MainActor
public class LogDetailSceneState: ObservableObject {
    // 完整 DI 初始化(用于测试)
    public init(
        dataLoader: LogDataLoaderProtocol,
        filterState: FilterState
    ) { ... }

    // 便利初始化(生产环境)
    public convenience init(prefix: String, identifier: String) {
        let dbManager = LogDatabaseManager.shared
        let dataLoader = LogDataLoader(databaseManager: dbManager)
        let filterState = FilterState()

        self.init(
            dataLoader: dataLoader,
            filterState: filterState
        )
    }
}
```

**预期收益**:
- 支持 Mock 测试
- 依赖可替换
- 组件解耦

**风险**: 低
- 不破坏现有 API
- 渐进式引入

---

#### 步骤4: 提取 SearchState (可选, 2-3小时)

**新建组件**: `Sources/LoggerKit/UI/SearchState.swift`

**职责**: 独立搜索逻辑 + 性能优化
- 管理搜索文本和搜索范围
- **单次遍历计算搜索结果**(优化前是5次)
- 提供 onSearchChanged 回调

**性能优化**:
```swift
// 优化前: 5次独立遍历
for event in events { if message.contains() { ... } }  // 遍历1
for event in events { if function.contains() { ... } } // 遍历2
... // 共5次

// 优化后: 单次遍历
for event in events {
    if message.contains() { messageCounts[...] += 1 }
    if function.contains() { functionCounts[...] += 1 }
    ... // 一次遍历完成所有统计
}
```

**预期收益**:
- 搜索响应时间减少 50-70%
- 搜索逻辑独立可测
- 顺便解决阶段2.2的性能问题

**风险**: 低
- 纯计算逻辑重构

---

### 重构前后架构对比

**重构前**:
```
LogDetailSceneState (767行)
├─ UI状态 (16个@Published)
├─ 7个过滤字段 (各自didSet)
├─ 数据加载逻辑 (100+行)
├─ Task管理 (散落各处)
├─ 搜索逻辑 (5次遍历)
├─ 缓存管理 (已优化)
└─ 统计加载 (混杂)
```

**重构后**:
```
LogDetailSceneState (~250行)
├─ UI协调职责
├─ 分页状态管理
└─ 依赖注入集成

FilterState (新建, ~150行)
└─ 7个过滤字段统一管理

DataLoader (新建, ~150行)
├─ 数据库查询封装
└─ Task生命周期管理

SearchState (可选, ~100行)
└─ 搜索逻辑 + 单次遍历优化
```

### 不包含的内容

本次重构**明确排除**以下内容:
- ❌ 单元测试框架搭建
- ❌ 详细测试用例编写
- ❌ Mock 类实现
- ❌ Timer 泄漏修复(阶段2任务)
- ❌ 错误处理统一化(阶段2任务)
- ❌ fileName 优化(阶段2任务)
- ❌ Magic Numbers 提取(阶段2任务)

**原因**: 专注核心架构重构,避免范围蔓延

## How to Test

### 功能完整性验证

每完成一步重构,必须验证:

1. **编译验证**
   - swift build 成功
   - 无编译警告
   - 无类型错误

2. **Example 项目功能验证**
   - [ ] 日志列表正常显示
   - [ ] 过滤功能完整可用(7个维度)
   - [ ] 搜索功能正常工作
   - [ ] 分页加载正确
   - [ ] 统计信息准确
   - [ ] UI 交互流畅

3. **性能基准验证**
   - [ ] 初始加载时间 ≤ 重构前
   - [ ] 搜索响应时间 ≤ 重构前(步骤4应更快)
   - [ ] 滚动帧率 ≥ 60fps
   - [ ] 内存占用 ≤ 重构前

### 风险控制验证

1. **状态同步**
   - 快速切换多个过滤条件
   - 验证 filterState 和 UI 状态一致

2. **Task 取消**
   - 快速切换过滤条件
   - 验证旧 Task 被正确取消

3. **线程安全**
   - 并发场景测试
   - 验证无崩溃、无数据竞争

### 渐进式验证流程

```
完成步骤1
  ↓
编译 + Example验证 + 提交
  ↓
完成步骤2
  ↓
编译 + Example验证 + 提交
  ↓
完成步骤3
  ↓
编译 + Example验证 + 提交
  ↓
(可选)完成步骤4
  ↓
完整回归测试
```

## Impact & Rollout

### 影响范围

**API 影响**:
- ✅ **向后兼容** - 通过 filterState.selectedLevels 访问,外部代码仍可工作
- ✅ **渐进式迁移** - 可逐步更新引用点

**受影响文件**:
- `Sources/LoggerKit/UI/LogDetailSceneState.swift` - 大幅简化
- `Sources/LoggerKit/UI/LogDetailScene.swift` - 更新属性引用
- `Sources/LoggerKit/UI/LogFilterSheet.swift` - 更新属性引用
- 新增 4-5 个文件(FilterState, DataLoader, 协议等)

**测试影响**:
- 现有测试: 无(当前没有单元测试)
- 新增测试: 本次不包含(后续补充)

### 部署策略

**阶段**: 单阶段部署
- 一次性完成所有4个步骤
- 通过验证后统一提交

**回滚策略**:
- 每步独立 git commit
- 如遇问题可回滚到上一步
- 重构前打 tag: `before-phase3-refactor`

**风险评估**:
- **风险等级**: 中
- **缓解措施**: 渐进式实施 + 每步验证
- **最坏情况**: 回滚到重构前(功能完整保留)

### 时间规划

| 步骤 | 预计时间 | 累计时间 |
|------|---------|---------|
| 步骤1: FilterState | 2-3h | 2-3h |
| 步骤2: DataLoader | 3-4h | 5-7h |
| 步骤3: 依赖注入 | 2-3h | 7-10h |
| 步骤4: SearchState(可选) | 2-3h | 9-13h |
| **总计(核心)** | **7-10h** | - |
| **总计(含可选)** | **9-13h** | - |

**建议周期**: 1-2 周完成

## Success Metrics

### 代码质量指标

- ✅ LogDetailSceneState 行数 < 300
- ✅ 职责数量 ≤ 2 个
- ✅ @Published 属性 ≤ 6 个
- ✅ didSet 重复代码 = 0

### 性能指标

- ✅ 无性能回退(所有场景)
- ✅ 搜索响应时间减少 50%+(步骤4完成后)
- ✅ 编译时间无明显增加

### 架构质量

- ✅ 依赖注入支持完整
- ✅ 职责清晰分离
- ✅ 可测试性改善(支持 Mock)
- ✅ 代码可维护性提升

### 验收标准

**必须满足**:
1. 所有功能正常工作(无回归)
2. LogDetailSceneState < 300 行
3. 编译无警告
4. Example 项目运行正常
5. 无性能回退

**理想目标**:
6. 搜索性能提升 50%+(步骤4)
7. 代码行数减少 67%
8. 职责数量减少 75%
