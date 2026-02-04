# LoggerKit

[![CI](https://github.com/HeminWon/LoggerKit/actions/workflows/swift.yml/badge.svg)](https://github.com/HeminWon/LoggerKit/actions/workflows/swift.yml)
[![CocoaPods](https://img.shields.io/cocoapods/v/HMLoggerKit.svg)](https://cocoapods.org/pods/HMLoggerKit)
[![Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FHeminWon%2FLoggerKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/HeminWon/LoggerKit)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FHeminWon%2FLoggerKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/HeminWon/LoggerKit)

High-performance logging framework for Apple platforms built on SwiftyBeaver. Lightweight `Logger` instances share a single engine, with CoreData-backed persistence and a built-in SwiftUI log viewer.

## Features

- iOS 15+, macOS 12+, watchOS 8+, tvOS 15+
- CoreData-backed log storage with size and retention rotation
- Console logging
- Async batched writes with debounce and immediate flush for critical levels
- Context auto-extraction (module name) or custom context
- SwiftUI Environment integration
- Built-in log viewer UI with filtering and export

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/HeminWon/LoggerKit.git", from: "0.2.2")
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: ["LoggerKit"]
)
```

### CocoaPods

```ruby
pod 'HMLoggerKit', '~> 0.2.2'
```

## Quick Start

Configure the engine as early as possible during app launch.

### SwiftUI

```swift
import SwiftUI
import LoggerKit

@main
struct MyApp: App {
    init() {
        LoggerKit.configure(
            level: .debug,
            enableConsole: true,
            enableDatabase: true
        )
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### UIKit

```swift
import UIKit
import LoggerKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        LoggerKit.configure(level: .debug, enableConsole: true, enableDatabase: true)
        return true
    }
}
```

Create and use a logger:

```swift
import LoggerKit

let logger = Logger()
logger.debug("Debug message")
logger.info("Info message")
logger.error("Error message")
```

## Advanced Configuration

```swift
LoggerEngine.configure(
    LoggerEngineConfiguration(
        level: .info,
        enableConsole: true,
        enableDatabase: true,
        maxDatabaseSize: 100 * 1024 * 1024,
        maxRetentionDays: 30,
        batchSize: 50,
        debounceInterval: 2.0,
        immediateFlushLevels: [.error, .warning]
    )
)
```

## SwiftUI Environment

```swift
import SwiftUI
@_exported import LoggerKit

public let log = Logger()

struct MyView: View {
    @Environment(\.logger) var logger

    var body: some View {
        Button("Log") { logger.info("Button tapped") }
    }
}
```

## Log Viewer UI

```swift
import LoggerKit
import SwiftUI

struct LogsView: View {
    var body: some View {
        LoggerKit.makeViewWithViewStore()
    }
}
```

## Maintenance

```swift
Logger.performDatabaseRotation()
Logger.cleanupExpiredLogs()
Logger.flush()
```

## Testing

A `MockLogger` is provided in `Sources/LoggerKit/Testing` for unit tests.

## Example App

See `Examples/iOS/LoggerKitExample` for a full demo.

## License

MIT
