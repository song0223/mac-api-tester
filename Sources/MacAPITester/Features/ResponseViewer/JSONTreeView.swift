import SwiftUI

/// JSON 树视图
struct JSONTreeView: View {
    let jsonString: String
    @State private var rootNode: JSONNode?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                if let rootNode {
                    JSONNodeView(node: rootNode, depth: 0)
                } else {
                    Text(jsonString)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: 250, alignment: .topLeading)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .onAppear {
            parseJSON()
        }
        .onChange(of: jsonString) { _, _ in
            parseJSON()
        }
    }

    private func parseJSON() {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            rootNode = nil
            return
        }
        rootNode = JSONNode(key: nil, value: obj)
    }
}

/// JSON 节点
private struct JSONNode: Identifiable {
    let id = UUID()
    let key: String?
    let value: Any

    var isExpandable: Bool {
        value is [String: Any] || value is [Any]
    }

    var children: [JSONNode] {
        if let dict = value as? [String: Any] {
            return dict.sorted(by: { $0.key < $1.key }).map { JSONNode(key: $0.key, value: $0.value) }
        } else if let array = value as? [Any] {
            return array.map { JSONNode(key: nil, value: $0) }
        }
        return []
    }
}

/// JSON 节点视图
private struct JSONNodeView: View {
    let node: JSONNode
    let depth: Int

    private var indent: CGFloat {
        CGFloat(depth) * 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 节点行
            HStack(alignment: .top, spacing: 4) {
                // 占位
                if node.isExpandable {
                    Color.clear
                        .frame(width: 12, height: 12)
                } else {
                    Color.clear
                        .frame(width: 12, height: 12)
                }

                // Key
                if let key = node.key {
                    Text("\"\(key)\"")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color.purple)
                    Text(":")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                // Value
                if node.isExpandable {
                    if let dict = node.value as? [String: Any] {
                        Text("{")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else if let array = node.value as? [Any] {
                        Text("[")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    valueText
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, indent)

            // 子节点
            if node.isExpandable {
                ForEach(node.children) { child in
                    JSONNodeView(node: child, depth: depth + 1)
                }

                // 闭合括号
                HStack(spacing: 4) {
                    if node.value is [String: Any] {
                        Text("}")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else if node.value is [Any] {
                        Text("]")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, indent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var valueText: some View {
        if node.value is NSNull {
            Text("null")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.red)
        } else if let num = node.value as? NSNumber {
            // 区分 Bool 和数字：CFBooleanType 是 Bool 的底层类型
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                Text(num.boolValue ? "true" : "false")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.orange)
            } else {
                Text("\(num)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.blue)
            }
        } else if let str = node.value as? String {
            Text("\"\(str)\"")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.green)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
