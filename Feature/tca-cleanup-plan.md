# TCA 架构清理计划 - 短期优化

> 基于 LoggerKit UI 目录 TCA 改造分析报告
>
> 创建时间: 2025-12-19
>
> 目标: 清理遗留代码，消除状态重复，统一架构设计

---

## 一、优化目标

### 核心目标
1. ✅ 清理 `LogDetailState` 中的重复字段
2. ✅ 移除遗留的 `FilterReducer`
3. ✅ 统一 Action 命名和使用方式

### 预期效果
- 减少状态同步的复杂度
- 降低代码维护成本
- 提升架构一致性
- 消除潜在的数据不一致问题

---

## 二、任务清单

### 任务 1: 清理 LogDetailState 重复字段 🔴

**位置**: `/Sources/LoggerKit/UI/LogDetail/LogDetailState.swift`

**问题分析**:
```swift
// ❌ 当前状态：字段重复
public struct LogDetailState: Equatable {
    // 新的 LogList Feature 字段
    public var list: LogList.State = LogList.State()

    // ⚠️ 重复字段（与 list.events 重复）
    public var events: [LogEvent] = []
    public var totalCount: Int = 0
    public var loadingState: LoadingState = .idle
    public var currentPage: Int = 0
    public var pageSize: Int = 500
    public var hasMoreData: Bool = true

    // ⚠️ 重复字段（与 filterFeature 重复）
    public var selectedLevels: Set<LogEvent.Level> = [...]
    public var selectedFunctions: Set<String> = []
    public var selectedFileNames: Set<String> = []
    // ... 更多筛选字段
}
```

**解决方案**:
采用**渐进式迁移**策略，分三个阶段进行：

#### 阶段 1: 直接替换为计算属性（安全且简洁）✅

**原理说明**:
- ❌ **不保留私有字段**: 避免 `_events` 和 `list.events` 状态不同步
- ✅ **直接使用计算属性**: 保证单一数据源,维护 `Equatable` 正确性
- ✅ **提供 getter/setter**: 保持向后兼容,外部调用无需修改

```swift
public struct LogDetailState: Equatable {
    // ✅ 子 Feature 字段（唯一数据源）
    public var list: LogList.State = LogList.State()
    public var filterFeature: FilterFeature.State = FilterFeature.State()

    // ✅ 计算属性（代理到子 Feature）
    // 列表相关
    public var events: [LogEvent] {
        get { list.events }
        set { list.events = newValue }
    }

    public var totalCount: Int {
        get { list.totalCount }
        set { list.totalCount = newValue }
    }

    public var loadingState: LoadingState {
        get { list.loadingState }
        set { list.loadingState = newValue }
    }

    public var currentPage: Int {
        get { list.currentPage }
        set { list.currentPage = newValue }
    }

    public var pageSize: Int {
        get { list.pageSize }
        set { list.pageSize = newValue }
    }

    public var hasMoreData: Bool {
        get { list.hasMoreData }
        set { list.hasMoreData = newValue }
    }

    // 筛选相关
    public var selectedLevels: Set<LogEvent.Level> {
        get { filterFeature.selectedLevels }
        set { filterFeature.selectedLevels = newValue }
    }

    public var selectedFunctions: Set<String> {
        get { filterFeature.selectedFunctions }
        set { filterFeature.selectedFunctions = newValue }
    }

    public var selectedFileNames: Set<String> {
        get { filterFeature.selectedFileNames }
        set { filterFeature.selectedFileNames = newValue }
    }

    public var searchText: String {
        get { filterFeature.searchText }
        set { filterFeature.searchText = newValue }
    }

    // ... 其他筛选字段
}
```

**执行步骤**:
1. [ ] 备份当前的 `LogDetailState.swift` 文件
2. [ ] 删除所有重复的存储属性（`events`, `totalCount` 等）
3. [ ] 添加计算属性（getter/setter），代理到子 Feature
4. [ ] 编译项目，确保无编译错误
5. [ ] 手动测试: 打开 iOS Demo,验证列表加载和筛选功能
6. [ ] 提交代码（Commit message: `♻️ refactor: 使用计算属性消除 LogDetailState 重复字段`）

