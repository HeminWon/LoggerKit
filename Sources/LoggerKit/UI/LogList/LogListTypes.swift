//
//  LogListTypes.swift
//  LoggerKit
//
//  Created by Claude Code
//  Copyright © 2025 LoggerKit. All rights reserved.
//

import Foundation

// MARK: - LogList Error

/// LogList-related errors
public enum LogListError: Error, LocalizedError, Equatable {
    case loadFailed(String)
    case emptyResult
    case invalidSequenceNumber

    public var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return String(localized: "list_load_failed", bundle: .loggerKit).replacingOccurrences(of: "%@", with: message)
        case .emptyResult:
            return String(localized: "list_no_logs_found", bundle: .loggerKit)
        case .invalidSequenceNumber:
            return String(localized: "list_invalid_sequence", bundle: .loggerKit)
        }
    }
}

// MARK: - Design Note
//
// LoadingState 设计说明：
// 文档最初建议在此定义简化版 LoadingState (无 progress 参数)，
// 但为避免与全局 LoadingState 命名冲突和类型混淆，
// 当前设计选择复用全局的 LoadingState 类型。
//
// 这是一个合理的权衡：
// - ✅ 避免类型重复和命名空间污染
// - ✅ 保持代码库一致性
// - ✅ 功能完全正常（progress 参数传 nil 即可）
// - ⚠️ 未来如需独立演进，可考虑使用命名空间：LogList.LoadingState
