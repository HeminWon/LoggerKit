# SwiftUI List 滑动性能排查指南

## 🎯 目标
优化 LogDetailScene.swift 中大量数据滑动时的性能

## 📊 性能分析方法

### 1️⃣ 使用 Instruments Time Profiler

**步骤:**

```bash
# 1. 在 Xcode 中打开项目
# 2. Product > Profile (⌘I)
# 3. 选择 "Time Profiler"
# 4. 启动应用并进入日志列表
# 5. 快速滑动列表,持续 5-10 秒
# 6. 停止录制,分析调用栈
```

**关键指标:**
- 寻找 `LogRowView.body` 的调用次数和耗时
- 查看 `sessionColor(for:)` 哈希计算的开销
- 检查 `.contextMenu` 的创建频率

---

### 2️⃣ 使用 SwiftUI 自带性能调试

**添加性能监控代码:**

```swift
// 在 LogDetailScene.swift 顶部添加
import os.signpost

extension OSLog {
    static let performance = OSLog(subsystem: "com.loggerkit", category: "Performance")
}

// 在 LogRowView.body 中添加
var body: some View {
    os_signpost(.begin, log: .performance, name: "LogRowView render")
    defer { os_signpost(.end, log: .performance, name: "LogRowView render") }

    // 原有代码...
}
```

**使用 Instruments 查看 Signpost:**
1. Product > Profile (⌘I)
2. 选择 "os_signpost"
3. 滑动列表,观察 render 频率

---

### 3️⃣ 帧率监控

**方案 A: Xcode Debug Options**
```
Debug > View Debugging > Rendering
✓ Color Blended Layers (检查图层混合)
✓ Color Offscreen-Rendered (检查离屏渲染)
```

**方案 B: 添加 FPS 计数器**

创建 `PerformanceMonitor.swift`:

```swift
import SwiftUI
import Combine

class FPSCounter: ObservableObject {
    @Published var fps: Int = 0

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount = 0

    func start() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
    }

    @objc private func update(link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }

        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp

        if elapsed >= 1.0 {
            fps = frameCount
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }
}

struct FPSOverlay: View {
    @StateObject private var counter = FPSCounter()

    var body: some View {
        Text("FPS: \(counter.fps)")
            .font(.caption)
            .padding(8)
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(8)
            .onAppear { counter.start() }
            .onDisappear { counter.stop() }
    }
}
```

**在 LogDetailScene.swift 中使用:**

```swift
var body: some View {
    ZStack {
        VStack {
            // 原有代码...
        }

        #if DEBUG
        VStack {
            Spacer()
            HStack {
                Spacer()
                FPSOverlay()
                    .padding()
            }
        }
        #endif
    }
}
```

---

## 🔧 已发现的性能问题

### 问题 1: ForEach 创建临时数组

**当前代码 (LogDetailScene.swift:89):**
```swift
ForEach(Array(zip(sceneState.displayEvents.indices, sceneState.displayEvents)), id: \.1.id) { index, logEvent in
    LogRowView(event: logEvent, index: index + 1)
}
```

**问题分析:**
- `Array(zip(...))` 每次渲染都创建新数组
- 对于 10,000 条日志,这意味着每次滑动都创建 10,000 个元组

**优化方案:**

```swift
// 方案 A: 直接使用 ForEach.indices
ForEach(sceneState.displayEvents.indices, id: \.self) { index in
    LogRowView(
        event: sceneState.displayEvents[index],
        index: index + 1
    )
    .onAppear {
        if index == sceneState.displayEvents.count - 1 {
            Task { await sceneState.loadMore() }
        }
    }
}

// 方案 B: 预计算 indexed events
@Published var indexedEvents: [(index: Int, event: LogEvent)] = []

// 在 displayEvents didSet 中更新
@Published var displayEvents: [LogEvent] = [] {
    didSet {
        indexedEvents = displayEvents.enumerated().map { (index: $0, event: $1) }
    }
}

// 然后在 View 中使用
ForEach(sceneState.indexedEvents, id: \.event.id) { item in
    LogRowView(event: item.event, index: item.index + 1)
}
```

---

### 问题 2: LogRowView 重复计算

**当前代码 (LogDetailScene.swift:234-250):**
```swift
var body: some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(event.sessionId)
            .foregroundColor(cachedSessionColor)
            .font(.system(size: 9))
        + Text(" #\(index)")
            .foregroundColor(.secondary)
            .font(.system(size: 9))
        + Text(" ")
            .font(.system(size: 9))
        + Text(event.prefix)
            .foregroundColor(.gray)
            .font(.system(size: 9))

        Text(event.message)
            .foregroundColor(event.level.color)
            .font(.caption2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

**问题分析:**
- Text 连接符 `+` 每次 body 执行都重新计算
- 4 次字体设置重复代码
- `.contextMenu` 闭包对每个 cell 都创建

**优化方案:**

```swift
// 方案 A: 预计算 AttributedString (iOS 15+)
private var headerText: AttributedString {
    var text = AttributedString(event.sessionId)
    text.foregroundColor = cachedSessionColor
    text.font = .system(size: 9)

    var indexText = AttributedString(" #\(index)")
    indexText.foregroundColor = .secondary
    indexText.font = .system(size: 9)

    var prefixText = AttributedString(" \(event.prefix)")
    prefixText.foregroundColor = .gray
    prefixText.font = .system(size: 9)

    return text + indexText + prefixText
}

var body: some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(headerText)

        Text(event.message)
            .foregroundColor(event.level.color)
            .font(.caption2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .contextMenu { menuContent }
}