**验证清单**:
- [ ] 编译无警告
- [ ] `LogDetailState` 的 `Equatable` 行为正确
- [ ] 状态变化能正确触发 UI 更新

#### 阶段 2: 验证计算属性正确性 ✅

**目标**: 确保计算属性在所有场景下正常工作,没有遗漏的边界情况。

**执行步骤**:
1. [ ] 检查 Reducer 中所有使用 `state.events` 等字段的地方
2. [ ] 确认没有编译警告
3. [ ] 手动测试所有功能点
4. [ ] 提交代码（Commit message: `✅ verify: 验证 LogDetailState 计算属性正确性`）

**验证清单**:
- [ ] 读写操作正确
- [ ] Equatable 行为正确
- [ ] UI 更新正常

#### 阶段 3: 优化为只读计算属性（可选）✅

**背景**:
阶段1完成后,代码已经完全可用。阶段3是**可选优化**,目的是强制通过子 Feature 的 Action 修改状态,而不是直接赋值。

**决策标准**:
- ✅ **如果需要更严格的架构约束**: 继续执行阶段3
- ⚠️ **如果当前实现已满足需求**: 可以跳过阶段3,保留 setter 提供灵活性

**实现方案**（如果决定执行）:

```swift
public struct LogDetailState: Equatable {
    // ✅ 只保留子 Feature 字段
    public var list: LogList.State = LogList.State()
    public var filterFeature: FilterFeature.State = FilterFeature.State()

    // ✅ 计算属性（只读）
    public var events: [LogEvent] { list.events }
    public var totalCount: Int { list.totalCount }
    public var loadingState: LoadingState { list.loadingState }
    public var currentPage: Int { list.currentPage }
    public var pageSize: Int { list.pageSize }
    public var hasMoreData: Bool { list.hasMoreData }

    public var selectedLevels: Set<LogEvent.Level> {
        filterFeature.selectedLevels
    }
    public var selectedFunctions: Set<String> {
        filterFeature.selectedFunctions
    }
    public var selectedFileNames: Set<String> {
        filterFeature.selectedFileNames
    }
    public var searchText: String {
        filterFeature.searchText
    }
}
```

**需要同步修改的地方**:

```swift
// LogDetailReducer.swift

// ❌ 旧写法（直接赋值,阶段3后不可用）
case .logsLoaded(let events, let totalCount, _):
    state.events = events
    state.totalCount = totalCount
    state.loadingState = .loaded

// ✅ 新写法（通过子 Feature 修改）
case .logsLoaded(let events, let totalCount, _):
    state.list.events = events
    state.list.totalCount = totalCount
    state.list.loadingState = .loaded

// 或者通过 Action
case .logsLoaded(let events, let totalCount, let seq):
    return .send(.list(.loadSucceeded(events: events, totalCount: totalCount, sequenceNumber: seq)))
```

**执行步骤**（仅在决定执行阶段3时）:
1. [ ] 将所有计算属性改为只读（移除 setter）
2. [ ] 查找所有直接赋值的地方: `grep -r "state\\.events\\s*=" Sources/`
3. [ ] 更新为直接操作子 Feature: `state.list.events = ...`
4. [ ] 编译项目,修复所有编译错误
5. [ ] 手动测试 iOS Demo
6. [ ] 提交代码（Commit message: `♻️ refactor: 将 LogDetailState 计算属性改为只读`）

**推荐**:
建议**暂时跳过阶段3**,保留 setter。理由:
- 当前实现已经消除了重复字段
- setter 提供了更好的向后兼容性
- 如果未来需要更严格的约束,可以随时执行阶段3

---

### 任务 2: 移除遗留的 FilterReducer 🟡

**位置**: `/Sources/LoggerKit/UI/SubFeatures/FilterReducer.swift`

**问题分析**:
```swift
// LogDetailReducer.swift

public struct LogDetailReducer: Reducer {
    // ⚠️ 遗留的 FilterReducer（功能已被 FilterFeature 替代）
    private let filterReducer: FilterReducer

    // ✅ 新的 FilterFeature.Reducer
    private let filterFeatureReducer: FilterFeature.Reducer

    public func reduce(_ state: inout LogDetailState, _ action: LogDetailAction) -> Effect<LogDetailAction> {
        // ⚠️ 仍在调用旧的 filterReducer
        let subEffects = [
            filterReducer.reduce(&state, action),  // ❌ 待移除
            cacheReducer.reduce(&state, action)
        ]
        // ...
    }
}
```

