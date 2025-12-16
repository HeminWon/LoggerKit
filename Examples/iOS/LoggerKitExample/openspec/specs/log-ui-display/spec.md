# log-ui-display Specification

## Purpose
TBD - created by archiving change optimize-phase1-performance. Update Purpose after archive.
## Requirements
### Requirement: 分页加载日志

系统 SHALL 支持分页加载日志,避免一次性加载所有日志到内存。

初始加载 MUST 仅加载第一页日志(默认 500 条)。

用户滚动到列表底部时,系统 MUST 自动加载下一页日志。

分页加载 MUST 在后台线程执行,不阻塞主线程。

加载状态 MUST 反馈给用户(显示加载指示器)。

#### Scenario: 初始加载第一页

- **WHEN** 用户打开日志详情界面
- **THEN** 系统加载前 500 条日志
- **AND** 在列表中展示这些日志
- **AND** 显示加载指示器(如需要)

#### Scenario: 滚动到底部加载更多

- **WHEN** 用户滚动到列表底部
- **AND** 还有更多日志未加载
- **THEN** 系统自动加载下一页(接下来的 500 条)
- **AND** 将新日志追加到列表末尾
- **AND** 列表平滑滚动,无卡顿

#### Scenario: 已加载全部日志

- **WHEN** 用户滚动到底部
- **AND** 已经加载了所有日志
- **THEN** 不再触发加载
- **AND** 不显示加载指示器
- **AND** 可选地显示"已加载全部"提示

#### Scenario: 分页加载性能优化

- **WHEN** 分页加载日志
- **THEN** 初始加载时间减少 50-70%
- **AND** 内存占用降低(仅保存已加载的日志)
- **AND** 滚动帧率保持在 60fps

---

### Requirement: 虚拟化列表渲染

系统 SHALL 使用虚拟化列表组件渲染日志，仅渲染可见区域的日志。

列表组件 MUST 使用 SwiftUI 的 `List` 或等效的虚拟化组件。

列表 MUST 仅创建可见区域内的视图，不为屏幕外的日志创建视图。

滚动性能 MUST 达到 60fps，即使在大数据量场景下（10000+ 条日志）。

列表迭代 MUST 直接使用 LogRowViewModel 数组，不使用 zip 或 enumerated 等辅助操作。

#### Scenario: 仅渲染可见日志

- **WHEN** 列表展示 1000 条日志
- **THEN** 仅为屏幕可见区域的日志（约 10-20 条）创建视图
- **AND** 屏幕外的日志不创建视图
- **AND** 内存占用保持在合理范围

#### Scenario: 滚动时动态渲染

- **WHEN** 用户滚动列表
- **THEN** 新进入可见区域的日志动态创建视图
- **AND** 离开可见区域的日志视图被销毁或复用
- **AND** 滚动流畅，帧率保持 60fps

#### Scenario: 大数据量性能保障

- **WHEN** 列表展示 10000+ 条日志
- **THEN** 初始加载时间 < 1 秒
- **AND** 滚动帧率保持 60fps
- **AND** 内存占用 < 100MB

#### Scenario: 简化 ForEach 迭代逻辑

- **WHEN** 渲染日志列表
- **THEN** 使用 `ForEach(displayEvents) { viewModel in ... }` 直接迭代
- **AND** 不使用 `zip(indices, events)` 等复杂操作
- **AND** 代码可读性提升

---

### Requirement: 过滤选项缓存管理

系统 SHALL 统一管理过滤选项的缓存(函数列表、文件名列表、上下文列表、线程列表及其计数)。

缓存管理器 MUST 提供类型安全的缓存访问接口。

缓存管理器 MUST 支持线程安全的读写操作。

缓存管理器 MUST 提供统一的缓存失效方法。

缓存键 MUST 使用枚举定义,避免魔法字符串。

#### Scenario: 缓存函数列表

- **WHEN** 首次获取可用函数列表
- **THEN** 从所有日志中提取唯一函数名
- **AND** 将结果缓存到 `functions` 键
- **AND** 返回排序后的函数列表

#### Scenario: 缓存命中直接返回

- **WHEN** 再次获取可用函数列表
- **AND** 缓存中已有该数据
- **THEN** 直接从缓存返回
- **AND** 不重新遍历日志数组

#### Scenario: 统一失效所有缓存

- **WHEN** 原始日志数据变化
- **THEN** 调用缓存管理器的 `invalidate()` 方法
- **AND** 所有缓存项(functions, fileNames, contexts, threads, counts)被清空
- **AND** 下次访问时重新计算

#### Scenario: 线程安全访问

- **WHEN** 主线程和后台线程同时访问缓存
- **THEN** 不会发生数据竞争
- **AND** 不会发生崩溃
- **AND** 数据一致性得到保证

---

### Requirement: 并发安全的数据库访问

