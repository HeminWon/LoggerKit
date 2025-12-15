//
//  LoadingState.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/12/15.
//

import Foundation

/// 数据加载状态
public enum LoadingState: Equatable {
    /// 空闲状态
    case idle
    /// 加载中(可选进度信息)
    case loading(progress: String?)
    /// 加载更多
    case loadingMore
    /// 加载完成
    case loaded
    /// 加载失败
    case failed(Error)

    public static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading(let lProgress), .loading(let rProgress)):
            return lProgress == rProgress
        case (.loadingMore, .loadingMore):
            return true
        case (.loaded, .loaded):
            return true
        case (.failed(let lError), .failed(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        default:
            return false
        }
    }
}
