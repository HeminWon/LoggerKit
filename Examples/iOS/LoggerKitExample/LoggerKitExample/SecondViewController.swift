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
        log.info("进入第二个页面 - SecondViewController")
        log.debug("当前会话: \(UUID().uuidString)")
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

        log.info("用户浏览商品 - ID: \(productId), 名称: \(productName)")
        log.debug("商品详情 - 价格: ¥\(String(format: "%.2f", price)), 库存: \(Int.random(in: 0...100))")
        log.verbose("页面性能 - 加载时间: \(Int.random(in: 100...500))ms, 图片数量: \(Int.random(in: 1...10))")

        showToast("已记录商品浏览日志")
    }

    @objc private func logCartAction() {
        let actions = ["添加到购物车", "从购物车移除", "修改数量", "清空购物车"]
        let action = actions[Int.random(in: 0...3)]
        let itemCount = Int.random(in: 1...5)

        log.info("购物车操作 - \(action)")
        log.debug("购物车状态 - 商品数量: \(itemCount), 总金额: ¥\(String(format: "%.2f", Double.random(in: 100...5000)))")

        showToast("已记录购物车操作日志")
    }

    @objc private func logOrderAction() {
        let orderId = UUID().uuidString.prefix(8)
        let status = ["待支付", "已支付", "配送中", "已完成", "已取消"][Int.random(in: 0...4)]

        log.info("订单操作 - 订单号: \(orderId)")
        log.debug("订单状态 - \(status), 金额: ¥\(String(format: "%.2f", Double.random(in: 100...10000)))")
        log.verbose("订单详情 - 收货地址: 北京市朝阳区xxx街道, 联系电话: 138****\(Int.random(in: 1000...9999))")

        showToast("已记录订单日志")
    }

    @objc private func logPaymentAction() {
        let paymentMethods = ["支付宝", "微信支付", "Apple Pay", "银行卡"]
        let method = paymentMethods[Int.random(in: 0...3)]
        let amount = Double.random(in: 100...10000)

        log.info("发起支付 - 支付方式: \(method), 金额: ¥\(String(format: "%.2f", amount))")

        // 模拟支付过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let success = Bool.random()
            if success {
                log.info("支付成功 - 交易号: \(UUID().uuidString.prefix(12))")
            } else {
                log.warning("支付失败 - 原因: 余额不足/网络超时")
            }
        }

        showToast("已发起支付请求")
    }

    @objc private func logErrors() {
        log.error("网络请求失败 - 错误码: \(Int.random(in: 400...599))")
        log.error("数据解析异常 - JSON格式不正确")
        log.warning("缓存即将过期 - 剩余时间: \(Int.random(in: 1...60))秒")
        log.error("支付失败 - 银行系统维护中")

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
                "加载商品列表", "更新购物车", "创建订单", "处理支付",
                "获取用户信息", "下载图片", "读取缓存", "发送请求"
            ]

            for i in 1...100 {
                let context = contexts[i % contexts.count]
                let operation = operations[i % operations.count]

                let levelRandom = arc4random_uniform(100)
                if levelRandom < 15 {
                    log.verbose("[\(context)] \(operation) - 详细信息 #\(i)")
                } else if levelRandom < 35 {
                    log.debug("[\(context)] \(operation) - 调试信息 #\(i)")
                } else if levelRandom < 70 {
                    log.info("[\(context)] \(operation) - 常规信息 #\(i)")
                } else if levelRandom < 90 {
                    log.warning("[\(context)] \(operation) - 警告 #\(i)")
                } else {
                    log.error("[\(context)] \(operation) - 错误 #\(i)")
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

        log.info("[主线程] 准备启动多个下载任务")

        // 创建不同的队列模拟不同场景
        let downloadQueue = DispatchQueue(label: "com.example.download", attributes: .concurrent)
        let imageQueue = DispatchQueue(label: "com.example.imageProcessing")
        let dataQueue = DispatchQueue(label: "com.example.dataProcessing")

        // 任务1: 高优先级下载
        DispatchQueue.global(qos: .userInitiated).async {
            log.info("[高优先级线程] 开始下载关键资源")
            Thread.sleep(forTimeInterval: 0.1)
            log.debug("[高优先级线程] 下载进度: 50%")
            Thread.sleep(forTimeInterval: 0.1)
            log.info("[高优先级线程] 下载完成，耗时: 200ms")
        }

        // 任务2: 普通下载任务
        downloadQueue.async {
            log.info("[下载队列] 开始下载图片资源")
            Thread.sleep(forTimeInterval: 0.15)
            log.debug("[下载队列] 图片下载完成: image_001.jpg")
        }

        downloadQueue.async {
            log.info("[下载队列] 开始下载视频资源")
            Thread.sleep(forTimeInterval: 0.2)
            log.debug("[下载队列] 视频下载完成: video_001.mp4")
        }

        // 任务3: 图片处理
        imageQueue.async {
            log.info("[图片处理队列] 开始处理图片")
            Thread.sleep(forTimeInterval: 0.12)
            log.debug("[图片处理队列] 图片压缩完成，大小: 2.3MB -> 450KB")
            Thread.sleep(forTimeInterval: 0.08)
            log.verbose("[图片处理队列] 应用滤镜效果")
            log.info("[图片处理队列] 图片处理完成")
        }

        // 任务4: 数据处理
        dataQueue.async {
            log.info("[数据处理队列] 开始解析数据")
            Thread.sleep(forTimeInterval: 0.1)
            log.debug("[数据处理队列] JSON解析完成，条目数: 128")
            log.verbose("[数据处理队列] 数据验证通过")
            log.info("[数据处理队列] 数据入库完成")
        }

        // 任务5: 低优先级后台任务
        DispatchQueue.global(qos: .background).async {
            log.debug("[后台线程] 开始清理缓存")
            Thread.sleep(forTimeInterval: 0.3)
            log.info("[后台线程] 缓存清理完成，释放空间: 125MB")
        }

        // 回到主线程更新UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            log.info("[主线程] 所有下载任务已完成，准备刷新UI")
        }
    }

    @objc private func simulateBackgroundProcessing() {
        showToast("启动后台数据处理...")

        log.info("[主线程] 触发后台数据同步")

        // 创建自定义队列
        let syncQueue = DispatchQueue(label: "com.example.sync")
        let analyticsQueue = DispatchQueue(label: "com.example.analytics", qos: .utility)

        // 数据同步任务
        syncQueue.async {
            log.info("[同步队列] 开始同步用户数据")

            for i in 1...5 {
                Thread.sleep(forTimeInterval: 0.05)
                log.debug("[同步队列] 同步批次 \(i)/5: 已上传 \(i * 20)条记录")
            }

            log.info("[同步队列] 用户数据同步完成，总计: 100条")

            // 嵌套任务：同步后的验证
            DispatchQueue.global(qos: .default).async {
                log.verbose("[验证线程] 开始验证同步数据完整性")
                Thread.sleep(forTimeInterval: 0.1)
                log.info("[验证线程] 数据验证通过，一致性: 100%")
            }
        }

        // 统计分析任务
        analyticsQueue.async {
            log.info("[分析队列] 开始计算用户行为统计")
            Thread.sleep(forTimeInterval: 0.15)
            log.debug("[分析队列] 活跃用户: 1,234, 新增用户: 89")
            Thread.sleep(forTimeInterval: 0.1)
            log.debug("[分析队列] 平均停留时长: 5分32秒")
            log.info("[分析队列] 统计分析完成，报告已生成")
        }

        // 并发执行多个任务
        DispatchQueue.concurrentPerform(iterations: 3) { index in
            log.debug("[并发线程-\(index)] 处理数据块 #\(index)")
            Thread.sleep(forTimeInterval: 0.08)
            log.verbose("[并发线程-\(index)] 数据块 #\(index) 处理完成")
        }
    }

    @objc private func simulateConcurrentRequests() {
        showToast("发起并发网络请求...")

        log.info("[主线程] 开始批量API请求")

        let requestQueue = DispatchQueue(label: "com.example.network", attributes: .concurrent)
        let group = DispatchGroup()

        // 模拟多个API请求
        let apis = [
            ("用户信息API", "https://api.example.com/user", 0.1),
            ("订单列表API", "https://api.example.com/orders", 0.15),
            ("商品详情API", "https://api.example.com/products", 0.12),
            ("推荐系统API", "https://api.example.com/recommendations", 0.18),
            ("消息通知API", "https://api.example.com/notifications", 0.08)
        ]

        for (name, url, delay) in apis {
            group.enter()
            requestQueue.async {
                log.info("[网络请求线程] 发起请求: \(name)")
                log.debug("[网络请求线程] URL: \(url)")

                Thread.sleep(forTimeInterval: delay)

                let success = Bool.random()
                if success {
                    log.info("[网络请求线程] ✅ \(name) 成功 - 耗时: \(Int(delay * 1000))ms")
                } else {
                    log.warning("[网络请求线程] ⚠️ \(name) 失败 - 状态码: \(Int.random(in: 400...599))")
                }

                group.leave()
            }
        }

        // 等待所有请求完成
        group.notify(queue: .main) {
            log.info("[主线程] 所有API请求已完成")

            // 后续处理
            DispatchQueue.global(qos: .utility).async {
                log.debug("[处理线程] 开始合并响应数据")
                Thread.sleep(forTimeInterval: 0.1)
                log.info("[处理线程] 数据合并完成，缓存已更新")
            }
        }
    }

    @objc private func showLogList() {
        let logVC = LoggerKit.makeViewController()
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
        log.info("离开第二个页面 - SecondViewController")
    }
}
