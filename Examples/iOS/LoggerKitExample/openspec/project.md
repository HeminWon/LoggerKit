# Project Context

## Purpose

LoggerKit 是一个基于 SwiftyBeaver 的高性能日志框架，专为 Apple 平台设计。项目目标：

- 提供实例化设计的日志系统，支持依赖注入和 Mock 测试
- 支持多目标输出（控制台、CoreData 数据库）
- 提供内置日志查看器 UI 组件
- 支持日志轮转和自动清理
- 线程安全和高性能异步 IO
- 支持 iOS 15+、macOS 12+、watchOS 8+、tvOS 15+

## Tech Stack

**核心技术栈**:
- Swift 5.9+
- Swift Package Manager
- SwiftyBeaver 2.1.1+ (底层日志引擎)
- CoreData (日志持久化存储)
- SwiftUI (UI 组件)

**开发工具**:
- Xcode 15+
- Swift Testing 框架
- Git (版本控制)

**平台支持**:
- iOS 15+
- macOS 12+
- watchOS 8+
- tvOS 15+

## Project Conventions

### Code Style

**命名约定**:
- 类型名：大驼峰（PascalCase），如 `Logger`, `LoggerEngine`, `CoreDataStack`
- 变量/函数：小驼峰（camelCase），如 `sessionId`, `performDatabaseRotation()`
- 协议：以 `Protocol` 后缀命名，如 `LoggerProtocol`
- 常量：小驼峰或全大写，如 `logDirectoryName`, `Constants.UserDefaultsKeys`

**访问控制**:
- 公开 API 使用 `public` 修饰符
- 内部实现使用 `private` 或 `fileprivate`
- 优先使用协议定义公开接口

**文档注释**:
- 所有公开 API 必须包含文档注释（`///`）
- 包含使用示例的代码块
- 说明参数、返回值和注意事项

**格式规范**:
- 使用 4 空格缩进
- 代码行建议不超过 120 字符
- 使用 SwiftLint 风格（如已配置）

### Architecture Patterns

**核心架构**:
- **Singleton Engine 模式**: `LoggerEngine` 作为单例管理底层资源（SwiftyBeaver、CoreData）
- **轻量级值类型**: `Logger` 是值类型（struct），可随意创建多个实例，共享同一个 `LoggerEngine`
- **协议驱动设计**: 使用 `LoggerProtocol` 支持依赖注入和 Mock 测试
- **Destination 模式**: 日志输出到多个目标（Console、CoreData），继承自 SwiftyBeaver 的 `BaseDestination`

**模块分层**:
```
Core/               # 核心日志接口和引擎
├── Logger.swift           # 轻量级日志实例
├── LoggerProtocol.swift   # 协议定义
├── LoggerEngine.swift     # 引擎单例
└── LoggerEnvironment.swift # SwiftUI Environment 支持

Database/           # 数据库持久化
├── CoreDataStack.swift           # CoreData 栈
├── CoreDataDestination.swift     # 日志写入目标
├── LogDatabaseManager.swift      # 数据库查询管理
├── LogDatabaseRotationManager.swift # 轮转管理
└── LogEventEntity+*.swift        # CoreData 实体

UI/                 # 日志查看器
├── LogDetailScene.swift       # 日志列表主界面
├── LogDetailSceneState.swift  # 状态管理
├── LogFilterSheet.swift       # 筛选器
└── Components/               # 可复用组件

Configuration/      # 配置模块
Parser/             # 日志解析
Testing/            # Mock 工具
Utilities/          # 工具类
```

**数据流**:
```
Logger → LoggerEngine → SwiftyBeaver → Destinations
                                         ├→ ConsoleDestination (控制台)
                                         └→ CoreDataDestination (数据库)
```

**并发安全**:
- `Logger` 和 `LoggerProtocol` 遵循 `Sendable` 协议
- `LoggerEngine` 使用 `NSLock` 保护共享状态
- CoreData 使用后台上下文处理批量写入

### Testing Strategy

**测试框架**:
- Swift Testing 框架（`@Test`, `@Suite`）
- 使用 `@testable import LoggerKit` 访问内部类型