系统 SHALL 确保数据库访问的并发安全性,避免数据竞争。

CoreData 的 `viewContext` MUST 仅在主线程访问。

后台数据库操作 MUST 使用 `performBackgroundTask` 创建独立的后台 context。

后台闭包 MUST 在进入前捕获必要的值,避免在闭包中访问 @Published 属性。

异步操作 MUST 显式切换线程,不使用 `nonisolated(unsafe)` 修饰符。

加载完成后 MUST 在主线程更新 UI 状态。

#### Scenario: 主线程访问 viewContext

- **WHEN** 需要同步查询少量日志数据
- **THEN** 在主线程访问 `viewContext`
- **AND** 不会触发线程安全警告
- **AND** 不会导致崩溃
- **AND** 查询应足够快,不阻塞UI

#### Scenario: 后台执行数据库查询

- **WHEN** 需要执行耗时的数据库查询
- **THEN** 使用 `performBackgroundTask` 创建后台 context
- **AND** 在后台 context 中执行查询
- **AND** 查询完成后在主线程更新 UI
- **AND** 不阻塞主线程

#### Scenario: 避免数据竞争

- **WHEN** 多个线程同时访问数据库管理器
- **THEN** 不会发生数据竞争
- **AND** Thread Sanitizer 不报告错误
- **AND** 应用保持稳定

#### Scenario: 错误处理

- **WHEN** 数据库查询失败
- **THEN** 错误信息在主线程更新到 UI 状态
- **AND** 用户看到友好的错误提示
- **AND** 应用不会崩溃

#### Scenario: 避免在闭包中访问@Published属性

- **WHEN** 执行后台数据库查询
- **THEN** 在进入performBackgroundTask闭包前捕获所需的值
- **AND** 闭包内不直接访问self的@Published属性
- **AND** 仅在主线程回调中更新@Published属性

---

### Requirement: 错误处理和用户反馈

系统 SHALL 为所有异步数据库操作提供错误处理和用户反馈。

数据库查询失败 MUST 在UI上显示错误消息。

系统 MAY 提供自动重试机制(最多重试1次)。

系统 MUST 记录错误日志,便于调试和问题定位。

#### Scenario: 查询失败显示错误

- **WHEN** 数据库查询失败
- **THEN** UI显示错误提示消息
- **AND** 提示消息清晰说明错误原因
- **AND** 提供"重试"按钮

#### Scenario: 自动重试失败的查询

- **WHEN** 首次查询失败
- **THEN** 系统自动在1秒后重试一次
- **AND** 如果重试成功,正常显示数据
- **AND** 如果重试仍失败,显示错误提示

#### Scenario: 错误日志记录

- **WHEN** 任何数据库操作失败
- **THEN** 系统记录详细的错误日志
- **AND** 日志包含失败的操作类型、参数、错误信息
- **AND** 便于开发者调试

#### Scenario: 加载状态指示

- **WHEN** 执行异步数据库查询
- **THEN** UI显示加载指示器
- **AND** 查询完成或失败后隐藏指示器
- **AND** 用户了解当前操作状态

---

### Requirement: 数据一致性和刷新策略

系统 SHALL 提供明确的数据刷新策略,平衡性能和数据新鲜度。

系统 SHOULD 采用"快照式分页"模式,分页加载期间不实时刷新已显示数据。

系统 MUST 在用户切换过滤条件时重置分页状态并重新加载。

系统 SHOULD 提供手动刷新机制(下拉刷新)。

#### Scenario: 分页期间数据库新增日志

- **WHEN** 用户正在查看第二页,数据库新增了日志
- **THEN** 已显示的数据不自动刷新
- **AND** 新日志不影响当前分页结果
- **AND** 用户可以手动刷新查看新日志

#### Scenario: 过滤条件变化重置分页

- **WHEN** 用户修改过滤条件(如选择不同的日志级别)
- **THEN** 系统重置 currentPage = 0
- **AND** 清空 displayEvents 数组
- **AND** 重新加载第一页
- **AND** 取消任何正在进行的加载

#### Scenario: 手动下拉刷新

- **WHEN** 用户在列表顶部下拉刷新
- **THEN** 系统清空现有数据
- **AND** 重置分页状态
- **AND** 重新加载第一页
- **AND** 显示最新的日志

#### Scenario: 快照式分页保证一致性

- **WHEN** 用户从第一页滚动到第二页
- **THEN** 第二页数据基于与第一页相同的排序和过滤条件
- **AND** 不会出现重复的日志
- **AND** 不会遗漏日志
- **AND** 数据顺序保持一致

### Requirement: LogRow 显示数据模型

系统 SHALL 使用专用 ViewModel 封装 LogRow 的显示数据，避免在 View 层执行计算逻辑。