**解决方案**:

#### 步骤 1: 确认 FilterFeature 功能完整性 ✅

**检查清单**:
- [ ] `FilterFeature` 是否处理所有筛选 Action？
  - `toggleLevel`, `addFunction`, `removeFunction` 等
- [ ] `FilterReducer` 中是否有 `FilterFeature` 未实现的逻辑？
- [ ] `FilterReducer` 处理的 Action 是否已废弃？

**执行方式**:
```bash
# 1. 查找 FilterReducer 处理的所有 Action
grep -n "case\." Sources/LoggerKit/UI/SubFeatures/FilterReducer.swift

# 2. 确认 FilterFeature 是否处理这些 Action
grep -n "case\." Sources/LoggerKit/UI/Filter/FilterFeature.swift
```

#### 步骤 2: 迁移遗留逻辑（如有）✅

如果 `FilterReducer` 中存在 `FilterFeature` 未实现的逻辑：

```swift
// FilterFeature.swift - 添加缺失的 Action 处理

extension FilterFeature.Reducer {
    // 示例：如果 FilterReducer 中有特殊的 resetFilter 逻辑
    case .resetFilters:
        state.reset()
        state.invalidateCache()  // 如果有额外逻辑
        return .send(.filtersApplied)
}
```

**执行步骤**:
1. [ ] 对比 `FilterReducer` 和 `FilterFeature.Reducer` 的实现
2. [ ] 迁移缺失的逻辑到 `FilterFeature`
3. [ ] 手动验证功能
4. [ ] 提交代码（Commit message: `✨ feat: 迁移 FilterReducer 遗留逻辑到 FilterFeature`）

#### 步骤 3: 移除 FilterReducer 引用 ✅

```swift
// LogDetailReducer.swift

public struct LogDetailReducer: Reducer {
    // ❌ 移除这行
    // private let filterReducer: FilterReducer

    private let cacheReducer: CacheReducer
    private let filterFeatureReducer: FilterFeature.Reducer

    public init(environment: LogDetailEnvironment) {
        self.environment = environment

        // ❌ 移除这行
        // self.filterReducer = FilterReducer(environment: environment)

        let filterFeatureEnvironment = FilterFeature.Environment.live(
            dataLoader: environment.dataLoader
        )
        self.filterFeatureReducer = FilterFeature.Reducer(environment: filterFeatureEnvironment)

        self.cacheReducer = CacheReducer()
    }

    public func reduce(_ state: inout LogDetailState, _ action: LogDetailAction) -> Effect<LogDetailAction> {
        // ❌ 移除 filterReducer 调用
        let subEffects = [
            // filterReducer.reduce(&state, action),  // ❌ 删除
            cacheReducer.reduce(&state, action)
        ]

        // ...
    }
}
```

**执行步骤**:
1. [ ] 在 `LogDetailReducer` 中移除 `filterReducer` 属性
2. [ ] 移除 `filterReducer` 初始化代码
3. [ ] 移除 `filterReducer.reduce(&state, action)` 调用
4. [ ] 手动验证功能
5. [ ] 提交代码（Commit message: `🔥 remove: 移除 LogDetailReducer 中的 FilterReducer 引用`）

#### 步骤 4: 删除 FilterReducer 文件 ✅

```bash
# 删除文件
rm Sources/LoggerKit/UI/SubFeatures/FilterReducer.swift
```

**执行步骤**:
1. [ ] 删除 `FilterReducer.swift` 文件
2. [ ] 检查是否有其他文件引用 `FilterReducer`
3. [ ] 手动验证功能
4. [ ] 提交代码（Commit message: `🔥 remove: 删除遗留的 FilterReducer.swift`）

---

### 任务 3: 统一 Action 命名和使用 🟢

**位置**: `/Sources/LoggerKit/UI/LogDetail/LogDetailAction.swift`

**问题分析**:
```swift
// ❌ 旧的 Action（已废弃，但仍在处理）
case logsLoaded(events: [LogEvent], totalCount: Int, sequenceNumber: UInt64)

// ✅ 新的 Action（通过 LogList Feature）
case list(LogList.Action)
// 其中 LogList.Action 包含:
// - .loadSucceeded(events: [LogEvent], totalCount: Int, sequenceNumber: UInt64)
```

