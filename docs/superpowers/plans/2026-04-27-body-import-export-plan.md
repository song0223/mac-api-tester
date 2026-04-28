# Body参数导入导出实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现JSON格式的Body参数导入导出功能

**Architecture:** 创建独立的导入导出模块，支持JSON格式的Body参数导入导出

**Tech Stack:** Swift, Foundation, SwiftUI

---

## 文件结构

### 新增文件
- `Sources/MacAPITester/Core/ImportExport/BodyImporterExporter.swift` - Body导入导出器
- `Sources/MacAPITester/Features/ImportExport/ImportExportView.swift` - 导入导出UI
- `Tests/MacAPITesterTests/BodyImporterExporterTests.swift` - 导入导出测试

### 修改文件
- `Sources/MacAPITester/Features/RequestEditor/RequestEditorView.swift` - 集成导入导出功能
- `Sources/MacAPITester/App/AppContainer.swift` - 集成导入导出功能

---

## 任务分解

### Task 1: 创建Body导入导出器

**Files:**
- Create: `Sources/MacAPITester/Core/ImportExport/BodyImporterExporter.swift`

- [ ] **Step 1: 创建BodyImporterExporter类**

```swift
import Foundation

struct BodyParameter: Codable, Equatable {
    var name: String
    var value: String
    var type: String
    var required: Bool
    var description: String
    
    init(
        name: String = "",
        value: String = "",
        type: String = "string",
        required: Bool = false,
        description: String = ""
    ) {
        self.name = name
        self.value = value
        self.type = type
        self.required = required
        self.description = description
    }
}

struct BodyImportExportData: Codable {
    var parameters: [BodyParameter]
    var bodyMode: String
    var rawData: String?
    
    init(
        parameters: [BodyParameter] = [],
        bodyMode: String = "form-data",
        rawData: String? = nil
    ) {
        self.parameters = parameters
        self.bodyMode = bodyMode
        self.rawData = rawData
    }
}

final class BodyImporterExporter {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        decoder = JSONDecoder()
    }
    
    func exportParameters(_ parameters: [BodyParameter], bodyMode: String, rawData: String? = nil) throws -> Data {
        let exportData = BodyImportExportData(
            parameters: parameters,
            bodyMode: bodyMode,
            rawData: rawData
        )
        return try encoder.encode(exportData)
    }
    
    func importParameters(from data: Data) throws -> BodyImportExportData {
        return try decoder.decode(BodyImportExportData.self, from: data)
    }
    
    func exportToJSONString(_ parameters: [BodyParameter], bodyMode: String, rawData: String? = nil) throws -> String {
        let data = try exportParameters(parameters, bodyMode: bodyMode, rawData: rawData)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ImportError.exportFailed("无法将数据转换为JSON字符串")
        }
        return jsonString
    }
    
    func importFromJSONString(_ jsonString: String) throws -> BodyImportExportData {
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.importFailed("无法将JSON字符串转换为数据")
        }
        return try importParameters(from: data)
    }
    
    func validateImportData(_ data: Data) throws -> Bool {
        do {
            let importData = try decoder.decode(BodyImportExportData.self, from: data)
            return !importData.parameters.isEmpty || importData.rawData != nil
        } catch {
            throw ImportError.validationFailed("JSON格式无效: \(error.localizedDescription)")
        }
    }
    
    func validateImportString(_ jsonString: String) throws -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.validationFailed("无法将JSON字符串转换为数据")
        }
        return try validateImportData(data)
    }
}

enum ImportError: Error, LocalizedError {
    case exportFailed(String)
    case importFailed(String)
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return "导出失败: \(message)"
        case .importFailed(let message):
            return "导入失败: \(message)"
        case .validationFailed(let message):
            return "验证失败: \(message)"
        }
    }
}
```

- [ ] **Step 2: 编写Body导入导出测试**

