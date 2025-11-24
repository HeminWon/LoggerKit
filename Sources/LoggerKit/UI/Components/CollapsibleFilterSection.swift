//
//  CollapsibleFilterSection.swift
//  LoggerKit
//
//  Created by Hemin Won on 2025/11/23.
//

import SwiftUI

/// 水平滚动筛选区域组件
struct CollapsibleFilterSection: View {
    let title: String
    let options: [String]
    @Binding var selectedOptions: Set<String>

    /// 排序后的选项列表：选中的在前，未选中的在后
    private var sortedOptions: [String] {
        let selected = options.filter { selectedOptions.contains($0) }.sorted()
        let unselected = options.filter { !selectedOptions.contains($0) }.sorted()
        return selected + unselected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题栏
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !selectedOptions.isEmpty {
                    Text("(\(selectedOptions.count))")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Spacer()

                if selectedOptions.isEmpty {
                    // 没有选中时显示全选按钮
                    Button(String(localized: "select_all_button", bundle: .module)) {
                        selectedOptions = Set(options)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                } else {
                    // 有选中时显示清除按钮
                    Button(String(localized: "clear_button", bundle: .module)) {
                        selectedOptions.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }

            // 选项列表（水平滚动，使用 LazyHStack 优化性能）
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(sortedOptions, id: \.self) { option in
                        FilterChip(
                            title: truncateText(option, maxLength: 20),
                            isSelected: selectedOptions.contains(option)
                        ) {
                            if selectedOptions.contains(option) {
                                selectedOptions.remove(option)
                            } else {
                                selectedOptions.insert(option)
                            }
                        }
                    }
                }
                .padding(.vertical, 1) // 防止 LazyHStack 裁剪阴影
            }
        }
    }

    private func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count > maxLength {
            return String(text.prefix(maxLength)) + "..."
        }
        return text
    }
}
