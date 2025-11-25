//
//  LogListScene.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/9/10.
//

import SwiftUI

public struct LogListScene: View {
    
    @ObservedObject public var sceneState: LogListSceneState
    
    public init(sceneState: LogListSceneState? = nil) {
        if let sceneState = sceneState {
            self.sceneState = sceneState
        } else {
            self.sceneState = LogListSceneState()
        }
    }
    
    public var body: some View {
        List {
            ForEach(sceneState.logFiles, id: \.self) { logFile in
                NavigationLink(destination: LogDetailScene(sceneState: LogDetailSceneState(logFileURL: logFile,
                                                                                           prefix: sceneState.prefix,
                                                                                           identifier: sceneState.identifier))) {
                    Text(logFile.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .onDelete(perform: deleteLogFiles)
        }
        #if os(iOS) || os(tvOS)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !sceneState.logFiles.isEmpty {
                    Button(action: {
                        sceneState.deleteLogFiles()
                    }) {
                        Text(String(localized: "clear_all", bundle: .module))
                            .foregroundColor(.red)
                    }
                    .disabled(sceneState.logFiles.isEmpty)
                }
            }
        }
        #else
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if !sceneState.logFiles.isEmpty {
                    Button(action: {
                        sceneState.deleteLogFiles()
                    }) {
                        Text(String(localized: "clear_all", bundle: .module))
                            .foregroundColor(.red)
                    }
                    .disabled(sceneState.logFiles.isEmpty)
                }
            }
        }
        #endif
        .navigationTitle("Log Files")
        .onAppear(perform: sceneState.loadLogFiles)
    }
    
    private func deleteLogFiles(at offsets: IndexSet) {
//        sceneState.logFiles.remove(atOffsets: offsets)
        // 如果还要真的删掉磁盘文件，可以在这里调用 sceneState 的方法
        sceneState.deleteLogFile(at: offsets)
    }
}

#Preview {
    LogListScene(sceneState: LogListSceneState())
}

#if canImport(UIKit)
import UIKit

extension LogListScene {
    /// 创建一个包含 LogListScene 的 UIViewController,方便在 UIKit 项目中使用
    /// - Parameter sceneState: 可选的场景状态,不传则使用默认状态
    /// - Returns: 包含 LogListScene 的 UIViewController,外部可以自行决定如何展示 (present/push)
    public static func makeViewController(sceneState: LogListSceneState? = nil) -> UIViewController {
        let scene = LogListScene(sceneState: sceneState)
        let hostingController = UIHostingController(rootView: scene)
        hostingController.title = "Log Files"
        return hostingController
    }
}
#endif