**解决方案**:

#### 步骤 1: 标记废弃的 Action ✅

```swift
// LogDetailAction.swift

public enum LogDetailAction: Equatable {
    // MARK: - Deprecated Actions (待移除)

    /// ⚠️ DEPRECATED: Use `.list(.loadSucceeded)` instead
    @available(*, deprecated, message: "Use .list(.loadSucceeded) instead")
    case logsLoaded(events: [LogEvent], totalCount: Int, sequenceNumber: UInt64)

    /// ⚠️ DEPRECATED: Use `.list(.loadLogFile)` instead
    @available(*, deprecated, message: "Use .list(.loadLogFile) instead")
    case loadLogFile

    /// ⚠️ DEPRECATED: Use `.list(.loadMore)` instead
    @available(*, deprecated, message: "Use .list(.loadMore) instead")
    case loadMore

    /// ⚠️ DEPRECATED: Use `.list(.refresh)` instead
    @available(*, deprecated, message: "Use .list(.refresh) instead")
    case refresh

    // MARK: - Filter Actions (待移除)

    /// ⚠️ DEPRECATED: Use `.filter(.toggleLevel)` instead
    @available(*, deprecated, message: "Use .filter(.toggleLevel) instead")
    case toggleLevel(LogEvent.Level)

    /// ⚠️ DEPRECATED: Use `.filter(.addFunction)` instead
    @available(*, deprecated, message: "Use .filter(.addFunction) instead")
    case addFunctionFilter(String)

    // ... 其他废弃的 Action

    // MARK: - Current Actions

    case list(LogList.Action)
    case filter(FilterFeature.Action)
    case search(SearchFeature.Action)
    case export(ExportFeature.Action)
    case delete(DeleteFeature.Action)

    // ... 其他有效 Action
}
```

**执行步骤**:
1. [ ] 添加 `@available(*, deprecated)` 标记
2. [ ] 添加 deprecation message 指引
3. [ ] 编译项目，查看警告
4. [ ] 提交代码（Commit message: `⚠️ deprecate: 标记废弃的 Action`）

#### 步骤 2: 更新调用点 ✅

查找并更新所有使用废弃 Action 的地方：

```swift
// ❌ 旧写法
await store.send(.loadLogFile)
await store.send(.toggleLevel(.debug))

// ✅ 新写法
await store.send(.list(.loadLogFile))
await store.send(.filter(.toggleLevel(.debug)))
```

**执行步骤**:
1. [ ] 使用 Xcode "Find in Project" 搜索废弃的 Action
2. [ ] 逐个更新调用点
3. [ ] 手动验证功能
4. [ ] 提交代码（Commit message: `♻️ refactor: 更新 Action 调用为新的命名空间`）

#### 步骤 3: 移除 Reducer 中的废弃 Action 处理 ✅

```swift
// LogDetailReducer.swift

private func reduceCoreActions(_ state: inout LogDetailState, _ action: LogDetailAction) -> Effect<LogDetailAction> {
    switch action {
    // ❌ 删除这些 case
    // case .loadLogFile:
    //     return handleLoadLogFile(&state)
    //
    // case .logsLoaded(let events, let totalCount, let seq):
    //     return handleLogsLoaded(&state, events: events, totalCount: totalCount, sequenceNumber: seq)

    // ✅ 保留这些 case
    case .list(let listAction):
        let effect = listReducer.reduce(&state.list, listAction)
        return effect.map { .list($0) }

    case .filter(let filterAction):
        let effect = filterFeatureReducer.reduce(&state.filterFeature, filterAction)
        return effect.map { .filter($0) }

    // ...
    }
}
```

**执行步骤**:
1. [ ] 删除所有废弃 Action 的 case 处理
2. [ ] 删除对应的 handler 方法
3. [ ] 手动验证功能
4. [ ] 提交代码（Commit message: `🔥 remove: 移除 Reducer 中的废弃 Action 处理`）

#### 步骤 4: 删除废弃的 Action 定义 ✅