LogRowViewModel MUST 实现 `Identifiable` 协议，使用 LogEvent.id 作为唯一标识。

LogRowViewModel MUST 封装以下数据：
- `event: LogEvent` - 原始日志数据
- `index: Int` - 显示序号（从 1 开始）
- `cachedColor: Color` - 预计算的 session 颜色

sessionColor 计算 MUST 在 ViewModel 初始化时执行，而不是在 View 渲染时执行。

#### Scenario: ViewModel 封装显示数据

- **WHEN** 从数据库加载日志数据
- **THEN** 为每条 LogEvent 创建对应的 LogRowViewModel
- **AND** ViewModel 包含 event、index 和 cachedColor
- **AND** index 从 1 开始连续递增

#### Scenario: 预计算 session 颜色

- **WHEN** 创建 LogRowViewModel
- **THEN** 在 init 方法中计算并缓存 sessionColor
- **AND** sessionColor 基于 event.sessionId 稳定生成
- **AND** 相同 sessionId 始终生成相同颜色

#### Scenario: 使用 event.id 作为唯一标识

- **WHEN** ForEach 迭代 LogRowViewModel 数组
- **THEN** 使用 ViewModel.id（即 event.id）作为标识符
- **AND** SwiftUI 正确识别每个 row 的身份
- **AND** 数据更新时 row 复用逻辑正确

#### Scenario: 分页加载时 index 连续性

- **WHEN** 加载第二页数据（第 501-1000 条）
- **THEN** 新 ViewModel 的 index 从 501 开始
- **AND** index 不会重新从 1 开始
- **AND** 所有 ViewModel 的 index 唯一且连续

---

### Requirement: 全量日志导出

系统 SHALL 提供导出功能,允许用户导出所有日志到文件。

导出功能 MUST 使用流式写入,分批查询和追加写入,避免全量内存加载。

导出查询 MUST 返回所有符合当前筛选条件的日志,不受数量限制。

导出过程 MUST 在后台线程执行,避免阻塞主线程。

导出过程 MUST 显示实时进度(百分比和已导出条数)。

导出操作 MUST 支持取消,及时释放资源。

内存占用 MUST 保持在 10MB 以内,无论导出数量多少。

导出文件格式 MUST 保持与现有实现一致(每行: `prefix - message`)。

导出文件名 MUST 使用格式：`{bundleId}_{identifier}_{YYYY-MM-DD}_{HHmmss}.log`，其中：
- `{bundleId}` 为应用的 Bundle Identifier（若为 nil 则使用 "unknown"）
- `{identifier}` 为 8 位 UUID 应用标识（从 UserDefaults 读取或生成）
- `{YYYY-MM-DD}` 为导出数据集中第一条日志的日期（ISO 8601 格式）
- `{HHmmss}` 为导出数据集中第一条日志的时间（24 小时制，无分隔符）
- `.log` 为固定文件扩展名

当导出数据为空时，系统 MUST 禁止导出操作，不生成文件。

#### Scenario: 流式导出大量日志

- **WHEN** 用户导出 100,000 条日志
- **THEN** 系统分批查询(每批 1000 条)
- **AND** 每批数据转换为字符串后追加写入文件
- **AND** 每批写入完成后立即释放内存
- **AND** 峰值内存占用 < 10MB
- **AND** 导出成功完成,文件大小约 80MB

#### Scenario: 导出进度实时反馈

- **WHEN** 导出正在进行
- **THEN** UI 显示进度条,百分比从 0% 到 100%
- **AND** 显示文本"已导出 X / 总计 Y 条"
- **AND** 进度每完成 1 批(1000 条)更新一次
- **AND** 用户清楚了解当前进度和剩余时间

#### Scenario: 取消导出操作

- **WHEN** 用户在导出过程中点击取消按钮
- **THEN** 系统立即停止当前批次查询
- **AND** 删除未完成的临时文件
- **AND** 释放已分配的资源(FileHandle)
- **AND** UI 恢复到导出前状态
- **AND** 最长取消延迟 < 100ms

#### Scenario: 导出尊重筛选条件

- **WHEN** 用户设置了筛选条件(如只显示 ERROR 级别)
- **AND** 数据库中 ERROR 日志有 5,000 条
- **AND** 用户点击导出按钮
- **THEN** 系统查询总数为 5,000 条
- **AND** 分 5 批导出(每批 1000 条)
- **AND** 导出的文件仅包含 ERROR 级别日志
- **AND** 不包含其他级别的日志

#### Scenario: 导出超大数据集(无限制)

- **WHEN** 用户导出 500,000 条日志(5 倍于旧限制)
- **THEN** 系统成功导出所有日志
- **AND** 峰值内存占用仍保持 < 10MB
- **AND** 进度条正常工作
- **AND** 不会因内存不足崩溃

#### Scenario: 导出文件格式兼容性

