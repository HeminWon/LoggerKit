# LoggerKit 优化路线图

## 📅 文档信息

- **创建日期**: 2025-12-12
- **最后更新**: 2025-12-15
- **当前分支**: feature/optimization_251210
- **当前进度**: 1/5 任务已完成 ✅
- **剩余工作量**: ~3.5-4小时 (核心任务)

---

## 🎯 优化概览

### 当前状态

```
✅ 阶段1 (性能优化): 已完成
✅ 阶段3 (架构重构): 已完成
🚧 阶段2 (代码质量): 进行中 - 4个任务待完成

✅ 已完成: 1个任务 (P0 Timer泄漏修复)
🚧 剩余核心任务: 2个任务, ~3-4小时
🚧 可选任务: 2个任务, ~2小时
```

### 优先级说明

| 优先级 | 标识 | 说明 | 建议 |
|-------|------|------|------|
| P0 | 🔥 | 关键 - 稳定性/安全性问题 | 必须立即完成 |
| P1 | 🚀 | 高 - 显著性能提升 | 强烈推荐完成 |
| P2 | 🛠️ | 中 - 代码质量改进 | 推荐完成 |
| P3 | 💡 | 低 - 可选优化 | 根据时间决定 |

---

## 🚧 待完成任务

### ✅ 任务1: Timer 内存泄漏修复 (已完成)

**优先级**: P0 - 🔥 **关键** (稳定性问题)
**完成日期**: 2025-12-15
**实际工作量**: 30分钟
**风险**: 低

#### 问题诊断

- **文件**: `Sources/LoggerKit/Database/CoreDataDestination.swift:40-49`
- **问题**: Foundation.Timer 通过 RunLoop 强引用,存在潜在内存泄漏风险
- **实际情况**: 代码已有 `deinit` 使用 `invalidate()`,但仍存在隐患:
  1. `Timer.scheduledTimer` 会被 main RunLoop 强引用
  2. 不必要地依赖主线程
  3. RunLoop 生命周期管理复杂

#### 原有实现

```swift
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

deinit {
    flushTimer?.invalidate()  // 依赖 RunLoop 的生命周期
    flush()
}
```

#### 修复方案 (已实施)

```swift
private var flushTimer: DispatchSourceTimer?

private func setupFlushTimer() {
    // 使用 DispatchSourceTimer 替代 Foundation.Timer
    // 优势: 1) 不依赖 RunLoop, 避免引用循环 2) 更好的线程控制
    let timer = DispatchSource.makeTimerSource(queue: queue)

    timer.setEventHandler { [weak self] in
        self?.flushPendingEvents()
    }

    // 每 5 秒触发一次
    timer.schedule(deadline: .now() + 5.0, repeating: 5.0)
    timer.resume()

    self.flushTimer = timer
}

deinit {
    // 取消定时器并最后一次刷新,确保数据不丢失
    flushTimer?.cancel()
    flushTimer = nil
    flush()
}
```

#### 修复详情

**代码修改**:
1. 将 `Timer?` 替换为 `DispatchSourceTimer?`
2. 使用现有的 `queue` 队列,统一线程管理
3. 优化 deinit: 使用 `cancel()` 代替 `invalidate()`

**技术优势**:
- ✅ 完全避免 RunLoop 引用循环
- ✅ 不依赖主线程,统一使用 utility 队列
- ✅ 更清晰的资源管理 (cancel vs invalidate)
- ✅ 更好的线程一致性 (所有 flush 操作都在同一队列)

#### 验证结果

- ✅ 编译通过: `swift build` 成功
- ✅ iOS 示例编译通过: `xcodebuild` 成功
- ✅ 无新增警告或错误

---

### P1 🚀 任务2: 搜索结果单次遍历优化

**优先级**: P1 - 🚀 **高** (性能提升50-70%)
**工作量**: 2小时
**风险**: 低
**收益**: 搜索响应时间减少50-70%，用户体验显著提升

#### 问题描述

- **文件**: `Sources/LoggerKit/UI/LogDetailSceneState.swift:296-360`
- **问题**: 每个搜索字段独立遍历 events 数组
- **复杂度**: O(n*m) - 5个字段 = 5次完整遍历
- **影响**: 大数据集搜索延迟明显

#### 当前实现 (伪代码)

```swift
var searchResults: SearchResults {
    var results = SearchResults()

    // ❌ 遍历1: message
    for event in events {
        if event.message.contains(searchText) {
            results.message.insert(event.message)
        }
    }

    // ❌ 遍历2: function
    for event in events {
        if event.function.contains(searchText) {
            results.function.insert(event.function)
        }
    }

    // ... 还有 fileName, context, thread 各自遍历一次
}
```

#### 优化方案