```swift
// LogDetailAction.swift

public enum LogDetailAction: Equatable {
    // ❌ 删除所有标记为 deprecated 的 case

    // ✅ 只保留有效的 Action
    case list(LogList.Action)
    case filter(FilterFeature.Action)
    case search(SearchFeature.Action)
    case export(ExportFeature.Action)
    case delete(DeleteFeature.Action)

    case statisticsLoaded(LogStatistics)
    case allEventsLoaded([LogEvent])
    case loadingFailed(Error)

    // ... 其他有效 Action
}
```

**执行步骤**:
1. [ ] 删除所有 `@available(*, deprecated)` 的 case
2. [ ] 编译项目，确保无错误
3. [ ] 手动验证功能
4. [ ] 提交代码（Commit message: `🔥 remove: 删除废弃的 Action 定义`）

---

## 三、执行顺序

建议按以下顺序执行，确保每个阶段都可以独立测试和回滚：

### Week 1: LogDetailState 清理（3-4天）
```
Day 1-2: 任务 1 阶段 1 - 替换为计算属性
  - 删除重复字段,添加计算属性
  - 编译测试,修复错误
  - 手动测试功能

Day 3:   任务 1 阶段 2 - 验证计算属性
  - 验证 Equatable 行为
  - 手动测试 iOS Demo

Day 4:   任务 1 阶段 3 - 优化为只读（可选）
  - 如果需要更严格约束,执行此阶段
  - 否则跳过,进入任务 2
```

**里程碑**: LogDetailState 无重复字段,状态单一数据源

### Week 2: FilterReducer 移除（5-7天）
```
Day 1-2: 任务 2 步骤 1 - 确认功能完整性
  - 使用 grep 查找所有 FilterReducer 引用
  - 对比 FilterReducer 和 FilterFeature 的实现
  - 确认是否有遗留逻辑

Day 3-4: 任务 2 步骤 2 - 迁移遗留逻辑（如有）
  - 迁移缺失的功能到 FilterFeature
  - 验证功能完整性

Day 5:   任务 2 步骤 3 - 移除 FilterReducer 引用
  - 在 LogDetailReducer 中移除引用
  - 手动验证功能

Day 6:   任务 2 步骤 4 - 删除文件
  - 删除 FilterReducer.swift
  - 最终验证

Day 7:   缓冲时间（应对意外情况）
```

**里程碑**: FilterReducer 完全移除,只使用 FilterFeature

### Week 3: Action 统一（5-7天）
```
Day 1:   任务 3 步骤 1 - 标记废弃 Action
  - 添加 @available(*, deprecated)
  - 编译查看警告

Day 2-4: 任务 3 步骤 2 - 更新调用点
  - 搜索所有废弃 Action 的使用
  - 逐个更新为新的命名空间
  - 手动验证功能

Day 5:   任务 3 步骤 3 - 移除 Reducer 处理
  - 删除废弃 Action 的 case
  - 手动验证功能

Day 6:   任务 3 步骤 4 - 删除废弃定义
  - 删除 Action 定义
  - 最终验证

Day 7:   缓冲时间和文档更新
```

**里程碑**: Action 命名统一,架构清晰

### 总时间: 3-4 周

**关键节点**:
- Week 1 结束: LogDetailState 重构完成 ✅
- Week 2 结束: FilterReducer 完全移除 ✅
- Week 3 结束: Action 统一,架构优化完成 ✅

---

## 四、验证策略

### 手动测试清单
- [ ] 日志列表加载正常
- [ ] 分页功能正常
- [ ] 筛选功能正常（Level、Function、FileName 等）
- [ ] 搜索功能正常
- [ ] 导出功能正常
- [ ] 删除功能正常
- [ ] 所有 Sheet 正常打开和关闭
- [ ] 无崩溃、无内存泄漏

---

## 五、回滚计划

每个任务都应该有独立的 commit，便于回滚：

```bash
# 查看最近的 commits
git log --oneline -10

# 回滚到某个 commit
git revert <commit-hash>

# 或者 reset（慎用）
git reset --hard <commit-hash>
```

### 回滚决策标准
如果出现以下情况，应立即回滚：
- ❌ 关键功能（加载、筛选、导出）无法使用
- ❌ 出现崩溃或内存泄漏
- ❌ 性能明显下降（加载时间增加 20% 以上）

