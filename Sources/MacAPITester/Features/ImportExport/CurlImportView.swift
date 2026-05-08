import SwiftUI

struct CurlImportView: View {
    let onImport: (CurlParseResult) -> Void
    let onCancel: () -> Void

    @State private var curlText = ""
    @State private var errorMessage: String?
    @State private var showingAlert = false

    private let parser = CurlParser()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("导入 cURL")
                        .font(.system(size: 16, weight: .semibold))
                    Text("粘贴 cURL 命令，自动解析为请求")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Editor
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $curlText)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }
            .padding(20)

            Divider()

            // Footer
            HStack {
                Button {
                    if let clipboard = NSPasteboard.general.string(forType: .string) {
                        curlText = clipboard
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11))
                        Text("从剪贴板粘贴")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.5), in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Button("取消") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button(action: importCurl) {
                    Text("导入")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(curlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 520)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("导入错误", isPresented: $showingAlert) {
            Button("确定") {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private func importCurl() {
        do {
            let result = try parser.parse(curlText)
            onImport(result)
        } catch {
            errorMessage = error.localizedDescription
            showingAlert = true
        }
    }
}
