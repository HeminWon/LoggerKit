# HMLoggerKit CocoaPods 发布指南（维护者）

本文档用于维护者执行 `HMLoggerKit` 的标准发布流程。

## 1. 适用范围

- 仓库：`https://github.com/HeminWon/LoggerKit`
- Pod：`HMLoggerKit`
- Podspec 文件：`HMLoggerKit.podspec`
- 发布通道：CocoaPods Trunk

## 2. 发布前检查

发布前请确认：

- 当前分支为待发布分支（通常是 `main`）
- 工作区无未提交变更（建议）
- `HMLoggerKit.podspec` 中字段正确：
  - `s.name`
  - `s.version`
  - `s.source`（tag 与 version 一致）
  - `s.swift_version`
  - `s.platforms`
- 本地工具可用：`pod`、`git`

建议先执行一次本地 lint：

```bash
sh Scripts/pod-lib-lint.sh
```

## 3. 首次发布前的一次性配置

如果是首次在当前机器发布：

1. 注册 trunk 账号（邮箱需可用）

```bash
pod trunk register heminwon@gmail.com "HeminWon"
```

2. 打开邮箱确认链接
3. 验证会话

```bash
pod trunk me
```

## 4. 标准发布步骤

以下示例以版本 `0.2.3` 为例。

1. 更新 podspec 版本

修改 `HMLoggerKit.podspec`：

```ruby
s.version = "0.2.3"
```

2. 再次执行 lint

```bash
sh Scripts/pod-lib-lint.sh
```

3. 提交代码并打 tag（tag 必须与版本号完全一致）

```bash
git add HMLoggerKit.podspec
git commit -m "release: 0.2.3"
git tag 0.2.3
git push origin main --tags
```

4. 推送到 CocoaPods

```bash
pod trunk push HMLoggerKit.podspec --allow-warnings
```

5. 验证发布结果

```bash
pod trunk info HMLoggerKit
```

或在网页确认新版本：

- `https://cocoapods.org/pods/HMLoggerKit`

## 5. 常见问题

### 5.1 `No podspec exists at path ...`

原因：脚本或命令引用了错误的 podspec 文件名。

处理：确保使用 `HMLoggerKit.podspec`，并从仓库根目录执行命令。

### 5.2 `Unable to find a specification for ...` / 依赖解析失败

原因：spec repo 未更新或网络异常。

处理：

```bash
pod repo update
```

然后重新执行 lint / push。

### 5.3 `The version should be incremented`

原因：要发布的 `s.version` 已存在。

处理：递增版本号，重新打新 tag 并发布。

### 5.4 tag 与 podspec 版本不一致

原因：`s.source[:tag]` 解析到的 tag 与 `s.version` 不匹配。

处理：保证 `s.version`、git tag、推送的 tag 三者一致。

## 6. 回滚与修复策略

CocoaPods Trunk 不建议删除已发布版本。推荐策略：

- 保留错误版本
- 尽快发布修复版本（例如 `0.2.3` -> `0.2.4`）
- 在 Release Notes 说明问题和修复点

如果必须处理严重问题，请先评估依赖方影响，再谨慎使用 trunk 的删除/废弃能力。

## 7. 建议的发布检查清单

每次发布可按以下顺序打勾：

- [ ] 更新 `HMLoggerKit.podspec` 版本号
- [ ] 本地 `pod lib lint` 通过
- [ ] 提交版本变更
- [ ] 创建并推送同名 tag
- [ ] `pod trunk push` 成功
- [ ] `pod trunk info` 和 cocoapods.org 页面可见新版本

