# LoggerKit

基于 SwiftyBeaver 的高性能日志框架，支持多平台、实例化设计、依赖注入。

## 特性

- 支持 iOS 15+、macOS 12+、watchOS 8+、tvOS 15+
- 实例化设计，支持依赖注入和 Mock 测试
- 多目标输出（Console、File）
- SwiftUI Environment 支持
- 线程安全
- 高性能异步 IO
- 日志轮转和自动清理
- JSON 格式日志文件
- 自动提取模块名

## 安装

### Swift Package Manager

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/HeminWon/LoggerKit.git", from: "0.1.0")
]
```

然后在 target 中添加：

```swift
.target(
    name: "YourTarget",
    dependencies: ["LoggerKit"]
)
```

## 示例应用

想要快速体验 LoggerKit 的所有功能?我们提供了完整的 iOS 示例应用!

### 运行示例

```bash
# 克隆仓库
git clone https://github.com/HeminWon/LoggerKit.git
cd LoggerKit

# 打开示例项目
open Examples/iOS/LoggerKitExample/LoggerKitExample.xcodeproj
```

示例应用包含:
- ✅ 基础使用 - 6 种日志级别演示
- ✅ 高级配置 - 自定义配置和文件轮转
- ✅ 日志查看器 - UI 组件集成演示
- ✅ 依赖注入 - 多种注入模式示例
- ✅ 性能测试 - 批量日志性能评估
- ✅ 多线程场景 - 并发安全性测试

📖 [查看示例应用完整文档](Examples/iOS/README.md)

## 快速开始

### ⚠️ 重要：配置日志引擎

**在使用 LoggerKit 之前，必须在 App 启动时尽早配置日志引擎。** 未配置时调用日志方法，日志会被静默丢弃。

#### UIKit App

```swift
import UIKit
import LoggerKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // ✅ 第一件事：配置日志引擎
        LoggerKit.configure(
            level: .debug,
            enableConsole: true,
            enableDatabase: true
        )

        // 之后的所有日志都会被正确记录
        return true
    }
}
```

#### SwiftUI App

```swift
import SwiftUI
import LoggerKit

