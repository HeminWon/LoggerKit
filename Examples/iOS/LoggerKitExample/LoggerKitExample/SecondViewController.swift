//
//  SecondViewController.swift
//  LoggerKitExample
//
//  Created by Claude Code on 2025/12/19.
//

import UIKit
import LoggerKit

class SecondViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "第二个页面"
        view.backgroundColor = .systemBackground

        setupUI()

        // 在第二个页面启动时打印日志
        log.info("Enter second page - SecondViewController")
        log.debug("Current session: \(UUID().uuidString)")
    }

    private func setupUI() {
        // 设置 ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // 设置 StackView
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        // 添加标题
        let titleLabel = UILabel()
        titleLabel.text = "这是第二个页面\n用于测试会话筛选功能"
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        stackView.addArrangedSubview(titleLabel)

        addSeparator()

        // 添加按钮
        addButton(title: "记录商品浏览日志", action: #selector(logProductView), backgroundColor: .systemPurple)
        addButton(title: "记录购物车操作日志", action: #selector(logCartAction), backgroundColor: .systemPurple)
        addButton(title: "记录订单日志", action: #selector(logOrderAction), backgroundColor: .systemPurple)
        addButton(title: "记录支付日志", action: #selector(logPaymentAction), backgroundColor: .systemPurple)

        addSeparator()

        addButton(title: "模拟异常日志", action: #selector(logErrors), backgroundColor: .systemRed)
        addButton(title: "生成批量日志 (100条)", action: #selector(generateBatchLogs), backgroundColor: .systemOrange)

        addSeparator()

        // 多线程场景
        addButton(title: "多线程并发下载", action: #selector(simulateMultithreadedDownload), backgroundColor: .systemTeal)
        addButton(title: "后台数据处理", action: #selector(simulateBackgroundProcessing), backgroundColor: .systemTeal)
        addButton(title: "并发网络请求", action: #selector(simulateConcurrentRequests), backgroundColor: .systemTeal)

        addSeparator()

        addButton(title: "查看日志列表", action: #selector(showLogList), backgroundColor: .systemGreen)
    }

    private func addButton(title: String, action: Selector, backgroundColor: UIColor = .systemIndigo) {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = backgroundColor
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: action, for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stackView.addArrangedSubview(button)
    }

    private func addSeparator() {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separator)
    }

    // MARK: - Log Actions

    @objc private func logProductView() {
        let productId = Int.random(in: 1000...9999)
        let productName = ["iPhone 15 Pro", "MacBook Pro", "AirPods Pro", "iPad Air", "Apple Watch"][Int.random(in: 0...4)]
        let price = Double.random(in: 999...19999)

        log.info("User viewed product - ID: \(productId), Name: \(productName)")
        log.debug("Product details - Price: ¥\(String(format: "%.2f", price)), Stock: \(Int.random(in: 0...100))")
        log.verbose("Page performance - Load time: \(Int.random(in: 100...500))ms, Image count: \(Int.random(in: 1...10))")

        showToast("已记录商品浏览日志")
    }

    @objc private func logCartAction() {
        let actions = ["Add to cart", "Remove from cart", "Change quantity", "Clear cart"]
        let action = actions[Int.random(in: 0...3)]
        let itemCount = Int.random(in: 1...5)

        log.info("Cart action - \(action)")
        log.debug("Cart status - Item count: \(itemCount), Total amount: ¥\(String(format: "%.2f", Double.random(in: 100...5000)))")

        showToast("已记录购物车操作日志")
    }

    @objc private func logOrderAction() {
        let orderId = UUID().uuidString.prefix(8)
        let status = ["Pending payment", "Paid", "Shipping", "Completed", "Cancelled"][Int.random(in: 0...4)]

        log.info("Order action - Order ID: \(orderId)")
        log.debug("Order status - \(status), Amount: ¥\(String(format: "%.2f", Double.random(in: 100...10000)))")
        log.verbose("Order details - Shipping address: No. 1 Example Street, Chaoyang District, Beijing, Phone: 138****\(Int.random(in: 1000...9999))")

        showToast("已记录订单日志")
    }

    @objc private func logPaymentAction() {
        let paymentMethods = ["Alipay", "WeChat Pay", "Apple Pay", "Bank Card"]
        let method = paymentMethods[Int.random(in: 0...3)]
        let amount = Double.random(in: 100...10000)

        log.info("Initiate payment - Method: \(method), Amount: ¥\(String(format: "%.2f", amount))")

        // 模拟支付过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let success = Bool.random()
            if success {
                log.info("Payment succeeded - Transaction ID: \(UUID().uuidString.prefix(12))")
            } else {
                log.warning("Payment failed - Reason: insufficient balance/network timeout")
            }
        }

        showToast("已发起支付请求")
    }

    @objc private func logErrors() {
        log.error("Network request failed - Error code: \(Int.random(in: 400...599))")
        log.error("Data parsing exception - Invalid JSON format")
        log.warning("Cache about to expire - Remaining time: \(Int.random(in: 1...60))s")
        log.error("Payment failed - Bank system under maintenance")

        showToast("已记录4条异常日志")
    }

    @objc private func generateBatchLogs() {
        showToast("开始生成100条测试日志...")

        DispatchQueue.global(qos: .background).async { [weak self] in
            let contexts = [
                "ProductService", "CartManager", "OrderManager", "PaymentService",
                "UserProfile", "ImageLoader", "CacheManager", "NetworkClient"
            ]

            let operations = [
                "Load product list", "Update cart", "Create order", "Process payment",
                "Fetch user profile", "Download image", "Read cache", "Send request"
            ]

            for i in 1...100 {
                let context = contexts[i % contexts.count]
                let operation = operations[i % operations.count]

                let levelRandom = arc4random_uniform(100)
                if levelRandom < 15 {
                    log.verbose("[\(context)] \(operation) - Detailed info #\(i)")
                } else if levelRandom < 35 {
                    log.debug("[\(context)] \(operation) - Debug info #\(i)")
                } else if levelRandom < 70 {
                    log.info("[\(context)] \(operation) - General info #\(i)")
                } else if levelRandom < 90 {
                    log.warning("[\(context)] \(operation) - Warning #\(i)")
                } else {
                    log.error("[\(context)] \(operation) - Error #\(i)")
                }

                if i % 25 == 0 {
                    Thread.sleep(forTimeInterval: 0.02)
                }
            }

            DispatchQueue.main.async {
                self?.showToast("✅ 已生成100条测试日志")
            }
        }
    }

    // MARK: - Multithreading Scenarios

    @objc private func simulateMultithreadedDownload() {
        showToast("开始多线程下载任务...")

        log.info("[Main thread] Preparing to start multiple download tasks")

        // 创建不同的队列模拟不同场景
        let downloadQueue = DispatchQueue(label: "com.example.download", attributes: .concurrent)
        let imageQueue = DispatchQueue(label: "com.example.imageProcessing")
        let dataQueue = DispatchQueue(label: "com.example.dataProcessing")

        // 任务1: 高优先级下载
        DispatchQueue.global(qos: .userInitiated).async {
            log.info("[High-priority thread] Start downloading critical resources")
            Thread.sleep(forTimeInterval: 0.1)
            log.debug("[High-priority thread] Download progress: 50%")
            Thread.sleep(forTimeInterval: 0.1)
            log.info("[High-priority thread] Download completed, duration: 200ms")
        }

        // 任务2: 普通下载任务
        downloadQueue.async {
            log.info("[Download queue] Start downloading image resources")
            Thread.sleep(forTimeInterval: 0.15)
            log.debug("[Download queue] Image download completed: image_001.jpg")
        }

        downloadQueue.async {
            log.info("[Download queue] Start downloading video resources")
            Thread.sleep(forTimeInterval: 0.2)
            log.debug("[Download queue] Video download completed: video_001.mp4")
        }

        // 任务3: 图片处理
        imageQueue.async {
            log.info("[Image processing queue] Start processing images")
            Thread.sleep(forTimeInterval: 0.12)
            log.debug("[Image processing queue] Image compression completed, size: 2.3MB -> 450KB")
            Thread.sleep(forTimeInterval: 0.08)
            log.verbose("[Image processing queue] Applying filter effects")
            log.info("[Image processing queue] Image processing completed")
        }

        // 任务4: 数据处理
        dataQueue.async {
            log.info("[Data processing queue] Start parsing data")
            Thread.sleep(forTimeInterval: 0.1)
            log.debug("[Data processing queue] JSON parsing completed, record count: 128")
            log.verbose("[Data processing queue] Data validation passed")
            log.info("[Data processing queue] Data persisted to storage")
        }

        // 任务5: 低优先级后台任务
        DispatchQueue.global(qos: .background).async {
            log.debug("[Background thread] Start clearing cache")
            Thread.sleep(forTimeInterval: 0.3)
            log.info("[Background thread] Cache cleanup completed, freed space: 125MB")
        }

        // 回到主线程更新UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            log.info("[Main thread] All download tasks completed, preparing to refresh UI")
        }
    }

    @objc private func simulateBackgroundProcessing() {
        showToast("启动后台数据处理...")

        log.info("[Main thread] Trigger background data sync")

        // 创建自定义队列
        let syncQueue = DispatchQueue(label: "com.example.sync")
        let analyticsQueue = DispatchQueue(label: "com.example.analytics", qos: .utility)

        // 数据同步任务
        syncQueue.async {
            log.info("[Sync queue] Start syncing user data")

            for i in 1...5 {
                Thread.sleep(forTimeInterval: 0.05)
                log.debug("[Sync queue] Sync batch \(i)/5: uploaded \(i * 20) records")
            }

            log.info("[Sync queue] User data sync completed, total: 100 records")

            // 嵌套任务：同步后的验证
            DispatchQueue.global(qos: .default).async {
                log.verbose("[Validation thread] Start validating synced data integrity")
                Thread.sleep(forTimeInterval: 0.1)
                log.info("[Validation thread] Data validation passed, consistency: 100%")
            }
        }

        // 统计分析任务
        analyticsQueue.async {
            log.info("[Analytics queue] Start calculating user behavior metrics")
            Thread.sleep(forTimeInterval: 0.15)
            log.debug("[Analytics queue] Active users: 1,234, New users: 89")
            Thread.sleep(forTimeInterval: 0.1)
            log.debug("[Analytics queue] Average session duration: 5m32s")
            log.info("[Analytics queue] Analytics completed, report generated")
        }

        // 并发执行多个任务
        DispatchQueue.concurrentPerform(iterations: 3) { index in
            log.debug("[Concurrent thread-\(index)] Processing data chunk #\(index)")
            Thread.sleep(forTimeInterval: 0.08)
            log.verbose("[Concurrent thread-\(index)] Data chunk #\(index) processed")
        }
    }

    @objc private func simulateConcurrentRequests() {
        showToast("发起并发网络请求...")

        log.info("[Main thread] Start batch API requests")

        let requestQueue = DispatchQueue(label: "com.example.network", attributes: .concurrent)
        let group = DispatchGroup()

        // 模拟多个API请求
        let apis = [
            ("User Profile API", "https://api.example.com/user", 0.1),
            ("Order List API", "https://api.example.com/orders", 0.15),
            ("Product Detail API", "https://api.example.com/products", 0.12),
            ("Recommendation API", "https://api.example.com/recommendations", 0.18),
            ("Notification API", "https://api.example.com/notifications", 0.08)
        ]

        for (name, url, delay) in apis {
            group.enter()
            requestQueue.async {
                log.info("[Network request thread] Send request: \(name)")
                log.debug("[Network request thread] URL: \(url)")

                Thread.sleep(forTimeInterval: delay)

                let success = Bool.random()
                if success {
                    log.info("[Network request thread] ✅ \(name) succeeded - duration: \(Int(delay * 1000))ms")
                } else {
                    log.warning("[Network request thread] ⚠️ \(name) failed - status code: \(Int.random(in: 400...599))")
                }

                group.leave()
            }
        }

        // 等待所有请求完成
        group.notify(queue: .main) {
            log.info("[Main thread] All API requests completed")

            // 后续处理
            DispatchQueue.global(qos: .utility).async {
                log.debug("[Processing thread] Start merging response data")
                Thread.sleep(forTimeInterval: 0.1)
                log.info("[Processing thread] Data merge completed, cache updated")
            }
        }
    }

    @objc private func showLogList() {
        let logVC = LK.makeViewController()
        navigationController?.pushViewController(logVC, animated: true)
    }

    // MARK: - Helper

    private func showToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }

    deinit {
        log.info("Leave second page - SecondViewController")
    }
}
