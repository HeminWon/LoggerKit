# log-database Specification

## Purpose
TBD - created by archiving change optimize-phase1-performance. Update Purpose after archive.
## Requirements
### Requirement: 统计查询优化

系统 SHALL 使用单次或最少次数的数据库查询获取日志统计信息。

统计查询 MUST 使用 CoreData 的分组查询功能(`propertiesToGroupBy`),避免多次独立查询。

统计信息 MUST 包含:
- 总日志数量
- 各级别日志数量(verbose, debug, info, warning, error, critical, fault)
- 热门函数列表(Top 100)

单次查询 MUST 能够同时获取总数和各级别统计,减少数据库 I/O 往返次数。

查询性能 MUST 达到 50-100ms(相比优化前的 500ms,减少 80%)。

#### Scenario: 单次查询获取级别统计

- **WHEN** 请求日志统计信息
- **THEN** 使用单次分组查询获取所有级别的计数
- **AND** 查询使用 `NSExpressionDescription` 进行聚合统计
- **AND** 返回包含所有级别统计的结果

#### Scenario: 计算总日志数

- **WHEN** 获取统计信息
- **THEN** 通过对各级别计数求和得到总数
- **AND** 不需要单独的总数查询
- **AND** 结果准确无误

#### Scenario: 查询热门函数

- **WHEN** 需要获取热门函数列表
- **THEN** 使用分组查询按函数名统计调用次数
- **AND** 按计数降序排列
- **AND** 限制返回前 100 个结果
- **AND** 查询在单独的请求中执行(与级别统计分离)

#### Scenario: 查询性能提升

- **WHEN** 执行统计查询
- **THEN** 总查询次数从 9 次减少到 2 次
- **AND** 查询总耗时从 500ms 降至 50-100ms
- **AND** 性能提升 80% 以上

#### Scenario: 统计结果准确性

- **WHEN** 获取优化后的统计结果
- **THEN** 结果与优化前的逻辑一致
- **AND** 总数等于各级别计数之和
- **AND** 热门函数列表准确反映调用频率

---

### Requirement: 数据库资源初始化优化

系统 SHALL 优化 CoreData 模型资源的加载,避免重复查询。

模型 URL 查询 MUST 仅执行一次,并缓存结果。

模型文件查找 MUST 按优先级顺序尝试(momd > mom > xcdatamodeld)。

查找失败 MUST 抛出明确的错误,便于调试。

#### Scenario: 首次查询模型 URL

- **WHEN** 首次初始化 CoreDataStack
- **THEN** 按优先级顺序查找模型文件
- **AND** 找到第一个匹配的文件后立即返回
- **AND** 查询结果被缓存到静态属性

#### Scenario: 后续访问使用缓存

- **WHEN** 后续访问 CoreDataStack
- **THEN** 直接使用缓存的模型 URL
- **AND** 不再重复查询 Bundle 资源
- **AND** 初始化时间缩短

#### Scenario: 模型文件未找到

- **WHEN** Bundle 中不存在任何匹配的模型文件
- **THEN** 抛出 fatalError 并显示明确的错误信息
- **AND** 错误信息包含查找路径和文件类型
- **AND** 便于开发者快速定位问题

#### Scenario: 代码可读性提升

- **WHEN** 查看 CoreDataStack 初始化代码
- **THEN** 模型查找逻辑清晰简洁
- **AND** 使用循环遍历候选路径,避免重复代码
- **AND** 易于维护和扩展

---

### Requirement: 数据库索引优化

系统 SHALL 为高频查询字段添加数据库索引,提升查询性能。

索引 MUST 包含以下字段:
- `sessionId`: 会话ID过滤字段
- `level`: 日志级别过滤字段
- `timestamp`: 排序字段

索引策略 MUST 在实施前进行性能验证,对比有索引和无索引的查询性能差异。

对于文本搜索字段(`message`, `function`),系统 SHOULD 评估CONTAINS查询的性能影响,必要时实施优化措施。

#### Scenario: sessionId索引提升过滤性能

- **WHEN** 使用sessionId过滤查询10万条日志
- **THEN** 查询时间应 < 50ms(带索引)
- **AND** 相比无索引查询时间减少 80%+