---

## 六、成功标准

### 代码质量
- ✅ 无编译警告
- ✅ 无 SwiftLint 警告

### 架构清晰度
- ✅ `LogDetailState` 无重复字段
- ✅ `FilterReducer` 完全移除
- ✅ 所有 Action 使用新的命名空间

### 功能完整性
- ✅ 所有功能正常工作
- ✅ 无性能退化
- ✅ 无新增 Bug

---

## 七、风险评估

### 高风险区域 🔴
1. **FilterReducer 移除**
   - **风险**: 可能存在未迁移的逻辑导致功能缺失
   - **影响**: 筛选功能可能失效
   - **缓解措施**:
     - 使用 `grep -r "FilterReducer"` 全面搜索引用
     - 逐行对比 FilterReducer 和 FilterFeature 的代码
     - 手动测试所有筛选场景
   - **回滚预案**: 如果发现关键逻辑缺失,立即 `git revert`

### 中风险区域 🟡
1. **LogDetailState 计算属性**
   - **风险**: ~~可能遗漏某些直接赋值的地方~~ (已通过直接使用计算属性消除)
   - **影响**: 编译时即可发现错误,风险可控
   - **缓解措施**:
     - 修改后立即编译,修复所有编译错误
     - 提供 getter/setter,保持向后兼容
     - 手动验证 Equatable 行为
   - **降级为中风险**: 因为采用了更安全的实现方案

2. **Action 命名统一**
   - **风险**: 可能遗漏某些调用点
   - **影响**: 编译时会有 deprecation warning
   - **缓解措施**:
     - 使用 `@available(*, deprecated)` 标记
     - 编译时检查所有警告
     - 使用全局搜索确认所有调用点
   - **回滚预案**: 如果遗漏过多,可以暂时保留废弃 Action

### 低风险区域 🟢
1. **性能影响**
   - **风险**: 计算属性可能带来轻微性能开销
   - **评估**: 影响极小（仅为一次间接访问）
   - **验证**: 手动验证性能

### 风险矩阵

| 风险项 | 概率 | 影响 | 优先级 | 缓解措施完成度 |
|--------|------|------|--------|----------------|
| FilterReducer 逻辑缺失 | 中 | 高 | 🔴 高 | 待执行 |
| LogDetailState 编译错误 | 低 | 中 | 🟡 中 | 已规划 |
| Action 调用点遗漏 | 低 | 低 | 🟢 低 | 已规划 |
| 性能退化 | 极低 | 低 | 🟢 低 | 手动验证 |

---

## 八、参考资料

### 相关文件
- `/Sources/LoggerKit/UI/LogDetail/LogDetailState.swift` - 主状态定义
- `/Sources/LoggerKit/UI/LogDetail/LogDetailReducer.swift` - 主 Reducer
- `/Sources/LoggerKit/UI/SubFeatures/FilterReducer.swift` - 待移除的 Reducer
- `/Sources/LoggerKit/UI/Filter/FilterFeature.swift` - 新的 Filter Feature

### 架构文档
- `refator-tca.md` - TCA 重构总体计划
- `filter-feature-refactor.md` - Filter Feature 重构文档
- `export-feature-refactor.md` - Export Feature 重构文档