- **WHEN** 用户使用新方法导出日志
- **THEN** 生成的文件格式与旧方法完全一致
- **AND** 每行格式为: `2025-12-16 10:00:01 [ERROR] fileName.swift func() - message`
- **AND** 行之间以 `\n` 分隔
- **AND** 文件可被旧版本代码读取

#### Scenario: 导出文件名包含时间信息

- **WHEN** 用户在 2025-12-16 14:30:20 导出日志
- **AND** 导出数据集中第一条日志的时间戳为 2025-12-16 14:30:20
- **AND** Bundle ID 为 "com.example.LoggerKit"
- **AND** identifier 为 "a1b2c3d4"
- **THEN** 导出文件名为 `com.example.LoggerKit_a1b2c3d4_2025-12-16_143020.log`
- **AND** 文件名清晰标识了导出时间范围的起点
- **AND** 文件扩展名为 `.log`

#### Scenario: 空数据禁止导出

- **WHEN** 用户尝试导出日志
- **AND** 当前筛选条件下没有任何日志数据
- **THEN** 系统显示错误提示"没有可导出的日志"
- **AND** 不创建临时文件
- **AND** 不弹出分享界面
- **AND** 用户清楚了解无法导出的原因

#### Scenario: Bundle ID 为 nil 的回退逻辑

- **WHEN** Bundle.main.bundleIdentifier 返回 nil
- **AND** 用户导出日志
- **THEN** 文件名中 bundleId 部分使用 "unknown"
- **AND** 文件名格式为 `unknown_a1b2c3d4_2025-12-16_143020.log`
- **AND** 导出正常完成

#### Scenario: 多次导出文件名不冲突

- **WHEN** 用户在 14:30:20 导出一次日志
- **AND** 在 14:30:25 再次导出相同数据
- **THEN** 两个文件名不同
- **AND** 第一个文件名为 `...2025-12-16_143020.log`
- **AND** 第二个文件名为 `...2025-12-16_143025.log`（假设第一条日志时间不同）
- **AND** 两个文件都可以正常保存和分享

### Requirement: 初始加载使用分页

系统 SHALL 在首次打开日志界面时使用分页加载，而不是全量加载。

初始加载 MUST 仅加载第一页（默认 500 条），而不是一次性加载全部日志。

`loadAllLogsFromDatabase()` 和 `loadLogsForDate()` MUST 复用 `loadLogsFromDatabase(resetPagination: true)` 的分页逻辑。

初始加载时间 SHOULD 显著缩短（相比全量加载减少 50-70%）。

#### Scenario: 首屏分页加载

- **WHEN** 用户首次打开日志界面
- **THEN** 系统仅加载第一页（500 条日志）
- **AND** 不加载全部 10000 条日志
- **AND** 加载速度明显快于全量加载

#### Scenario: 统一分页逻辑

- **WHEN** 调用 `loadAllLogsFromDatabase()` 或 `loadLogsForDate()`
- **THEN** 内部调用 `loadLogsFromDatabase(resetPagination: true)`
- **AND** 不执行独立的全量查询
- **AND** 逻辑统一，易于维护

---

### Requirement: 显示符合筛选条件的日志总数

系统 SHALL 显示符合当前筛选条件的日志总数，而不仅是已加载的数量。

系统 MUST 提供 `totalCount` 属性，表示数据库中符合筛选条件的日志总数。

UI MUST 显示"已加载 X / 总计 Y 条"格式的统计信息。

系统 MUST 在重置分页时（首次加载、筛选条件变化）查询并更新 `totalCount`。

总数查询 MUST 使用 COUNT 查询，不加载实际数据，确保性能。

#### Scenario: 显示准确的总数统计

- **WHEN** 用户打开日志界面，仅加载了第一页（500 条）
- **AND** 数据库中实际有 5000 条日志
- **THEN** UI 显示"已加载 500 / 总计 5000 条"
- **AND** 不显示"总计 500 条"（误导用户）

#### Scenario: 分页加载后统计更新

- **WHEN** 用户滚动加载更多，已加载变为 1000 条
- **AND** 总数仍为 5000 条
- **THEN** UI 显示"已加载 1000 / 总计 5000 条"
- **AND** 总数不变

#### Scenario: 筛选后总数重新计算

- **WHEN** 用户应用筛选条件（如只显示 ERROR 级别）
- **AND** 符合条件的日志仅有 200 条
- **THEN** 系统重新查询总数
- **AND** UI 显示"已加载 100 / 总计 200 条"（假设加载了 100 条）

#### Scenario: COUNT 查询性能

- **WHEN** 系统查询总数
- **THEN** 使用 COUNT 查询，不加载实际 LogEvent 数据
- **AND** 查询速度快（< 100ms）
- **AND** 不影响 UI 响应

---

