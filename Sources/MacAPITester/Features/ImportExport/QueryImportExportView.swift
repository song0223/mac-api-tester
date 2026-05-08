import SwiftUI

struct QueryImportExportView: View {
    @Binding var queryRows: [QueryParamRow]
    let onDismiss: () -> Void

    @State private var importJSONString = ""
    @State private var exportJSONString = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""

    var body: some View {
        VStack(spacing: 16) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 500, minHeight: 400)
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("确定") {}
        } message: {
            Text(alertMessage)
        }
    }

    private var header: some View {
        HStack {
            Text("Query参数导入导出")
                .font(.headline)

            Spacer()

            Button("导入") {
                importParameters()
            }
            .buttonStyle(.bordered)

            Button("导出") {
                exportParameters()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var content: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("导入JSON")
                    .font(.subheadline)
                    .fontWeight(.bold)

                TextEditor(text: $importJSONString)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .border(Color.gray.opacity(0.3))

                HStack {
                    Button("从剪贴板导入") {
                        importFromClipboard()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("验证JSON") {
                        validateImportJSON()
                    }
                    .buttonStyle(.bordered)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("导出JSON")
                    .font(.subheadline)
                    .fontWeight(.bold)

                TextEditor(text: $exportJSONString)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .border(Color.gray.opacity(0.3))
                    .disabled(true)

                HStack {
                    Button("复制到剪贴板") {
                        copyToClipboard()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
        }
        .padding()
    }

    private var footer: some View {
        HStack {
            Text("支持JSON格式的Query参数导入导出")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func importFromClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
            showAlert(title: "导入失败", message: "剪贴板中没有文本内容")
            return
        }

        importJSONString = clipboardString
        importParameters()
    }

    private func importParameters() {
        do {
            guard let data = importJSONString.data(using: .utf8) else {
                showAlert(title: "导入失败", message: "无法解析JSON字符串")
                return
            }

            let decoder = JSONDecoder()
            let importedRows = try decoder.decode([QueryParamImportItem].self, from: data)

            queryRows = importedRows.map { item in
                QueryParamRow(
                    name: item.name,
                    value: item.value,
                    required: item.require == "1",
                    description: item.remark
                )
            }

            if queryRows.isEmpty {
                queryRows = [QueryParamRow()]
            }

            showAlert(title: "导入成功", message: "成功导入 \(importedRows.count) 个参数")
        } catch {
            showAlert(title: "导入失败", message: error.localizedDescription)
        }
    }

    private func exportParameters() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let exportItems = queryRows.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }.map { row in
                QueryParamImportItem(
                    name: row.name,
                    type: "string",
                    value: row.value,
                    require: row.required ? "1" : "0",
                    remark: row.description
                )
            }

            let data = try encoder.encode(exportItems)
            exportJSONString = String(data: data, encoding: .utf8) ?? ""
        } catch {
            showAlert(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func validateImportJSON() {
        do {
            guard let data = importJSONString.data(using: .utf8) else {
                showAlert(title: "验证失败", message: "无法解析JSON字符串")
                return
            }

            let decoder = JSONDecoder()
            let _ = try decoder.decode([QueryParamImportItem].self, from: data)
            showAlert(title: "验证通过", message: "JSON格式有效")
        } catch {
            showAlert(title: "验证失败", message: "JSON格式无效: \(error.localizedDescription)")
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(exportJSONString, forType: .string)
        showAlert(title: "复制成功", message: "JSON已复制到剪贴板")
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

private struct QueryParamImportItem: Codable {
    var name: String
    var type: String
    var value: String
    var require: String
    var remark: String
}
