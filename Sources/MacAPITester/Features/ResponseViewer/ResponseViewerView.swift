import AppKit
import SwiftUI

private enum ResponseContentTab: String, CaseIterable, Identifiable {
    case body = "响应体"
    case headers = "响应头"

    var id: String { rawValue }
}

struct ResponseViewerView: View {
    let response: RequestResponseSnapshot?
    let historyItems: [RequestHistoryItem]
    let errorMessage: String?
    @Binding var historySearchText: String
    @Binding var responseFields: [ResponseFieldInfo]
    let onHistorySearch: () -> Void
    let onFieldsChanged: () -> Void
    let onResponseBodyChanged: (String) -> Void

    @State private var selectedTab: ResponseContentTab = .body
    @State private var searchText = ""
    @State private var copyHint = false
    @State private var showingHistory = false
    @State private var editingBodyText: String = ""
    @State private var isEditingBody = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                responseHeader
                responseBody
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            // 参数说明区域
            ResponseFieldsView(
                fields: $responseFields,
                responseBody: response?.bodyText ?? "",
                onGenerate: generateFieldsFromResponse,
                onFieldsChanged: onFieldsChanged
            )
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.15), value: copyHint)
        .animation(.easeInOut(duration: 0.15), value: isEditingBody)
    }

    private func generateFieldsFromResponse() {
        guard let responseBody = response?.bodyText else { return }
        let newFields = ResponseFieldParser.parseFields(from: responseBody)
        // 合并：字段名一样则保留之前的描述，新的字段追加
        var merged: [ResponseFieldInfo] = []
        let existingMap = Dictionary(uniqueKeysWithValues: responseFields.map { ($0.fieldName, $0) })
        for field in newFields {
            if let existing = existingMap[field.fieldName] {
                merged.append(ResponseFieldInfo(
                    id: existing.id,
                    fieldName: field.fieldName,
                    fieldType: field.fieldType,
                    description: existing.description
                ))
            } else {
                merged.append(field)
            }
        }
        responseFields = merged
        onFieldsChanged()
    }

    // MARK: - 响应头部（固定高度）

    private var responseHeader: some View {
        HStack(spacing: 8) {
            Text("响应")
                .font(.system(size: 13, weight: .semibold))

            if let response, response.statusCode > 0 {
                Text("\(response.statusCode)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusCodeColor(response.statusCode), in: RoundedRectangle(cornerRadius: 3))

                if response.duration > 0 {
                    Text(durationText(response.duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
        .frame(height: 32)
        .padding(.horizontal, 10)
        .background(Color.gray.opacity(0.05))
    }

    private func statusCodeColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: return .green
        case 300..<400: return .orange
        case 400..<500: return .red
        case 500..<600: return .purple
        default: return .gray
        }
    }

    // MARK: - 响应体内容

    private var responseBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标签栏
            HStack(spacing: 0) {
                tabButton("响应体", isSelected: !showingHistory && selectedTab == .body) {
                    selectedTab = .body
                    showingHistory = false
                    isEditingBody = false
                }
                tabButton("响应头", isSelected: !showingHistory && selectedTab == .headers) {
                    selectedTab = .headers
                    showingHistory = false
                    isEditingBody = false
                }
                tabButton("历史", isSelected: showingHistory) {
                    showingHistory.toggle()
                    isEditingBody = false
                }

                Spacer()

                // 工具栏
                HStack(spacing: 4) {
                    // 搜索
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        TextField("搜索", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .frame(width: 100)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))

                    toolButton(icon: copyHint ? "checkmark" : "doc.on.doc", action: copyCurrentContent)
                        .help("复制")

                    if selectedTab == .body && !showingHistory {
                        toolButton(icon: isEditingBody ? "checkmark.circle.fill" : "pencil", action: toggleEditMode)
                            .foregroundStyle(isEditingBody ? .green : .secondary)
                            .help(isEditingBody ? "保存" : "编辑")
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.gray.opacity(0.03))

            Divider()

            // 内容区域
            if showingHistory {
                historyListView
            } else if isEditingBody {
                TextEditor(text: $editingBodyText)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.white)
                    .frame(height: 250)
            } else if let response {
                if selectedTab == .headers {
                    headersTableView(headersText: response.headersText)
                } else {
                    codeBlockView(text: response.bodyText)
                }
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - 代码块视图

    @ViewBuilder
    private func codeBlockView(text: String) -> some View {
        if isJSON(text) {
            JSONTreeView(jsonString: text)
        } else {
            plainTextView(text: text)
        }
    }

    private func plainTextView(text: String) -> some View {
        ScrollView(.vertical) {
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: 250, alignment: .topLeading)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
    }

    private func isJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    // MARK: - 响应头表格

    private func headersTableView(headersText: String) -> some View {
        let headers = parseHeaders(headersText)

        return VStack(spacing: 0) {
            // 表头
            HStack(spacing: 0) {
                Text("Header")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 180, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)

                Divider()

                Text("Value")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .background(Color.gray.opacity(0.08))

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                        HStack(spacing: 0) {
                            Text(header.key)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.blue)
                                .frame(width: 180, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)

                            Divider()

                            Text(header.value)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .textSelection(.enabled)
                        }
                        .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.03))

                        if index < headers.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 250, alignment: .topLeading)
        }
        .background(Color.white)
    }

    private func parseHeaders(_ text: String) -> [(key: String, value: String)] {
        guard !text.isEmpty, text != "无响应头。" else { return [] }
        return text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return (key: String(parts[0]).trimmingCharacters(in: .whitespaces),
                        value: String(parts[1]).trimmingCharacters(in: .whitespaces))
            }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("暂无响应数据")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 250)
        .background(Color.white)
    }

    // MARK: - 历史记录

    private var historyListView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                TextField("搜索历史...", text: $historySearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .onSubmit { onHistorySearch() }
                if !historySearchText.isEmpty {
                    Button { historySearchText = ""; onHistorySearch() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            if historyItems.isEmpty {
                VStack {
                    Spacer()
                    Text(historySearchText.isEmpty ? "暂无历史记录" : "未找到匹配记录")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(historyItems) { item in
                    HStack {
                        Text(item.message)
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Spacer()
                        Text(formatDate(item.timestamp))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 1)
                }
                .listStyle(.inset)
            }
        }
        .frame(minHeight: 300)
    }

    // MARK: - 辅助函数

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func copyCurrentContent() {
        guard let response else { return }
        let text = selectedTab == .body ? response.bodyText : response.headersText
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copyHint = true
        Task {
            try await Task.sleep(for: .milliseconds(1200))
            copyHint = false
        }
    }

    private func toggleEditMode() {
        if isEditingBody {
            onResponseBodyChanged(editingBodyText)
            isEditingBody = false
        } else {
            editingBodyText = response?.bodyText ?? ""
            isEditingBody = true
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        "\(Int((duration * 1000).rounded()))ms"
    }

    private func tabButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }

    private func toolButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}
