import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    @Binding var parameters: [BodyParameter]
    @Binding var bodyMode: String
    @Binding var rawData: String

    @State private var importJSONString = ""
    @State private var exportJSONString = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""

    private let importerExporter = BodyImporterExporter()

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
            Text("Body参数导入导出")
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
            Text("支持JSON格式的Body参数导入导出")
                .font(.caption)
                .foregroundStyle(.secondary)

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
            let importData = try importerExporter.importFromJSONString(importJSONString)

            parameters = importData.parameters
            bodyMode = importData.bodyMode

            if let rawData = importData.rawData {
                self.rawData = rawData
            }

            showAlert(title: "导入成功", message: "成功导入 \(importData.parameters.count) 个参数")
        } catch {
            showAlert(title: "导入失败", message: error.localizedDescription)
        }
    }

    private func exportParameters() {
        do {
            exportJSONString = try importerExporter.exportToJSONString(
                parameters,
                bodyMode: bodyMode,
                rawData: bodyMode == "raw" ? rawData : nil
            )
        } catch {
            showAlert(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func validateImportJSON() {
        do {
            let isValid = try importerExporter.validateImportString(importJSONString)
            if isValid {
                showAlert(title: "验证通过", message: "JSON格式有效")
            } else {
                showAlert(title: "验证失败", message: "JSON中没有有效的参数")
            }
        } catch {
            showAlert(title: "验证失败", message: error.localizedDescription)
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
