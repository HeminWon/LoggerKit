# log-session Specification

## Purpose
TBD - created by archiving change add-session-id. Update Purpose after archive.
## Requirements
### Requirement: Session ID Generation

系统 SHALL 在每次 App 启动时自动生成唯一的会话ID。

会话ID MUST 使用 UUID 的前8位（8个十六进制字符）作为标识符，格式如 `550e8400`。

会话ID 的生成 MUST 在 `LoggerEngine` 初始化时完成，确保在任何日志写入之前会话信息已经准备就绪。

#### Scenario: App 启动生成新会话ID

- **WHEN** App 启动并初始化 LoggerEngine
- **THEN** 生成新的会话ID（UUID前8位）
- **AND** 记录会话开始时间戳（当前时间）
- **AND** 会话ID在整个 App 生命周期内保持不变

#### Scenario: 会话ID格式正确

- **WHEN** 生成会话ID
- **THEN** 会话ID长度为8个字符
- **AND** 会话ID仅包含十六进制字符（0-9, a-f）

#### Scenario: 不同启动生成不同会话ID

- **WHEN** App 重新启动
- **THEN** 新生成的会话ID与上次启动的会话ID不同

### Requirement: Session Information Storage

系统 SHALL 在每条日志中存储会话信息，包括会话ID和会话开始时间。

日志事件结构 MUST 包含以下会话相关字段：
- `sessionId`: 当前会话的ID（String，非可选）
- `sessionStartTime`: 会话开始的时间戳（TimeInterval，非可选）

CoreData 数据模型 MUST 包含对应的字段以持久化会话信息：
- `sessionId`: String 类型，非可选，默认值 "unknown"
- `sessionStartTime`: Double 类型，非可选，默认值 0
- `bySessionId` 索引用于优化查询性能

#### Scenario: 日志包含会话信息

- **WHEN** 写入一条新日志
- **THEN** 日志的 sessionId 字段等于当前会话ID
- **AND** 日志的 sessionStartTime 字段等于当前会话的开始时间

#### Scenario: 会话信息持久化到数据库

- **WHEN** 日志写入到 CoreData
- **THEN** LogEventEntity 的 sessionId 字段正确存储
- **AND** LogEventEntity 的 sessionStartTime 字段正确存储
- **AND** 数据可以从数据库中正确读取

#### Scenario: 历史数据兼容性

- **WHEN** 读取没有会话信息的历史日志（如果存在）
- **THEN** sessionId 显示为默认值 "unknown"
- **AND** sessionStartTime 显示为默认值 0
- **AND** 不会导致崩溃或错误

### Requirement: Session Display Format

系统 SHALL 提供会话的展示格式，便于用户识别和区分不同会话。

会话展示文本 MUST 包含会话ID和会话开始时间，格式为 `{sessionId}-{yyyyMMddHHmm}`，例如 `550e8400-202512101430`。

日志列表 MUST 在每条日志中展示会话ID，并使用不同的灰度颜色区分不同会话。

会话颜色 MUST 基于 sessionId 生成，确保同一会话的所有日志显示相同颜色，不同会话显示不同颜色。

#### Scenario: 会话展示文本格式正确

- **WHEN** 获取会话的展示文本
- **THEN** 格式为 `{sessionId}-{yyyyMMddHHmm}`
- **AND** sessionId 为8位十六进制字符
- **AND** 时间部分为12位数字（年月日时分）

#### Scenario: 日志列表展示会话颜色

- **WHEN** 在日志列表中展示日志
- **THEN** 每条日志的 sessionId 使用专属的灰度颜色显示
- **AND** 同一会话的所有日志使用相同颜色
- **AND** 不同会话使用不同颜色（灰度范围 0.25-0.75）

#### Scenario: 会话颜色跨运行时一致

- **WHEN** 多次启动 App 查看同一会话的日志
- **THEN** 该会话的颜色在所有启动中保持一致
- **AND** 颜色基于 sessionId 的稳定 hash 算法生成

### Requirement: Session Filtering

系统 SHALL 支持查询所有会话列表，并允许用户按会话ID筛选日志。

会话列表查询 MUST 返回去重后的会话信息，包括：
- 会话ID
- 会话开始时间
- 该会话的日志数量

会话列表 MUST 按会话开始时间倒序排列（最新会话在前）。

日志筛选器 MUST 支持按 sessionId 筛选日志，筛选结果仅包含属于该会话的日志。

#### Scenario: 查询所有会话列表

- **WHEN** 请求获取所有会话列表
- **THEN** 返回所有唯一的会话ID
- **AND** 每个会话包含 id、startTime 和 logCount 字段
- **AND** 会话列表按 startTime 倒序排列

#### Scenario: 会话日志数量统计正确

- **WHEN** 获取会话列表
- **THEN** 每个会话的 logCount 等于该会话的实际日志数量
- **AND** 统计结果准确无误

#### Scenario: 按会话ID筛选日志

- **WHEN** 选择一个会话进行筛选
- **THEN** 仅返回该会话的日志
- **AND** 其他会话的日志不会出现在结果中

#### Scenario: 清除会话筛选

- **WHEN** 用户清除会话筛选条件
- **THEN** 显示所有会话的日志
- **AND** 不再限制会话ID

### Requirement: Session Filter UI

系统 SHALL 在日志筛选器UI中提供会话选择功能。

筛选器 MUST 展示会话列表，每个会话显示格式为 `{sessionId}-{时间} ({日志数量}条)`，例如 `550e8400-202512101430 (123条)`。

筛选器 MUST 支持加载状态、错误状态和空状态的 UI 反馈：
- 加载中：显示 ProgressView 和 "加载中..." 文案
- 加载失败：显示错误信息和"重试"按钮
- 无会话：显示 "暂无会话记录" 提示

用户 MUST 能够点击会话进行选择，选中的会话显示勾选标记。

#### Scenario: 会话列表正常加载

- **WHEN** 打开筛选器
- **THEN** 显示加载中状态
- **AND** 异步加载会话列表
- **AND** 加载完成后展示会话列表

#### Scenario: 会话列表加载失败

- **WHEN** 会话列表加载失败（如数据库错误）
- **THEN** 显示错误信息
- **AND** 显示"重试"按钮
- **AND** 点击"重试"按钮重新加载

#### Scenario: 无会话记录

- **WHEN** 数据库中没有任何日志
- **THEN** 显示 "暂无会话记录" 提示
- **AND** 不显示加载中或错误状态

#### Scenario: 选择会话

- **WHEN** 用户点击一个会话
- **THEN** 该会话被选中
- **AND** 该会话旁边显示勾选标记
- **AND** 日志列表自动更新为该会话的日志

#### Scenario: 切换会话

- **WHEN** 用户选择另一个会话
- **THEN** 之前的会话取消选中
- **AND** 新会话被选中并显示勾选标记
- **AND** 日志列表更新为新会话的日志

### Requirement: Session Localization

系统 SHALL 提供会话相关的本地化文案支持。

本地化字符串 MUST 包含以下键值对：
- `session`: "会话"
- `session_id`: "会话ID"
- `session_filter`: "按会话筛选"
- `no_session`: "暂无会话记录"
- `session_loading`: "加载中..."
- `session_load_failed`: "会话加载失败"
- `session_retry`: "重试"

#### Scenario: 本地化文案正确显示

- **WHEN** UI 展示会话相关文案
- **THEN** 使用本地化字符串
- **AND** 中文环境显示中文文案
- **AND** 其他语言环境显示对应语言文案（如已配置）