@main
struct MyApp: App {
    init() {
        // ✅ 在 App 初始化时配置日志引擎
        LoggerKit.configure(
            level: .debug,
            enableConsole: true,
            enableDatabase: true
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### 💡 最佳实践

- ✅ 在 `AppDelegate.application(_:didFinishLaunchingWithOptions:)` 第一行配置
- ✅ 在 SwiftUI `App.init()` 中配置
- ❌ 不要在 viewDidLoad 或 view body 中配置
- ❌ 不要延迟配置（如 DispatchQueue.main.async）

#### ⚠️ 未配置的影响

- 未配置时调用日志方法，日志会被静默丢弃
- 不会崩溃、不会警告、没有性能开销
- DEBUG 模式下重复配置会触发 `assertionFailure`

### 基础使用

```swift
import LoggerKit

// 创建 logger 实例
let logger = Logger()

// 记录日志
logger.verbose("详细信息")
logger.debug("调试信息")
logger.info("普通信息")
logger.warning("警告信息")
logger.error("错误信息")
```

### 全局实例（推荐）

在 App 入口创建全局实例：

```swift
import SwiftUI
@_exported import LoggerKit

public let log = Logger()

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.logger, log)
        }
    }
}
```

然后在任意位置使用：

```swift
log.debug("这是调试信息")
log.info("用户登录成功")
log.error("网络请求失败")
```

### SwiftUI Environment 注入

```swift
struct MyView: View {
    @Environment(\.logger) var logger

    var body: some View {
        Button("Log") {
            logger.info("Button tapped")
        }
    }
}
```

### 依赖注入（Service/ViewModel）

```swift
class UserService {
    private let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func login() {
        logger.info("User logging in")
    }
}

// 使用
let service = UserService(logger: Logger())
```

## 自定义配置

### 指定日志级别

```swift
let logger = Logger(
    level: .info,           // 最低日志级别
    enableConsole: true,    // 启用控制台输出
    enableFile: true        // 启用文件输出
)
```

### 自定义配置

```swift
let consoleDestination = ConsoleLogDestination(minLevel: .debug)
let fileDestination = FileLogDestination(
    fileURL: customFileURL,
    minLevel: .info,
    rotationPolicy: .size(5 * 1024 * 1024) // 5MB
)

let config = LogConfiguration(destinations: [consoleDestination, fileDestination])
let logger = Logger(configuration: config)
```

## 日志轮转

LoggerKit 支持多种日志轮转策略，自动管理日志文件大小和数量。

### 轮转策略

| 策略 | 说明 | 示例 |
|-----|------|------|
| `.size(Int)` | 文件超过指定字节数时轮转 | `.size(10 * 1024 * 1024)` = 10MB |
| `.time(TimeInterval)` | 文件超过指定秒数时轮转 | `.time(3600)` = 1小时 |
| `.daily` | 每日轮转 | - |
| `.never` | 不轮转 | - |

### 默认配置

- 轮转策略: `.size(10 * 1024 * 1024)` (10MB)
- 最大文件数: 10 个

### 自定义轮转策略

```swift
// 基于文件大小轮转（5MB，保留 10 个文件）
let config = LogConfiguration(
    destinations: [],
    rotationPolicy: .size(5 * 1024 * 1024),
    maxLogFiles: 10
)
let logger = Logger(configuration: config)

// 每日轮转（保留 7 天）
let config = LogConfiguration(
    destinations: [],
    rotationPolicy: .daily,
    maxLogFiles: 7
)
let logger = Logger(configuration: config)

// 基于时间轮转（每小时，保留 24 个文件）
let config = LogConfiguration(
    destinations: [],
    rotationPolicy: .time(3600),
    maxLogFiles: 24
)
let logger = Logger(configuration: config)

// 不轮转
let config = LogConfiguration(
    destinations: [],
    rotationPolicy: .never,
    maxLogFiles: 1
)
let logger = Logger(configuration: config)
```

### 手动触发轮转检查

可以在合适的时机（如 App 进入后台）手动触发轮转检查：

```swift
// 检查并执行轮转
logger.checkRotation()
```

## 日志级别

| 级别 | 用途 |
|------|------|
| `.verbose` | 最详细的信息，通常用于追踪 |
| `.debug` | 调试信息 |
| `.info` | 一般信息 |
| `.warning` | 警告信息 |
| `.error` | 错误信息 |

## 日志查看器

LoggerKit 内置日志查看界面：

```swift
import LoggerKit

NavigationLink("查看日志") {
    LogListScene()
}
```

功能：
- 查看所有日志文件
- 按级别筛选日志
- 分享日志文件
- 删除日志文件

## 日志文件

日志文件存储在：
```
Documents/LoggerKit/20231121-143052.123+0800.log
```

格式为 JSON Lines，每行一条日志：
```json
{"timestamp":1700550652.123,"level":1,"message":"Debug message","file":"/path/File.swift","function":"viewDidLoad()","line":42,"context":"MyModule","thread":"main"}
```

## 测试支持

创建 MockLogger 进行单元测试：

```swift
public final class MockLogger: LoggerProtocol {
    public var logs: [(level: String, message: String)] = []

    public func debug(_ message: String, file: String, function: String, line: Int) {
        logs.append(("DEBUG", message))
    }

    public func info(_ message: String, file: String, function: String, line: Int) {
        logs.append(("INFO", message))
    }

    public func warning(_ message: String, file: String, function: String, line: Int) {
        logs.append(("WARNING", message))
    }

    public func error(_ message: String, file: String, function: String, line: Int) {
        logs.append(("ERROR", message))
    }

    public func verbose(_ message: String, file: String, function: String, line: Int) {
        logs.append(("VERBOSE", message))
    }
}

// 测试
@Test
func testLogging() {
    let mock = MockLogger()
    let service = MyService(logger: mock)

    service.doSomething()

    #expect(mock.logs.contains { $0.message == "Something done" })
}
```

## API 参考

### Logger

```swift
public final class Logger: LoggerProtocol {
    // 初始化
    public init()
    public init(level: LogLevel, enableConsole: Bool, enableFile: Bool, logDirectory: URL?)
    public init(configuration: LogConfiguration)

    // 日志方法
    public func verbose(_ message: String, file: String, function: String, line: Int)
    public func debug(_ message: String, file: String, function: String, line: Int)
    public func info(_ message: String, file: String, function: String, line: Int)
    public func warning(_ message: String, file: String, function: String, line: Int)
    public func error(_ message: String, file: String, function: String, line: Int)

    // 刷新缓冲区
    public func flush()

    // 检查并执行日志轮转
    public func checkRotation()
}
```

### LoggerProtocol

```swift
public protocol LoggerProtocol: Sendable {
    func verbose(_ message: String, file: String, function: String, line: Int)
    func debug(_ message: String, file: String, function: String, line: Int)
    func info(_ message: String, file: String, function: String, line: Int)
    func warning(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, file: String, function: String, line: Int)
}
```

### Environment

```swift
extension EnvironmentValues {
    var logger: LoggerProtocol { get set }
}

extension View {
    func logger(_ logger: LoggerProtocol) -> some View
}
```

## 依赖

- [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) 2.1.1+

## License

MIT License