#### Scenario: level索引支持多值过滤

- **WHEN** 使用level IN (error, critical)过滤
- **THEN** 索引应能正确处理IN查询
- **AND** 查询时间与结果集大小成正比,与总数据量无关

#### Scenario: timestamp索引优化排序

- **WHEN** 按timestamp降序排列查询结果
- **THEN** 排序操作应利用索引,避免全表扫描
- **AND** 排序时间应 < 10ms

#### Scenario: CONTAINS查询性能评估

- **WHEN** 使用searchText执行CONTAINS查询
- **THEN** 系统应测量查询时间
- **AND** 如果查询时间 > 200ms,应考虑优化措施:
  - 限制搜索文本最小长度(>=3字符)
  - 添加UI层debounce(300ms)
  - 考虑全文索引或前缀索引

#### Scenario: 复合查询索引优化

- **WHEN** 同时使用sessionId、level、timestamp过滤
- **THEN** 数据库应能组合利用多个索引
- **AND** 查询性能应接近单一索引查询

#### Scenario: 索引对写入性能的影响

- **WHEN** 批量插入1000条日志
- **THEN** 插入时间增加应 < 20%
- **AND** 索引维护不应成为性能瓶颈

---

### Requirement: 分页查询支持

系统 SHALL 支持分页查询日志,避免一次性加载所有数据到内存。

查询方法 MUST 接受 `offset` 和 `limit` 参数。

查询结果 MUST 按时间戳降序排列(最新日志在前)。

分页查询 MUST 支持所有现有的过滤条件(级别、会话 ID、日期范围等)。

#### Scenario: 查询第一页日志

- **WHEN** 请求查询前 500 条日志
- **THEN** 使用 `offset=0, limit=500` 执行查询
- **AND** 返回最新的 500 条日志
- **AND** 结果按时间戳降序排列

#### Scenario: 查询后续页

- **WHEN** 请求查询第二页日志
- **THEN** 使用 `offset=500, limit=500` 执行查询
- **AND** 返回接下来的 500 条日志
- **AND** 与第一页无重复,无遗漏

#### Scenario: 结合过滤条件分页

- **WHEN** 请求查询特定级别的日志并分页
- **THEN** 先应用过滤条件
- **AND** 再应用分页限制
- **AND** 返回符合条件的第 N 页日志

#### Scenario: 查询性能

- **WHEN** 执行分页查询
- **THEN** 查询时间与数据总量无关,仅与分页大小相关
- **AND** 单页查询时间 < 100ms
- **AND** 内存占用仅限于当前页数据

#### Scenario: 边界条件 - 空数据库

- **WHEN** 数据库中没有任何日志(0条)
- **THEN** 查询应返回空数组
- **AND** 不应抛出错误
- **AND** 查询时间应 < 10ms

#### Scenario: 边界条件 - 过滤结果为空

- **WHEN** 使用过滤条件但没有匹配的日志
- **THEN** 返回空数组
- **AND** hasMorePages应为false
- **AND** 不应尝试加载更多页

#### Scenario: 边界条件 - 数据量刚好等于pageSize

- **WHEN** 数据库有刚好500条匹配的日志
- **THEN** 第一页返回500条
- **AND** hasMorePages应为false
- **AND** 尝试加载第二页应返回空数组

#### Scenario: 边界条件 - 数据量为pageSize+1

- **WHEN** 数据库有501条匹配的日志
- **THEN** 第一页返回500条
- **AND** hasMorePages应为true
- **AND** 第二页返回1条
- **AND** 第二页之后hasMorePages为false

#### Scenario: 边界条件 - 最后一页不足pageSize

- **WHEN** 查询到最后一页,仅剩100条日志
- **THEN** 返回100条日志
- **AND** hasMorePages应为false
- **AND** 不应填充到pageSize

#### Scenario: 特殊字符处理

- **WHEN** searchText包含SQL特殊字符(%, _, ', ")
- **THEN** NSPredicate应正确转义
- **AND** 不应导致查询错误
- **AND** 不应存在SQL注入风险

