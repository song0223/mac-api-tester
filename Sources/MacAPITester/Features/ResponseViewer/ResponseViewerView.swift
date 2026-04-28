import AppKit
import SwiftUI

private enum ResponseContentTab: String, CaseIterable, Identifiable {
    case body = "响应体"
    case headers = "响应头"

    var id: String { rawValue }
}

private enum ResponseRenderMode: String, CaseIterable, Identifiable {
    case pretty = "美化"
    case raw = "原生"
    case preview = "预览"

    var id: String { rawValue }
}

struct ResponseViewerView: View {
    let response: RequestResponseSnapshot?
    let historyItems: [RequestHistoryItem]
    let errorMessage: String?
    private let panelBackground = Color(red: 249 / 255, green: 249 / 255, blue: 249 / 255)

    @State private var selectedTab: ResponseContentTab = .body
    @State private var renderMode: ResponseRenderMode = .pretty
    @State private var searchText = ""
    @State private var copyHint = false
    private let codeFontSize: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            responseHeader
            Divider()
            responseBody
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(panelBackground)
        .animation(.easeInOut(duration: 0.15), value: copyHint)
    }

    private var responseHeader: some View {
        HStack(spacing: 10) {
            Text("响应")
                .font(.headline)

            Text(callStatusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(callStatusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(callStatusColor.opacity(0.12), in: Capsule())

            if let response {
                Text("(响应码: \(response.statusCode)  耗时: \(durationText(response.duration)))")
                    .font(.caption)
                    .foregroundStyle(response.statusCode >= 200 && response.statusCode < 300 ? .green : .orange)
            }

            Spacer()

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var callStatusText: String {
        if let response {
            return response.statusCode >= 200 && response.statusCode < 300 ? "调用成功" : "调用失败"
        }
        if let errorMessage, !errorMessage.isEmpty {
            return "调用失败"
        }
        return "未调用"
    }

    private var callStatusColor: Color {
        if let response {
            return response.statusCode >= 200 && response.statusCode < 300 ? .green : .orange
        }
        if let errorMessage, !errorMessage.isEmpty {
            return .orange
        }
        return .secondary
    }

    private var responseBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                ForEach(ResponseContentTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                            Rectangle()
                                .fill(selectedTab == tab ? Color.black.opacity(0.72) : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(minWidth: 72, minHeight: 30)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()

                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)

                Button {
                    copyCurrentContent()
                } label: {
                    Image(systemName: copyHint ? "checkmark" : "doc.on.doc")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.bordered)

                Picker("", selection: $renderMode) {
                    ForEach(ResponseRenderMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if let response {
                ReadOnlyCodeTextView(
                    attributedText: attributedContentForDisplay(response),
                    resetIdentity: scrollContentIdentity(for: response)
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(minHeight: 420)
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("暂无响应数据")
                        .font(.system(size: 14, weight: .semibold))
                    Text("点击底部“运行调试”后，这里会显示响应体内容。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }

    private func copyCurrentContent() {
        guard let response else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(contentForDisplay(response), forType: .string)
        copyHint = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copyHint = false
        }
    }

    private func contentForDisplay(_ response: RequestResponseSnapshot) -> String {
        let source = selectedTab == .body ? response.bodyText : response.headersText
        let modeApplied = applyRenderMode(source)
        return removeLeadingBlankLines(from: applySearchFilter(modeApplied))
    }

    private func attributedContentForDisplay(_ response: RequestResponseSnapshot) -> NSAttributedString {
        let source = contentForDisplay(response)
        let result = NSMutableAttributedString(
            string: source,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: codeFontSize, weight: .regular),
                .foregroundColor: NSColor.textColor
            ]
        )

        guard selectedTab == .body, renderMode == .pretty,
              let regex = try? NSRegularExpression(pattern: #""([^"\\]|\\.)*"(?=\s*:)"#) else {
            return result
        }

        let range = NSRange(location: 0, length: (source as NSString).length)
        let keyColor = NSColor(calibratedRed: 45 / 255, green: 110 / 255, blue: 210 / 255, alpha: 1)
        for match in regex.matches(in: source, range: range) {
            result.addAttribute(.foregroundColor, value: keyColor, range: match.range)
        }
        return result
    }

    private func removeLeadingBlankLines(from source: String) -> String {
        var trimmed = source
        while let first = trimmed.first, first.isWhitespace || first.isNewline {
            trimmed.removeFirst()
        }
        return trimmed
    }

    private func scrollContentIdentity(for response: RequestResponseSnapshot) -> String {
        "\(selectedTab.rawValue)-\(renderMode.rawValue)-\(response.statusCode)-\(response.duration)-\(response.bodyText.hashValue)-\(response.headersText.hashValue)"
    }

    private func applyRenderMode(_ source: String) -> String {
        switch renderMode {
        case .raw:
            return source
        case .preview:
            return source
                .split(whereSeparator: \.isNewline)
                .prefix(30)
                .joined(separator: "\n") + (source.contains("\n") ? "\n\n... 预览模式仅显示前 30 行" : "")
        case .pretty:
            guard selectedTab == .body,
                  let data = source.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: data),
                  JSONSerialization.isValidJSONObject(jsonObject),
                  let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
                  let prettyString = String(data: prettyData, encoding: .utf8) else {
                return source
            }
            return prettyString
        }
    }

    private func applySearchFilter(_ source: String) -> String {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return source }

        let lines = source.split(whereSeparator: \.isNewline).map(String.init)
        let filtered = lines.filter { $0.localizedCaseInsensitiveContains(keyword) }
        if filtered.isEmpty {
            return "未找到包含 \"\(keyword)\" 的内容"
        }
        return filtered.joined(separator: "\n")
    }

    private func durationText(_ duration: TimeInterval) -> String {
        "\(Int((duration * 1000).rounded()))ms"
    }
}

private struct ReadOnlyCodeTextView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let resetIdentity: String

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = []
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = .zero
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.string = ""

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(attributedText)

        if context.coordinator.lastResetIdentity != resetIdentity {
            context.coordinator.lastResetIdentity = resetIdentity
            DispatchQueue.main.async {
                scrollView.contentView.scroll(to: .zero)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastResetIdentity: String?
    }
}
