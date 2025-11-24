//
//  ShareSheet.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/9/15.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// SwiftUI 封装 UIActivityViewController（仅 iOS/tvOS）
public struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let onComplete: () -> Void

    public init(activityItems: [Any], onComplete: @escaping () -> Void) {
        self.activityItems = activityItems
        self.onComplete = onComplete
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.excludedActivityTypes = [.addToReadingList,
                                            .assignToContact,
                                            .markupAsPDF,
                                            .postToFacebook,
                                            .postToTencentWeibo,
                                            .postToVimeo,
                                            .postToTwitter,
                                            .postToWeibo,
                                            .postToFacebook]
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#if canImport(AppKit)
import AppKit

/// macOS 分享功能
public struct ShareSheet {
    let items: [Any]

    public init(items: [Any]) {
        self.items = items
    }

    @MainActor
    public func share() {
        let picker = NSSharingServicePicker(items: items)
        if let contentView = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }
}
#endif
