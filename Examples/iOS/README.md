# LoggerKit iOS Example App

This is the official iOS example app for LoggerKit. It demonstrates logger initialization, writing logs, and integrating the built-in log viewer in a UIKit project.

## Feature Overview

- Initialize once during app startup with `LK.configure(...)`
- Write multi-level logs using `Logger()` (verbose/debug/info/warning/error)
- Integrate log viewer in UIKit using `LK.makeViewController()`
- Search, filter, and export logs

## Run the Example

```bash
git clone https://github.com/HeminWon/LoggerKit.git
cd LoggerKit
open Examples/iOS/LoggerKitExample/LoggerKitExample.xcodeproj
```

In Xcode, select a target device and run (`⌘R`).

## Requirements

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

## Minimal Integration

### 1. Configure at Startup

```swift
import LoggerKit

LK.configure(
    level: .debug,
    enableConsole: true,
    enableDatabase: true
)
```

### 2. Write Logs

```swift
import LoggerKit

let logger = Logger(context: "Home")
logger.verbose("Verbose message")
logger.debug("Debug message")
logger.info("Info message")
logger.warning("Warning message")
logger.error("Error message")
```

### 3. Open the Log Viewer (UIKit)

```swift
import UIKit
import LoggerKit

final class HomeViewController: UIViewController {
    @objc private func showLogs() {
        let logVC = LK.makeViewController()
        navigationController?.pushViewController(logVC, animated: true)
    }
}
```

## FAQ

### Why are logs not printed in the console?

Check the following:

- `LK.configure(...)` has been called
- `enableConsole` is `true`
- The configured log level includes the current log

### Why is there no data in the log viewer?

Make sure `enableDatabase` is `true`, and write logs before opening the log viewer.

### Can I use a custom context?

Yes. `Logger(context: "Network")` writes logs with that custom context.