**测试覆盖**:
- 核心功能：Logger 初始化、配置、日志写入
- Mock 工具：`MockLogger` 的捕获和验证功能
- 工具类：`ConcurrentCache`、`LogParser`、日志轮转逻辑
- 边界条件：空数据、无效输入、并发访问

**Mock 设计**:
- 提供 `MockLogger` 用于单元测试
- 支持调用记录、级别筛选、验证方法
- 示例：
  ```swift
  let mock = MockLogger()
  service.doSomething(logger: mock)
  #expect(mock.verify(level: "INFO", message: "Expected log"))
  ```

**性能测试**:
- 批量日志写入性能（10万条日志）
- 并发场景下的线程安全验证
- 大数据量查询性能（CoreData 索引验证）

### Git Workflow

**分支策略**:
- `main`: 主分支，生产就绪代码
- `develop`: 开发分支，集成最新功能
- `feature/*`: 功能分支，命名如 `feature/session-id`
- `bugfix/*`: 修复分支

**提交规范**:
- 使用 **Conventional Commits** 和 **Gitmoji**
- 格式：`<emoji> <type>(<scope>): <description>`
- 示例：
  ```
  ✨ feat(database): migrate storage from file system to CoreData
  ♻️ refactor(logger): optimize session ID generation
  🐛 fix(ui): fix filter sheet layout issue
  📝 docs: update README with installation guide
  ```

**类型标签**:
- `feat`: 新功能
- `fix`: Bug 修复
- `refactor`: 重构
- `docs`: 文档
- `test`: 测试
- `chore`: 构建/工具配置

## Domain Context

**日志系统领域知识**:

**日志级别**（从低到高）:
- `verbose`: 最详细的追踪信息
- `debug`: 调试信息
- `info`: 一般信息
- `warning`: 警告信息
- `error`: 错误信息

**日志轮转策略**:
- `.size(Int)`: 文件超过指定字节数时轮转
- `.time(TimeInterval)`: 文件超过指定秒数时轮转
- `.daily`: 每日轮转
- `.never`: 不轮转

**会话（Session）概念**:
- 每次 App 启动生成唯一会话 ID（前8位 UUID）
- 用于标识 App 完整生命周期
- 支持按会话筛选日志
- 会话开始时间用于排序和展示

**日志存储**:
- 历史方案：JSON Lines 文件存储（已废弃）
- 当前方案：CoreData 数据库存储
- 默认位置：`Documents/LoggerKit/logs.sqlite`
- 启用 WAL 模式（Write-Ahead Logging）提升性能

## Important Constraints

**技术约束**:
- 最低支持 Swift 5.9
- 必须兼容 iOS 15+ 及其他 Apple 平台
- CoreData 模型变更需要考虑数据迁移（开发阶段可接受清理数据）
- 线程安全是核心要求，所有公开 API 必须并发安全

**性能约束**:
- 日志写入必须异步，不能阻塞主线程
- 数据库默认最大 100MB，超出需轮转
- 日志默认保留 30 天
- 大数据量查询需使用索引优化（sessionId, timestamp）

**开发阶段约束**:
- 当前处于开发阶段，CoreData 模型可直接修改
- 如遇模型冲突，可删除 App 重新安装
- 未来发布到生产环境需配置轻量级迁移

**设计约束**:
- `Logger` 必须是轻量级值类型，支持随意创建
- 所有日志 API 必须提供默认参数（`#file`, `#function`, `#line`）
- 公开协议 `LoggerProtocol` 便于依赖注入和测试

## External Dependencies

**核心依赖**:
- **SwiftyBeaver** (2.1.1+): 底层日志引擎
  - 提供日志格式化、多目标输出、级别过滤
  - LoggerKit 继承其 `BaseDestination` 实现自定义输出
  - GitHub: https://github.com/SwiftyBeaver/SwiftyBeaver

**系统框架**:
- Foundation: 基础类型和工具
- CoreData: 日志持久化存储
- SwiftUI: 日志查看器 UI
- Combine: 异步数据流（如需要）

**无外部服务依赖**:
- 日志完全存储在本地设备
- 无网络上传或云端同步功能
- 无第三方分析服务集成
