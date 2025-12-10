//
//  ViewController.swift
//  LoggerKitExample
//
//  Created by Hemin Won on 2025/11/25.
//

import UIKit
import LoggerKit

class ViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "LoggerKit Example"
        view.backgroundColor = .systemBackground

        setupUI()
        setupLogger()

        // 打印一些初始日志
        printInitialLogs()
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

        // 添加按钮
        addButton(title: "打印 Verbose 日志", action: #selector(logVerbose))
        addButton(title: "打印 Debug 日志", action: #selector(logDebug))
        addButton(title: "打印 Info 日志", action: #selector(logInfo))
        addButton(title: "打印 Warning 日志", action: #selector(logWarning))
        addButton(title: "打印 Error 日志", action: #selector(logError))
        addButton(title: "打印所有级别日志", action: #selector(logAllLevels))

        addSeparator()

        addButton(title: "打印结构化数据", action: #selector(logStructuredData), backgroundColor: .systemBlue)
        addButton(title: "打印网络请求", action: #selector(logNetworkRequest), backgroundColor: .systemBlue)
        addButton(title: "打印用户行为", action: #selector(logUserAction), backgroundColor: .systemBlue)

        addSeparator()

        addButton(title: "查看日志列表 (Push)", action: #selector(showLogList), backgroundColor: .systemGreen)
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

    private func setupLogger() {
        // 配置 LoggerKit (使用 CoreData 存储)
        LoggerKit.configure(
            level: .verbose,
            enableConsole: true,
            enableDatabase: true,
            maxDatabaseSize: 50 * 1024 * 1024,  // 50MB
            maxRetentionDays: 7                  // 保留 7 天
        )
    }

    private func printInitialLogs() {
        log.info("应用启动完成 - LoggerKitExample v1.0.0")
    }

    // MARK: - Log Actions

    @objc private func logVerbose() {
        log.verbose("这是一条 Verbose 级别的日志，用于详细的调试信息")
        showToast("已打印 Verbose 日志")
    }

    @objc private func logDebug() {
        log.debug("这是一条 Debug 级别的日志，用于开发调试")
        showToast("已打印 Debug 日志")
    }

    @objc private func logInfo() {
        log.info("这是一条 Info 级别的日志，用于一般信息记录")
        showToast("已打印 Info 日志")
    }

    @objc private func logWarning() {
        log.warning("这是一条 Warning 级别的日志，用于警告信息")
        showToast("已打印 Warning 日志")
    }

    @objc private func logError() {
        log.error("这是一条 Error 级别的日志，用于错误信息")
        showToast("已打印 Error 日志")
    }

    @objc private func logAllLevels() {
        log.verbose("Verbose: 最详细的日志信息")
        log.debug("Debug: 调试信息")
        log.info("Info: 普通信息")
        log.warning("Warning: 警告信息")
        log.error("Error: 错误信息")
        showToast("已打印所有级别日志")
    }

    @objc private func logStructuredData() {
        log.info("用户登录成功 - 用户ID: 12345, 用户名: 张三, 邮箱: zhangsan@example.com")
        log.debug("用户角色: admin, user")
        log.debug("用户设置: 深色主题, 通知已开启")
        showToast("已打印结构化数据")
    }

    @objc private func logNetworkRequest() {
        log.debug("发起网络请求 -> POST https://api.example.com/users")
        log.debug("请求头: Content-Type=application/json, Authorization=Bearer ***")
        log.debug("请求体: username=testuser")
        log.info("网络请求成功 <- 状态码: 201, 响应时间: 245ms")
        showToast("已打印网络请求日志")
    }

    @objc private func logUserAction() {
        log.info("用户操作: 点击按钮 [查看日志] 在页面 [ViewController]")
        log.debug("会话ID: \(UUID().uuidString)")
        showToast("已打印用户行为日志")
    }

    @objc private func showLogList() {
        // 使用 UIKit 静态方法创建 ViewController
        let logVC = LogDetailScene.makeViewController()
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
}