### TCA 最佳实践
- [PointFree TCA Documentation](https://pointfreeco.github.io/swift-composable-architecture/)
- SwiftUI State Management
- Reducer Composition Patterns

---

## 九、Commit Message 规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/) 和 [Gitmoji](https://gitmoji.dev/) 规范：

```
<gitmoji> <type>: <subject>

[optional body]

[optional footer]
```

### 示例
```
♻️ refactor: 使用计算属性消除 LogDetailState 重复字段

- 删除重复的存储属性（events, totalCount, loadingState 等）
- 添加计算属性代理到子 Feature（list, filterFeature）
- 保证单一数据源,维护 Equatable 正确性

Refs: #123
```

### Type 说明
- `feat`: 新功能
- `refactor`: 重构
- `remove`: 删除代码
- `test`: 测试相关
- `docs`: 文档更新
- `chore`: 构建/工具配置

---

## 十、进度跟踪

### 任务 1: LogDetailState 清理（预计 3-4天）
- [ ] 阶段 1: 替换为计算属性
  - [ ] 备份 LogDetailState.swift
  - [ ] 删除重复的存储属性
  - [ ] 添加计算属性（getter/setter）
  - [ ] 编译并修复错误
  - [ ] 手动测试功能
  - [ ] 提交代码

- [ ] 阶段 2: 验证计算属性
  - [ ] 验证 Equatable 行为
  - [ ] 手动测试 iOS Demo
  - [ ] 提交代码

- [ ] 阶段 3: 优化为只读（可选）
  - [ ] 评估是否需要更严格约束
  - [ ] 如需执行: 移除 setter,更新调用点
  - [ ] 如跳过: 直接进入任务 2

**里程碑**: ✅ LogDetailState 无重复字段

---

### 任务 2: FilterReducer 移除（预计 5-7天）
- [ ] 步骤 1: 确认功能完整性
  - [ ] grep 搜索所有 FilterReducer 引用
  - [ ] 对比 FilterReducer 和 FilterFeature 实现
  - [ ] 列出差异清单

- [ ] 步骤 2: 迁移遗留逻辑（如有）
  - [ ] 迁移缺失功能到 FilterFeature
  - [ ] 验证功能完整性
  - [ ] 提交代码

- [ ] 步骤 3: 移除引用
  - [ ] 在 LogDetailReducer 中移除 FilterReducer
  - [ ] 编译并修复错误
  - [ ] 手动验证功能
  - [ ] 提交代码

- [ ] 步骤 4: 删除文件
  - [ ] 删除 FilterReducer.swift
  - [ ] 检查是否有其他引用
  - [ ] 最终验证
  - [ ] 提交代码

**里程碑**: ✅ FilterReducer 完全移除

---

### 任务 3: Action 统一（预计 5-7天）
- [ ] 步骤 1: 标记废弃 Action
  - [ ] 添加 @available(*, deprecated)
  - [ ] 编译查看警告
  - [ ] 提交代码

- [ ] 步骤 2: 更新调用点
  - [ ] 搜索所有废弃 Action 使用
  - [ ] 更新为新的命名空间
  - [ ] 逐个验证
  - [ ] 手动验证功能
  - [ ] 提交代码
- [ ] 步骤 3: 移除 Reducer 处理
  - [ ] 删除废弃 Action 的 case
  - [ ] 删除对应的 handler 方法
  - [ ] 手动验证功能
  - [ ] 提交代码

- [ ] 步骤 4: 删除废弃定义
  - [ ] 删除所有 @available(*, deprecated) 的 case
  - [ ] 编译确保无错误
  - [ ] 最终验证
  - [ ] 提交代码

**里程碑**: ✅ Action 命名统一,架构清晰

---

### 总体进度

```
┌─────────────────────────────────────────────────────────┐
│  Week 1         Week 2         Week 3         Week 4    │
│  ████░░░░       ░░░░░░░       ░░░░░░░       ░░░░░       │
│  Task 1        Task 2         Task 3        Buffer      │
│  State清理    Reducer移除     Action统一    文档&测试   │
└─────────────────────────────────────────────────────────┘
```

**当前状态**: 📝 Ready for Implementation
**下一步**: 执行任务 1 阶段 1

---

## 十一、变更记录

### v1.1 (2025-12-19)
- ✅ 修正任务1阶段1实现方案
  - 改为直接使用计算属性,不保留私有字段
  - 避免状态不同步和 Equatable 问题
- ✅ 更新阶段2为验证阶段,添加详细测试用例
- ✅ 调整阶段3为可选优化
- ✅ 更新时间规划,增加缓冲时间(3周→3-4周)
- ✅ 完善风险评估,添加风险矩阵
- ✅ 细化进度跟踪 checklist

### v1.0 (2025-12-19)
- 初始版本
- 定义三个主要任务和执行步骤

---

## 十二、联系方式

如有问题，请联系：
- 技术负责人：[Your Name]
- 项目仓库：https://github.com/your-org/LoggerKit
- Issue Tracker：https://github.com/your-org/LoggerKit/issues

---

**最后更新**: 2025-12-19
**文档版本**: v1.1
**状态**: 📝 Ready for Implementation (已修正关键风险)