```swift
var searchResults: SearchResults {
    var results = SearchResults()
    let lowercased = searchText.lowercased()

    // 用字典统计匹配次数
    var messageCounts: [String: Int] = [:]
    var functionCounts: [String: Int] = [:]
    var fileNameCounts: [String: Int] = [:]
    var contextCounts: [String: Int] = [:]
    var threadCounts: [String: Int] = [:]

    // ✅ 单次遍历，同时检查所有字段
    for event in events {
        if searchFields.contains(.message) &&
           event.message.lowercased().contains(lowercased) {
            messageCounts[event.message, default: 0] += 1
        }

        if searchFields.contains(.function) &&
           event.function.lowercased().contains(lowercased) {
            functionCounts[event.function, default: 0] += 1
        }

        if searchFields.contains(.fileName) &&
           event.fileName.lowercased().contains(lowercased) {
            fileNameCounts[event.fileName, default: 0] += 1
        }

        if searchFields.contains(.context) &&
           event.context.lowercased().contains(lowercased) {
            contextCounts[event.context, default: 0] += 1
        }

        if searchFields.contains(.thread) &&
           event.thread.lowercased().contains(lowercased) {
            threadCounts[event.thread, default: 0] += 1
        }
    }

    // 构建结果
    results.message = messageCounts.map {
        SearchResultItem(field: .message, value: $0.key, matchCount: $0.value)
    }
    results.function = functionCounts.map {
        SearchResultItem(field: .function, value: $0.key, matchCount: $0.value)
    }
    // ... 其他字段同理

    return results
}
```

#### 实施步骤

1. 重构搜索逻辑为单次遍历
2. 添加匹配计数功能 (额外收益)
3. 测试验证结果一致性
4. 性能基准测试对比

#### 预期收益

- ✅ 搜索时间减少 50-70% (5次遍历 → 1次)
- ✅ 减少临时对象分配
- ✅ 附加功能: 显示匹配次数

---

### P2 🛠️ 任务3: 错误处理统一化

**优先级**: P2 - 🛠️ **中** (可观测性提升)
**工作量**: 1-2小时
**风险**: 极低
**收益**: 生产环境错误可追踪，便于诊断问题

#### 问题描述

- **问题**: 多处使用 `print()` 进行错误处理
- **影响**: 生产环境无法追踪错误，调试困难
- **范围**: 6个文件，约11处 print()

#### 影响文件统计

| 文件 | 行号 | 数量 |
|------|------|------|
| LogDatabaseManager.swift | 344, 346, 375, 377, 402, 404 | 6处 |
| LogDetailSceneState.swift | 477, 504, 552, 572, 614 | 5处 |
| CoreDataStack.swift | 待检查 | ? |
| CoreDataDestination.swift | 待检查 | ? |
| LogDestination.swift | 待检查 | ? |
| LogDatabaseRotationManager.swift | 待检查 | ? |

#### 当前问题代码

```swift
do {
    try context.save()
} catch {
    print("Failed to save: \(error)")  // ❌ 使用 print
}
```

#### 修复方案

```swift
do {
    try context.save()
} catch {
    Logger(context: "CoreData").error("Failed to save logs: \(error)")  // ✅
    // 根据情况决定是否抛出异常
}
```

#### 实施步骤

1. **第一步**: 全局搜索 `print(` 找出所有位置
2. **第二步**: 分类处理
   - 错误情况 → `Logger.error()`
   - 警告情况 → `Logger.warning()`
   - 调试信息 → `Logger.debug()`
3. **第三步**: 考虑是否需要抛出异常
4. **第四步**: 测试验证日志正常输出

#### 预期收益

- ✅ 生产环境错误可追踪
- ✅ 统一日志格式和级别
- ✅ 支持日志过滤和分析
- ✅ 提升问题诊断效率

---

### P3 💡 任务4: fileName 计算优化 (可选)

**优先级**: P3 - 💡 **低** (微优化)
**工作量**: 1小时
**风险**: 低
**收益**: 减少重复字符串操作，微幅性能提升

#### 问题描述

- **文件**: `Sources/LoggerKit/Parser/LogParser.swift:80-86`
- **问题**: `fileName` 是计算属性，每次访问都重新计算
- **影响**: 如果频繁访问会产生不必要的字符串操作

#### 当前实现

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

#### 优化方案

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

        // ... 其他初始化
    }
}
```

#### 注意事项

⚠️ **需要更新所有创建 LogEvent 的地方**，确保所有初始化路径都正确

#### 预期收益

- ✅ 减少重复字符串操作
- ✅ 微幅内存效率提升
- ⚠️ 需要仔细测试所有初始化路径

---

### P3 💡 任务5: Magic Numbers 提取 (可选)

**优先级**: P3 - 💡 **低** (代码整洁)
**工作量**: 1小时
**风险**: 极低
**收益**: 提升可维护性，便于参数调整

#### 问题描述

- **问题**: 硬编码数值散落在多个文件中
- **影响**: 修改配置需要多处查找替换
- **现状**: Constants.swift 已存在，需要扩展

#### 硬编码位置统计

```swift
// LogDetailSceneState.swift
let pageSize = 500
let limit: Int = 10000

