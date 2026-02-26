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
        log.debug("unused")
        setupUI()

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

        addButton(title: "进入第二个页面 (测试会话)", action: #selector(pushToSecondPage), backgroundColor: .systemPurple)
        addButton(title: "生成200条测试日志", action: #selector(generate200Logs), backgroundColor: .systemOrange)
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

    private func printInitialLogs() {
        log.info("App launch completed - LoggerKitExample v1.0.0")
    }

    // MARK: - Log Actions

    @objc private func logVerbose() {
        log.verbose("This is a Verbose level log for detailed debugging information")
        showToast("已打印 Verbose 日志")
    }

    @objc private func logDebug() {
        log.debug("This is a Debug level log for development debugging")
        showToast("已打印 Debug 日志")
    }

    @objc private func logInfo() {
        log.info("This is an Info level log for general information")
        showToast("已打印 Info 日志")
    }

    @objc private func logWarning() {
        log.warning("This is a Warning level log for warning information")
        showToast("已打印 Warning 日志")
    }

    @objc private func logError() {
        log.error("This is an Error level log for error information")
        showToast("已打印 Error 日志")
    }

    @objc private func logAllLevels() {
        log.verbose("Verbose: Most detailed log information")
        log.debug("Debug: Debug information")
        log.info("Info: General information")
        log.warning("Warning: Warning information")
        log.error("Error: Error information")
        showToast("已打印所有级别日志")
    }

    @objc private func logStructuredData() {
        log.info("User login succeeded - User ID: 12345, Username: Zhang San, Email: zhangsan@example.com")
        log.debug("User roles: admin, user")
        log.debug("User settings: dark theme, notifications enabled")
        showToast("已打印结构化数据")
    }

    @objc private func logNetworkRequest() {
        log.debug("Send network request -> POST https://api.example.com/users")
        log.debug("Request headers: Content-Type=application/json, Authorization=Bearer ***")
        log.debug("Request body: username=testuser")
        log.info("Network request succeeded <- Status code: 201, Response time: 245ms")
        showToast("已打印网络请求日志")
    }

    @objc private func logUserAction() {
        log.info("User action: tapped button [View Logs] on page [ViewController]")
        log.debug("Session ID: \(UUID().uuidString)")
        showToast("已打印用户行为日志")
    }

    @objc private func generate200Logs() {
        showToast("开始生成200条测试日志...")

        DispatchQueue.global(qos: .background).async { [weak self] in
            for i in 1...5000 {
                // 变化的函数名
                let functions = [
                    "viewDidLoad()", "buttonTapped()", "dataFetched()", "userLogin()",
                    "networkRequest()", "handleResponse()", "saveToDatabase()", "validateInput()",
                    "refreshUI()", "loadCache()"
                ]

                // 变化的上下文
                let contexts = [
                    "ViewController", "NetworkManager", "DataManager", "AuthService",
                    "APIClient", "CacheService", "ValidationEngine", "DatabaseHelper",
                    "UIUpdater", "SessionManager"
                ]

                // 变化的动作
                let actions = [
                    "Start", "Tap", "Request", "Response", "Process", "Complete",
                    "Fail", "Retry", "Validate", "Update", "Save", "Load"
                ]

                // 变化的详细信息
                let details = [
                    "User ID: \(1000 + i)",
                    "Duration: \(arc4random_uniform(500))ms",
                    "Status code: \(200 + Int(arc4random_uniform(5)) * 100)",
                    "Payload size: \(arc4random_uniform(1000))KB",
                    "Retry count: \(arc4random_uniform(4))",
                    "Thread: Thread-\(arc4random_uniform(10))"
                ]

                let function = functions[i % functions.count]
                let context = contexts[i % contexts.count]
                let action = actions[i % actions.count]
                let detail = details[i % details.count]

                // 按不同比例分配日志级别 (info最多, error最少)
                let levelRandom = arc4random_uniform(100)
                if levelRandom < 10 {
                    // 10% Verbose
                    log.verbose("[\(context)] \(action) - Detailed info #\(i) | \(detail) | \(function)")
                } else if levelRandom < 30 {
                    // 20% Debug
                    log.debug("[\(context)] \(action) - Debug info #\(i) | \(detail) | \(function)")
                } else if levelRandom < 70 {
                    // 40% Info
                    log.info("[\(context)] \(action) - General info #\(i) | \(detail) | \(function)")
                } else if levelRandom < 90 {
                    // 20% Warning
                    log.warning("[\(context)] \(action) - Warning info #\(i) | \(detail) | \(function)")
                } else {
                    // 10% Error
                    log.error("[\(context)] \(action) - Error info #\(i) | \(detail) | \(function)")
                }

                // 每50条日志暂停一下,避免过快
                if i % 50 == 0 {
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }

            DispatchQueue.main.async {
                self?.showToast("✅ 已生成200条测试日志")
            }
        }
    }

    @objc private func pushToSecondPage() {
        let secondVC = SecondViewController()
        navigationController?.pushViewController(secondVC, animated: true)
    }

    @objc private func showLogList() {
        // 使用 UIKit 静态方法创建 ViewController
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
}
