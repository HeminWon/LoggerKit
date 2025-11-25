# LoggerKit iOS 示例应用

这是 LoggerKit 的官方 iOS 示例应用,展示了如何在 UIKit 项目中使用 LoggerKit。

## 功能概览

示例应用展示了以下功能:

### 1. 全局 Logger 实例
- 使用 `log` 全局实例
- 无需手动创建 Logger 对象
- 简洁的 API 调用方式

### 2. 各种日志级别
- Verbose: 最详细的调试信息
- Debug: 开发调试信息
- Info: 一般信息记录
- Warning: 警告信息
- Error: 错误信息

### 3. 实际应用场景
- 结构化数据日志
- 网络请求日志
- 用户行为追踪日志

### 4. 日志查看器 (UIKit 集成)
- 使用 `LogListScene.makeViewController()` 创建日志查看器
- 支持 Push 导航
- 查看所有日志文件
- 日志搜索和过滤功能

## 快速开始

### 运行示例应用

1. 克隆 LoggerKit 仓库:
```bash
git clone https://github.com/yourusername/LoggerKit.git
cd LoggerKit
```

2. 打开示例项目:
```bash
open Examples/iOS/LoggerKitExample/LoggerKitExample.xcodeproj
```

3. 在 Xcode 中选择目标设备并运行 (⌘R)

### 系统要求

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

## 项目结构

```
LoggerKitExample/
├── AppDelegate.swift          # 应用代理
├── SceneDelegate.swift        # 场景代理 (配置 NavigationController)
├── ViewController.swift       # 主视图控制器 (演示所有功能)
└── Assets.xcassets/          # 资源文件
```

## 代码示例

### 1. 配置 LoggerKit (AppDelegate 或首个 ViewController)

```swift
import LoggerKit

// 在应用启动时配置一次
LoggerKit.configure(
    level: .verbose,
    enableConsole: true,
    enableFile: true,
    fileGenerationPolicy: .daily,
    rotationPolicy: .size(10 * 1024 * 1024),
    maxLogFiles: 7
)
```

### 2. 使用全局 log 实例记录日志

```swift
import LoggerKit

// 直接使用全局 log 实例
log.verbose("详细调试信息")
log.debug("调试信息")
log.info("普通信息")
log.warning("警告信息")
log.error("错误信息")
```

### 3. 在 UIKit 中展示日志查看器

```swift
import LoggerKit

class MyViewController: UIViewController {

    @objc func showLogs() {
        // 使用静态方法创建日志查看器
        let logVC = LogListScene.makeViewController()

        // Push 方式
        navigationController?.pushViewController(logVC, animated: true)

        // 或者 Present 方式
        // let nav = UINavigationController(rootViewController: logVC)
        // present(nav, animated: true)
    }
}
```

### 4. 实际应用场景示例

#### 网络请求日志
```swift
log.debug("发起网络请求 -> POST https://api.example.com/users")
log.debug("请求头: Content-Type=application/json")
log.info("网络请求成功 <- 状态码: 201, 响应时间: 245ms")
```

#### 用户行为追踪
```swift
log.info("用户操作: 点击按钮 [登录] 在页面 [LoginViewController]")
log.debug("会话ID: \(sessionID)")
```

#### 错误日志
```swift
log.error("数据加载失败: \(error.localizedDescription)")
log.warning("内存使用率较高: 85%")
```

## 集成到你的应用

### 添加依赖

在 Package.swift 中添加 LoggerKit:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/LoggerKit.git", from: "1.0.0")
]
```

或在 Xcode 中:
1. File → Add Packages...
2. 输入仓库 URL: `https://github.com/yourusername/LoggerKit.git`
3. 选择版本并添加

### 三步集成

#### 步骤 1: 导入并配置

```swift
import LoggerKit

// 在 AppDelegate 或 SceneDelegate 中配置
LoggerKit.configure(
    level: .debug,
    enableConsole: true,
    enableFile: true
)
```

#### 步骤 2: 使用全局 log 实例

```swift
// 在任何地方直接使用
log.info("应用已启动")
log.debug("调试信息")
log.error("发生错误")
```

#### 步骤 3: 添加日志查看器 (可选)

```swift
// UIKit
let logVC = LogListScene.makeViewController()
navigationController?.pushViewController(logVC, animated: true)

// SwiftUI
NavigationLink("查看日志") {
    LogListScene()
}
```

## 常见问题

### 日志文件在哪里?

日志文件保存在应用的 Documents 目录下的 `LoggerKit` 文件夹中:
```
Documents/LoggerKit/日志文件.log
```

你可以使用 `LogListScene.makeViewController()` 查看和分享日志文件。

### 如何查看日志?

有三种方式:
1. 使用内置的 `LogListScene` UI 组件
2. 在 Xcode 控制台查看 (启用 enableConsole 时)
3. 导出日志文件并使用文本编辑器打开

### 全局 log 和自定义 Logger 的区别?

```swift
// 方式 1: 使用全局 log 实例 (推荐)
import LoggerKit
log.info("消息")

// 方式 2: 创建自定义 Logger
let customLogger = Logger(context: "Network")
customLogger.info("消息")  // 输出: [Network] 消息
```

### 线程安全吗?

是的,LoggerKit 是线程安全的,可以在多线程环境中安全使用。

## 特性一览

✅ 5 种日志级别 (Verbose, Debug, Info, Warning, Error)
✅ 全局 `log` 实例,开箱即用
✅ 文件日志和控制台日志
✅ 日志轮转和文件管理
✅ 内置日志查看器 UI
✅ UIKit 和 SwiftUI 支持
✅ 线程安全
✅ 高性能

## 相关资源

- [LoggerKit 主仓库](https://github.com/yourusername/LoggerKit)
- [完整文档](https://github.com/yourusername/LoggerKit/blob/main/README.md)
- [问题反馈](https://github.com/yourusername/LoggerKit/issues)

---

**Happy Logging! 🪵**