// CoreDataDestination.swift
batchSize: Int = 50
flushInterval: 5.0

// LogFilterSheet.swift
.fetchLimit = 100

// LoggerEngineConfiguration
maxDatabaseSize: Int64 = 100 * 1024 * 1024
maxRetentionDays: Int = 30
```

#### 优化方案

扩展现有的 `Sources/LoggerKit/Utilities/Constants.swift`:

```swift
public enum Constants {
    // 现有常量
    public static let logDirectoryName = "LoggerKit"

    // 新增: 数据库常量
    public enum Database {
        public static let maxDatabaseSize: Int64 = 100 * 1024 * 1024  // 100MB
        public static let maxRetentionDays: Int = 30
        public static let defaultPageSize: Int = 500
        public static let batchWriteSize: Int = 50
        public static let topFunctionsLimit: Int = 100
    }

    // 新增: UI常量
    public enum UI {
        public static let searchPreviewLimit: Int = 5
        public static let initialLogLoadLimit: Int = 10000
        public static let filterFetchLimit: Int = 100
    }

    // 新增: 性能常量
    public enum Performance {
        public static let flushInterval: TimeInterval = 5.0
    }

    // 保持现有的 UserDefaultsKeys
    public enum UserDefaultsKeys {
        public static let logIdentifier = "com.loggerkit.identifier"
    }
}
```

#### 使用示例

```swift
// 替换前
let pageSize = 500

// 替换后
let pageSize = Constants.Database.defaultPageSize
```

#### 预期收益

- ✅ 提升代码可维护性
- ✅ 便于全局调整参数
- ✅ 代码意图更清晰
- ✅ 减少魔法数字

---

## 📋 任务优先级总结

### 推荐执行顺序

```
第一周 (核心任务 - 必做):
├─ Day 1     → ✅ P0: Timer泄漏修复 (已完成 - 30min) 🔥
├─ Day 2-3   → P1: 搜索单次遍历 (2h) 🚀
└─ Day 4-5   → P2: 错误处理统一 (1-2h) 🛠️

第二周 (可选任务):
├─ Day 1     → P3: fileName优化 (1h) 💡
└─ Day 2     → P3: Magic Numbers (1h) 💡
```

### 最小必做集

**核心3项 (P0-P2)**: ~3.5-4小时 (剩余)
- ✅ 修复稳定性问题 (P0已完成)
- 🚧 提升性能50-70% (P1待完成)
- 🚧 改善可观测性 (P2待完成)

完成后项目质量显著提升，可考虑发布新版本。

### 完整任务集

**全部5项 (P0-P3)**: ~5.5-6小时 (剩余)
- ✅ P0 完成 (稳定性修复)
- 🚧 P1-P3 待完成 (4个任务)
- 完成后代码达到生产级别标准

---

## 🎯 成功标准

### 任务完成标准

| 任务 | 状态 | 验证方法 |
|------|------|---------|
| Timer修复 | ✅ | 编译通过,使用DispatchSourceTimer |
| 搜索优化 | 🚧 | 性能测试显示50%+提升 |
| 错误处理 | 🚧 | 全局搜索无残留print() |
| fileName优化 | 🚧 | 所有测试通过 |
| Magic Numbers | 🚧 | 代码审查通过 |

### 质量指标目标

| 指标 | 修复前 | 当前 | 目标 |
|------|------|------|------|
| Timer 泄漏风险 | ⚠️ 存在 | ✅ 消除 | ✅ 消除 |
| 搜索响应时间 | ~300ms | ~300ms | <150ms |
| print() 错误处理 | 11+ 处 | 11+ 处 | 0 处 |
| 魔法数字 | 分散 | 分散 | 集中管理 |

---

## 📚 相关文档

- 📊 [阶段1完成记录](./Examples/iOS/LoggerKitExample/openspec/changes/archive/2025-12-12-optimize-phase1-performance/PROGRESS.md)
- 🏗️ [架构重构记录](查看 LogDataLoader, FilterState, SearchState 等文件)
- 🧪 [测试框架](./Tests/LoggerKitTests/)

---

## 🔄 更新历史

| 日期 | 版本 | 变更 |
|------|------|------|
| 2025-12-12 | 1.0 | 初始创建 |
| 2025-12-15 | 2.0 | 阶段3完成后更新 |
| 2025-12-15 | 3.0 | 精简版: 删除已完成项，重新标记优先级 |
| 2025-12-15 | 3.1 | ✅ **P0完成**: Timer泄漏修复 (DispatchSourceTimer) |

---

**下一步**: 推荐开始 **P1: 搜索单次遍历优化** (2小时) - 性能提升50-70%