```swift
import Testing
@testable import MacAPITester

@Suite("Body Importer Exporter Tests")
struct BodyImporterExporterTests {
    @Test func exportsParametersToJSON() throws {
        let exporter = BodyImporterExporter()
        let parameters = [
            BodyParameter(name: "username", value: "test", type: "string", required: true, description: "用户名"),
            BodyParameter(name: "password", value: "123456", type: "string", required: true, description: "密码")
        ]
        
        let jsonString = try exporter.exportToJSONString(parameters, bodyMode: "form-data")
        
        #expect(jsonString.contains("username"))
        #expect(jsonString.contains("password"))
        #expect(jsonString.contains("form-data"))
    }
    
    @Test func importsParametersFromJSON() throws {
        let exporter = BodyImporterExporter()
        let jsonString = """
        {
            "parameters": [
                {"name": "username", "value": "test", "type": "string", "required": true, "description": "用户名"}
            ],
            "bodyMode": "form-data"
        }
        """
        
        let importData = try exporter.importFromJSONString(jsonString)
        
        #expect(importData.parameters.count == 1)
        #expect(importData.parameters.first?.name == "username")
        #expect(importData.bodyMode == "form-data")
    }
    
    @Test func validatesImportData() throws {
        let exporter = BodyImporterExporter()
        let validJSON = """
        {
            "parameters": [{"name": "test", "value": "123"}],
            "bodyMode": "form-data"
        }
        """
        
        let isValid = try exporter.validateImportString(validJSON)
        #expect(isValid == true)
    }
    
    @Test func throwsErrorForInvalidJSON() {
        let exporter = BodyImporterExporter()
        let invalidJSON = "这不是有效的JSON"
        
        #expect(throws: ImportError.self) {
            try exporter.validateImportString(invalidJSON)
        }
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test --filter BodyImporterExporterTests`
Expected: 测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/ImportExport/BodyImporterExporter.swift
git add Tests/MacAPITesterTests/BodyImporterExporterTests.swift
git commit -m "feat: 添加Body导入导出器"
```

### Task 2: 创建导入导出UI

**Files:**
- Create: `Sources/MacAPITester/Features/ImportExport/ImportExportView.swift`

- [ ] **Step 1: 创建ImportExportView**

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    @Binding var parameters: [BodyParameter]
    @Binding var bodyMode: String
    @Binding var rawData: String
    
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
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
                showingImportPicker = true
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
            // 导入区域
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
                    
                    Button("从文件导入") {
                        showingImportPicker = true
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("验证JSON") {
                        validateImportJSON()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // 导出区域
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
                    
                    Button("保存到文件") {
                        showingExportPicker = true
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
            let importData = try importerExporter.importFromJSONString(importJSONString)
            
            // 更新参数
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

struct ImportExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data?
    
    init(data: Data?) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data ?? Data())
    }
}
```

- [ ] **Step 2: 更新RequestEditorView集成导入导出功能**

```swift
// 在RequestEditorView中添加
@State private var showingImportExport = false

// 在bodyTablePanel中更新"导入导出"按钮
Button("导入导出") {
    showingImportExport = true
}
.buttonStyle(.plain)
.foregroundStyle(.secondary)
.sheet(isPresented: $showingImportExport) {
    ImportExportView(
        parameters: $bodyRows.map { rows in
            rows.map { BodyParameter(name: $0.name, value: $0.value, type: $0.type, required: $0.required, description: $0.description) }
        },
        bodyMode: Binding(
            get: { bodyMode.rawValue },
            set: { newMode in
                if let mode = BodyMode(rawValue: newMode) {
                    bodyMode = mode
                }
            }
        ),
        rawData: $request.bodyText
    )
}
```

- [ ] **Step 3: 运行应用验证UI**

Run: `./script/build_and_run.sh`
Expected: 导入导出UI正常显示

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Features/ImportExport/ImportExportView.swift
git add Sources/MacAPITester/Features/RequestEditor/RequestEditorView.swift
git commit -m "feat: 添加Body参数导入导出UI"
```

---

## 验证清单

- [ ] Body导入导出器正常工作
- [ ] 导入导出UI正常显示
- [ ] 导入功能正常
- [ ] 导出功能正常
- [ ] 验证功能正常
- [ ] 所有测试通过

---

## 回滚计划

如果导入导出功能失败，可以回滚：

1. 删除新增的导入导出相关文件
2. 恢复RequestEditorView.swift
3. 重新构建和测试
