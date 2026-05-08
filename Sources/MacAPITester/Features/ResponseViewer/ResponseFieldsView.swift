import SwiftUI
import UniformTypeIdentifiers

struct ResponseFieldsView: View {
    @Binding var fields: [ResponseFieldInfo]
    let responseBody: String
    let onGenerate: () -> Void
    let onFieldsChanged: () -> Void

    @State private var draggingFieldID: UUID?

    private let fieldNameWidth: CGFloat = 300
    private let typeWidth: CGFloat = 120
    private let descWidth: CGFloat = 300
    private let cellPadding: CGFloat = 12
    private let rowHeight: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Text("参数说明")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: onGenerate) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                        Text("从响应生成")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1), in: Capsule())
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .disabled(responseBody.isEmpty)

                Button(action: {
                    fields.append(ResponseFieldInfo(fieldName: "", fieldType: "string"))
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("添加行")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.1), in: Capsule())
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // 表头和内容使用相同的布局
            tableHeaderRow

            Divider()

            // 字段列表
            if fields.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("暂无参数说明")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("点击\"从响应生成\"自动解析 JSON 字段")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach($fields) { $field in
                            fieldRow(field: $field)
                                .overlay(Divider(), alignment: .bottom)
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: FieldReorderDropDelegate(
                                        targetID: field.id,
                                        fields: $fields,
                                        draggingID: $draggingFieldID
                                    )
                                )
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    // 表头行
    private var tableHeaderRow: some View {
        HStack(spacing: 0) {
            Text("字段名")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: fieldNameWidth, height: rowHeight, alignment: .leading)
                .padding(.horizontal, cellPadding)

            Divider()

            Text("类型")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: typeWidth, height: rowHeight, alignment: .leading)
                .padding(.horizontal, cellPadding)

            Divider()

            Text("描述")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: descWidth, height: rowHeight, alignment: .leading)
                .padding(.horizontal, cellPadding)

            Divider()

            Text("操作")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: rowHeight)
                .padding(.horizontal, cellPadding)
        }
        .frame(height: rowHeight)
        .background(Color.black.opacity(0.02))
    }

    // 内容行
    private func fieldRow(field: Binding<ResponseFieldInfo>) -> some View {
        HStack(spacing: 0) {
            // 字段名
            TextField("字段名", text: field.fieldName)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .frame(width: fieldNameWidth, height: rowHeight, alignment: .leading)
                .padding(.horizontal, cellPadding)
                .onChange(of: field.wrappedValue.fieldName) { _, _ in
                    onFieldsChanged()
                }

            Divider()

            // 类型
            Picker("", selection: field.fieldType) {
                Text("string").tag("string")
                Text("integer").tag("integer")
                Text("number").tag("number")
                Text("boolean").tag("boolean")
                Text("object").tag("object")
                Text("array").tag("array")
                Text("null").tag("null")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .font(.system(size: 12))
            .frame(width: typeWidth, height: rowHeight, alignment: .leading)
            .padding(.horizontal, cellPadding)
            .onChange(of: field.wrappedValue.fieldType) { _, _ in
                onFieldsChanged()
            }

            Divider()

            // 描述
            TextField("(选填) 字段描述", text: field.description)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: descWidth, height: rowHeight, alignment: .leading)
                .padding(.horizontal, cellPadding)
                .onChange(of: field.wrappedValue.description) { _, _ in
                    onFieldsChanged()
                }

            Divider()

            // 操作 - 居中显示
            HStack(spacing: 12) {
                Button(action: {
                    fields.removeAll(where: { $0.id == field.wrappedValue.id })
                    onFieldsChanged()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()

                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .onDrag {
                        draggingFieldID = field.wrappedValue.id
                        return NSItemProvider(object: field.wrappedValue.id.uuidString as NSString)
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: rowHeight)
            .padding(.horizontal, cellPadding)
        }
        .frame(height: rowHeight)
    }
}

// MARK: - 拖拽排序代理

private struct FieldReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var fields: [ResponseFieldInfo]
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != targetID,
              let from = fields.firstIndex(where: { $0.id == draggingID }),
              let to = fields.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.12)) {
            let field = fields.remove(at: from)
            fields.insert(field, at: to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