@ViewBuilder
private var menuContent: some View {
    Button(action: copyLog) {
        Label(String(localized: "copy_log", bundle: .module), systemImage: "doc.on.doc")
    }
}

// 方案 B: 使用 HStack 替代 Text 连接
var body: some View {
    VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 0) {
            Text(event.sessionId)
                .foregroundColor(cachedSessionColor)
            Text(" #\(index)")
                .foregroundColor(.secondary)
            Text(" \(event.prefix)")
                .foregroundColor(.gray)
        }
        .font(.system(size: 9))

        Text(event.message)
            .foregroundColor(event.level.color)
            .font(.caption2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .contextMenu { menuContent }
}
```

---

### 问题 3: sessionColor 哈希计算

**当前代码 (LogDetailScene.swift:262-281):**
```swift
private static func sessionColor(for sessionId: String) -> Color {
    let hash = sessionId.utf8.reduce(0) {
        ($0 &* 31 &+ Int($1)) & 0xFFFFFFFF
    }
    // ... 复杂的颜色计算
}
```

**问题分析:**
- 虽然在 init 中缓存,但仍需遍历 UTF8 字符计算哈希
- 对于重复出现的 sessionId,浪费计算

**优化方案:**

```swift
// 添加全局颜色缓存
private static var sessionColorCache: [String: Color] = [:]
private static let cacheQueue = DispatchQueue(label: "sessionColorCache")

private static func sessionColor(for sessionId: String) -> Color {
    // 先检查缓存
    if let cached = cacheQueue.sync(execute: { sessionColorCache[sessionId] }) {
        return cached
    }

    // 计算新颜色
    let hash = sessionId.hashValue  // 使用系统 hashValue 更快
    let hue = Double(abs(hash) % 360) / 360.0
    let saturation = 0.40 + Double((abs(hash) >> 8) % 21) / 100.0
    let brightness = 0.50 + Double((abs(hash) >> 16) % 21) / 100.0

    let color = Color(hue: hue, saturation: saturation, brightness: brightness, opacity: 1.0)

    // 缓存结果
    cacheQueue.sync {
        sessionColorCache[sessionId] = color
    }

    return color
}
```

---

### 问题 4: onAppear 触发加载更多

**当前代码 (LogDetailScene.swift:94-101):**
```swift
.onAppear {
    if logEvent.id == sceneState.displayEvents.last?.id {
        Task { await sceneState.loadMore() }
    }
}
```

**问题分析:**
- 每个 row 都有 onAppear 闭包
- 每次都比较 `logEvent.id == sceneState.displayEvents.last?.id`

**优化方案:**

```swift
// 方案 A: 使用索引比较
.onAppear {
    if index == sceneState.displayEvents.count - 1 {
        Task { await sceneState.loadMore() }
    }
}

// 方案 B: 提前计算阈值
// 在 LogDetailSceneState 中添加
private var loadMoreThreshold: Int {
    max(0, displayEvents.count - 10)  // 距离底部 10 条时加载
}

// 在 View 中使用
.onAppear {
    if index >= sceneState.loadMoreThreshold {
        Task { await sceneState.loadMore() }
    }
}
```

---

## 📈 性能测试脚本

创建 `PerformanceTests/ScrollPerformanceTests.swift`:

```swift
import XCTest
@testable import LoggerKit

final class ScrollPerformanceTests: XCTestCase {

    func testLogRowViewRenderPerformance() {
        let event = LogEvent(
            id: UUID(),
            level: .info,
            message: "Test message",
            sessionId: "test-session",
            prefix: "[2025-12-11 10:00:00]",
            fileName: "Test.swift",
            function: "testFunction()",
            line: 42,
            context: "TestContext",
            thread: "main"
        )

        measure {
            _ = LogRowView(event: event, index: 1)
        }
    }

    func testSessionColorPerformance() {
        let sessionIds = (0..<1000).map { "session-\($0)" }

        measure {
            for sessionId in sessionIds {
                _ = LogRowView.sessionColor(for: sessionId)
            }
        }
    }
}
```

---

## 🎬 优化优先级

### 🔴 高优先级 (立即修复)
1. **移除 Array(zip())** - 最简单,收益最大
2. **优化 Text 连接** - 使用 HStack 或 AttributedString
3. **sessionColor 全局缓存** - 避免重复计算

### 🟡 中优先级 (性能提升明显)
4. **优化 onAppear 判断** - 使用索引而非 ID 比较
5. **提取 contextMenu** - 避免每次创建闭包

### 🟢 低优先级 (可选)
6. **LazyVStack 替代 List** - 如果 List 性能仍不理想
7. **虚拟化优化** - 自定义滚动容器

---

## 🧪 性能验证清单

- [ ] 使用 Instruments 记录优化前后的 CPU 使用率
- [ ] 对比优化前后的滑动帧率 (目标 60 FPS)
- [ ] 测试 10,000 条日志的滑动流畅度
- [ ] 检查内存使用是否增加 (缓存带来的副作用)
- [ ] 验证功能完整性 (分页加载、过滤、复制等)

---

## 📚 参考资料

- [SwiftUI Performance Tips - WWDC 2021](https://developer.apple.com/videos/play/wwdc2021/10252/)
- [Instruments Time Profiler Guide](https://developer.apple.com/documentation/xcode/improving-your-apps-performance)
- [SwiftUI Layout Performance](https://www.swiftbysundell.com/articles/swiftui-layout-system-guide-part-1/)
