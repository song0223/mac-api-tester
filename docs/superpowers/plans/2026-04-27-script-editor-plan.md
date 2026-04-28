# 前/后执行脚本功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现可视化脚本编辑器，支持多引擎（JavaScriptCore, QuickJS），用于在请求前后执行自定义脚本

**Architecture:** 创建独立的脚本模块，包含ScriptEngine和ScriptEditor，支持脚本执行、调试和预览

**Tech Stack:** Swift, JavaScriptCore, SwiftUI

---

## 文件结构

### 新增文件
- `Sources/MacAPITester/Core/Scripts/ScriptEngine.swift` - 脚本执行引擎
- `Sources/MacAPITester/Core/Scripts/ScriptModels.swift` - 脚本数据模型
- `Sources/MacAPITester/Core/Scripts/ScriptDebugger.swift` - 脚本调试器
- `Sources/MacAPITester/Features/ScriptEditor/ScriptEditorView.swift` - 脚本编辑器UI
- `Sources/MacAPITester/Features/ScriptEditor/ScriptConsoleView.swift` - 脚本控制台UI
- `Tests/MacAPITesterTests/ScriptEngineTests.swift` - 脚本引擎测试

### 修改文件
- `Sources/MacAPITester/App/AppContainer.swift` - 集成脚本功能
- `Sources/MacAPITester/Core/Networking/HTTPClient.swift` - 支持脚本执行
- `Sources/MacAPITester/Core/Domain/Models.swift` - 添加脚本相关模型

---

## 任务分解

### Task 1: 创建脚本数据模型

**Files:**
- Create: `Sources/MacAPITester/Core/Scripts/ScriptModels.swift`

- [ ] **Step 1: 创建脚本数据模型**

```swift
import Foundation

enum ScriptType: String, Codable, CaseIterable, Identifiable {
    case preRequest = "pre_request"
    case postResponse = "post_response"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .preRequest: return "前执行脚本"
        case .postResponse: return "后执行脚本"
        }
    }
}

enum ScriptEngineType: String, Codable, CaseIterable, Identifiable {
    case javaScriptCore = "javascriptcore"
    case quickJS = "quickjs"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .javaScriptCore: return "JavaScriptCore"
        case .quickJS: return "QuickJS"
        }
    }
}

struct Script: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var scriptType: ScriptType
    var engine: ScriptEngineType
    var content: String
    var isEnabled: Bool
    var executionOrder: Int
    
    init(
        id: UUID = UUID(),
        name: String = "新脚本",
        scriptType: ScriptType = .preRequest,
        engine: ScriptEngineType = .javaScriptCore,
        content: String = "",
        isEnabled: Bool = true,
        executionOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.scriptType = scriptType
        self.engine = engine
        self.content = content
        self.isEnabled = isEnabled
        self.executionOrder = executionOrder
    }
}

struct ScriptExecutionContext {
    var request: URLRequest
    var response: HTTPURLResponse?
    var responseBody: Data?
    var variables: [String: String]
    var cookies: [String: String]
    
    init(
        request: URLRequest,
        response: HTTPURLResponse? = nil,
        responseBody: Data? = nil,
        variables: [String: String] = [:],
        cookies: [String: String] = [:]
    ) {
        self.request = request
        self.response = response
        self.responseBody = responseBody
        self.variables = variables
        self.cookies = cookies
    }
}

struct ScriptExecutionResult {
    var success: Bool
    var output: String
    var error: String?
    var modifiedRequest: URLRequest?
    var modifiedResponse: (HTTPURLResponse, Data)?
    var modifiedVariables: [String: String]?
    var modifiedCookies: [String: String]?
    var executionTime: TimeInterval
    
    init(
        success: Bool,
        output: String = "",
        error: String? = nil,
        modifiedRequest: URLRequest? = nil,
        modifiedResponse: (HTTPURLResponse, Data)? = nil,
        modifiedVariables: [String: String]? = nil,
        modifiedCookies: [String: String]? = nil,
        executionTime: TimeInterval = 0
    ) {
        self.success = success
        self.output = output
        self.error = error
        self.modifiedRequest = modifiedRequest
        self.modifiedResponse = modifiedResponse
        self.modifiedVariables = modifiedVariables
        self.modifiedCookies = modifiedCookies
        self.executionTime = executionTime
    }
}

struct ScriptLog: Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String
    
    enum LogLevel: String {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case debug = "DEBUG"
    }
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel = .info,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}
```

- [ ] **Step 2: 编写脚本模型测试**

```swift
import Testing
@testable import MacAPITester

@Suite("Script Models Tests")
struct ScriptModelsTests {
    @Test func scriptTypeDisplayName() {
        #expect(ScriptType.preRequest.displayName == "前执行脚本")
        #expect(ScriptType.postResponse.displayName == "后执行脚本")
    }
    
    @Test func scriptEngineTypeDisplayName() {
        #expect(ScriptEngineType.javaScriptCore.displayName == "JavaScriptCore")
        #expect(ScriptEngineType.quickJS.displayName == "QuickJS")
    }
    
    @Test func scriptInitialization() {
        let script = Script(name: "测试脚本", scriptType: .preRequest, content: "console.log('hello')")
        #expect(script.name == "测试脚本")
        #expect(script.scriptType == .preRequest)
        #expect(script.isEnabled == true)
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test --filter ScriptModelsTests`
Expected: 测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/Scripts/ScriptModels.swift
git add Tests/MacAPITesterTests/ScriptModelsTests.swift
git commit -m "feat: 添加脚本数据模型"
```

### Task 2: 创建脚本执行引擎

**Files:**
- Create: `Sources/MacAPITester/Core/Scripts/ScriptEngine.swift`

- [ ] **Step 1: 创建ScriptEngine协议和实现**

```swift
import Foundation
import JavaScriptCore

protocol ScriptEngineProtocol {
    func execute(script: String, context: ScriptExecutionContext) throws -> ScriptExecutionResult
}

final class JavaScriptCoreEngine: ScriptEngineProtocol {
    private var logs: [ScriptLog] = []
    
    func execute(script: String, context: ScriptExecutionContext) throws -> ScriptExecutionResult {
        let startTime = Date()
        logs.removeAll()
        
        let jsContext = JSContext()
        
        // 添加控制台对象
        setupConsole(in: jsContext)
        
        // 添加请求对象
        setupRequest(in: jsContext, context: context)
        
        // 添加响应对象
        if let response = context.response, let body = context.responseBody {
            setupResponse(in: jsContext, response: response, body: body)
        }
        
        // 添加变量对象
        setupVariables(in: jsContext, variables: context.variables)
        
        // 添加Cookies对象
        setupCookies(in: jsContext, cookies: context.cookies)
        
        // 执行脚本
        guard let result = jsContext?.evaluateScript(script) else {
            let error = jsContext?.exception?.toString() ?? "脚本执行失败"
            return ScriptExecutionResult(
                success: false,
                error: error,
                executionTime: Date().timeIntervalSince(startTime)
            )
        }
        
        // 获取修改后的数据
        let modifiedRequest = extractRequest(from: jsContext, original: context.request)
        let modifiedVariables = extractVariables(from: jsContext, original: context.variables)
        let modifiedCookies = extractCookies(from: jsContext, original: context.cookies)
        
        let output = logs.map { "[\($0.level.rawValue)] \($0.message)" }.joined(separator: "\n")
        
        return ScriptExecutionResult(
            success: true,
            output: output,
            modifiedRequest: modifiedRequest,
            modifiedVariables: modifiedVariables,
            modifiedCookies: modifiedCookies,
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
    
    private func setupConsole(in context: JSContext?) {
        let consoleObject = JSValue(newObjectIn: context)
        
        let logFunction: @convention(block) (String) -> Void = { [weak self] message in
            self?.logs.append(ScriptLog(level: .info, message: message))
        }
        consoleObject?.setObject(logFunction, forKeyedSubscript: "log" as NSString)
        
        let warnFunction: @convention(block) (String) -> Void = { [weak self] message in
            self?.logs.append(ScriptLog(level: .warning, message: message))
        }
        consoleObject?.setObject(warnFunction, forKeyedSubscript: "warn" as NSString)
        
        let errorFunction: @convention(block) (String) -> Void = { [weak self] message in
            self?.logs.append(ScriptLog(level: .error, message: message))
        }
        consoleObject?.setObject(errorFunction, forKeyedSubscript: "error" as NSString)
        
        let debugFunction: @convention(block) (String) -> Void = { [weak self] message in
            self?.logs.append(ScriptLog(level: .debug, message: message))
        }
        consoleObject?.setObject(debugFunction, forKeyedSubscript: "debug" as NSString)
        
        context?.setObject(consoleObject, forKeyedSubscript: "console" as NSString)
    }
    
    private func setupRequest(in context: JSContext?, context execContext: ScriptExecutionContext) {
        let requestObject = JSValue(newObjectIn: context)
        
        requestObject?.setObject(execContext.request.url?.absoluteString ?? "", forKeyedSubscript: "url" as NSString)
        requestObject?.setObject(execContext.request.httpMethod ?? "GET", forKeyedSubscript: "method" as NSString)
        
        if let headers = execContext.request.allHTTPHeaderFields {
            let headersObject = JSValue(newObjectIn: context)
            for (key, value) in headers {
                headersObject?.setObject(value, forKeyedSubscript: key as NSString)
            }
            requestObject?.setObject(headersObject, forKeyedSubscript: "headers" as NSString)
        }
        
        if let body = execContext.request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            requestObject?.setObject(bodyString, forKeyedSubscript: "body" as NSString)
        }
        
        context?.setObject(requestObject, forKeyedSubscript: "request" as NSString)
    }
    
    private func setupResponse(in context: JSContext?, response: HTTPURLResponse, body: Data) {
        let responseObject = JSValue(newObjectIn: context)
        
        responseObject?.setObject(response.statusCode, forKeyedSubscript: "statusCode" as NSString)
        
        let headersObject = JSValue(newObjectIn: context)
        for (key, value) in response.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                headersObject?.setObject(valueString, forKeyedSubscript: keyString as NSString)
            }
        }
        responseObject?.setObject(headersObject, forKeyedSubscript: "headers" as NSString)
        
        if let bodyString = String(data: body, encoding: .utf8) {
            responseObject?.setObject(bodyString, forKeyedSubscript: "body" as NSString)
        }
        
        context?.setObject(responseObject, forKeyedSubscript: "response" as NSString)
    }
    
    private func setupVariables(in context: JSContext?, variables: [String: String]) {
        let variablesObject = JSValue(newObjectIn: context)
        for (key, value) in variables {
            variablesObject?.setObject(value, forKeyedSubscript: key as NSString)
        }
        context?.setObject(variablesObject, forKeyedSubscript: "variables" as NSString)
    }
    
    private func setupCookies(in context: JSContext?, cookies: [String: String]) {
        let cookiesObject = JSValue(newObjectIn: context)
        for (key, value) in cookies {
            cookiesObject?.setObject(value, forKeyedSubscript: key as NSString)
        }
        context?.setObject(cookiesObject, forKeyedSubscript: "cookies" as NSString)
    }
    
    private func extractRequest(from context: JSContext?, original: URLRequest) -> URLRequest? {
        guard let requestObject = context?.objectForKeyedSubscript("request") else {
            return nil
        }
        
        var modifiedRequest = original
        
        if let urlString = requestObject.objectForKeyedSubscript("url")?.toString(),
           let url = URL(string: urlString) {
            modifiedRequest.url = url
        }
        
        if let method = requestObject.objectForKeyedSubscript("method")?.toString() {
            modifiedRequest.httpMethod = method
        }
        
        if let headersObject = requestObject.objectForKeyedSubscript("headers")?.toDictionary() as? [String: String] {
            modifiedRequest.allHTTPHeaderFields = headersObject
        }
        
        if let body = requestObject.objectForKeyedSubscript("body")?.toString() {
            modifiedRequest.httpBody = body.data(using: .utf8)
        }
        
        return modifiedRequest
    }
    
    private func extractVariables(from context: JSContext?, original: [String: String]) -> [String: String]? {
        guard let variablesObject = context?.objectForKeyedSubscript("variables")?.toDictionary() as? [String: String] else {
            return nil
        }
        return variablesObject
    }
    
    private func extractCookies(from context: JSContext?, original: [String: String]) -> [String: String]? {
        guard let cookiesObject = context?.objectForKeyedSubscript("cookies")?.toDictionary() as? [String: String] else {
            return nil
        }
        return cookiesObject
    }
}

final class ScriptEngine {
    private let javaScriptCoreEngine = JavaScriptCoreEngine()
    
    func execute(script: Script, context: ScriptExecutionContext) throws -> ScriptExecutionResult {
        guard script.isEnabled else {
            return ScriptExecutionResult(success: true, output: "脚本已禁用")
        }
        
        switch script.engine {
        case .javaScriptCore:
            return try javaScriptCoreEngine.execute(script: script.content, context: context)
        case .quickJS:
            // TODO: 实现QuickJS引擎
            throw ScriptError.engineNotSupported("QuickJS引擎暂未实现")
        }
    }
    
    func executeScripts(_ scripts: [Script], context: ScriptExecutionContext) throws -> ScriptExecutionResult {
        let sortedScripts = scripts
            .filter { $0.isEnabled }
            .sorted { $0.executionOrder < $1.executionOrder }
        
        var currentContext = context
        var combinedOutput = ""
        
        for script in sortedScripts {
            let result = try execute(script: script, context: currentContext)
            
            if !result.success {
                return result
            }
            
            combinedOutput += result.output + "\n"
            
            if let modifiedRequest = result.modifiedRequest {
                currentContext.request = modifiedRequest
            }
            
            if let modifiedVariables = result.modifiedVariables {
                currentContext.variables = modifiedVariables
            }
            
            if let modifiedCookies = result.modifiedCookies {
                currentContext.cookies = modifiedCookies
            }
        }
        
        return ScriptExecutionResult(
            success: true,
            output: combinedOutput,
            modifiedRequest: currentContext.request,
            modifiedVariables: currentContext.variables,
            modifiedCookies: currentContext.cookies
        )
    }
}

enum ScriptError: Error, LocalizedError {
    case engineNotSupported(String)
    case compilationError(String)
    case runtimeError(String)
    
    var errorDescription: String? {
        switch self {
        case .engineNotSupported(let message):
            return "引擎不支持: \(message)"
        case .compilationError(let message):
            return "编译错误: \(message)"
        case .runtimeError(let message):
            return "运行时错误: \(message)"
        }
    }
}
```

- [ ] **Step 2: 编写脚本引擎测试**

```swift
import Testing
@testable import MacAPITester

@Suite("Script Engine Tests")
struct ScriptEngineTests {
    @Test func executesJavaScriptCoreScript() throws {
        let engine = ScriptEngine()
        let script = Script(
            name: "测试脚本",
            scriptType: .preRequest,
            engine: .javaScriptCore,
            content: "console.log('Hello from script'); variables.test = 'modified';"
        )
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let context = ScriptExecutionContext(request: request, variables: ["original": "value"])
        
        let result = try engine.execute(script: script, context: context)
        
        #expect(result.success)
        #expect(result.modifiedVariables?["test"] == "modified")
    }
    
    @Test func skipsDisabledScript() throws {
        let engine = ScriptEngine()
        let script = Script(
            name: "禁用脚本",
            scriptType: .preRequest,
            engine: .javaScriptCore,
            content: "variables.test = 'modified';",
            isEnabled: false
        )
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let context = ScriptExecutionContext(request: request)
        
        let result = try engine.execute(script: script, context: context)
        
        #expect(result.success)
        #expect(result.modifiedVariables == nil)
    }
    
    @Test func executesMultipleScriptsInOrder() throws {
        let engine = ScriptEngine()
        let scripts = [
            Script(name: "脚本1", content: "variables.order = '1';", executionOrder: 2),
            Script(name: "脚本2", content: "variables.order = '2';", executionOrder: 1),
        ]
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let context = ScriptExecutionContext(request: request)
        
        let result = try engine.executeScripts(scripts, context: context)
        
        #expect(result.success)
        #expect(result.modifiedVariables?["order"] == "1")
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test --filter ScriptEngineTests`
Expected: 测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/Scripts/ScriptEngine.swift
git add Tests/MacAPITesterTests/ScriptEngineTests.swift
git commit -m "feat: 添加脚本执行引擎"
```

### Task 3: 创建脚本编辑器UI

**Files:**
- Create: `Sources/MacAPITester/Features/ScriptEditor/ScriptEditorView.swift`
- Create: `Sources/MacAPITester/Features/ScriptEditor/ScriptConsoleView.swift`

- [ ] **Step 1: 创建ScriptEditorView**

```swift
import SwiftUI

struct ScriptEditorView: View {
    @Binding var scripts: [Script]
    let onRequestUpdate: (URLRequest) -> Void
    
    @State private var selectedScriptID: Script.ID?
    @State private var isEditing = false
    @State private var editingScript = Script()
    @State private var consoleOutput = ""
    @State private var isRunning = false
    
    var selectedScript: Script? {
        scripts.first { $0.id == selectedScriptID }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                scriptList
                Divider()
                editorArea
            }
            Divider()
            ScriptConsoleView(output: consoleOutput)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private var header: some View {
        HStack {
            Text("脚本编辑器")
                .font(.headline)
            
            Spacer()
            
            Picker("脚本类型", selection: Binding(
                get: { selectedScript?.scriptType ?? .preRequest },
                set: { newType in
                    if let id = selectedScriptID, let index = scripts.firstIndex(where: { $0.id == id }) {
                        scripts[index].scriptType = newType
                    }
                }
            )) {
                ForEach(ScriptType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Button("运行") {
                runSelectedScript()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedScript == nil || isRunning)
        }
        .padding()
    }
    
    private var scriptList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedScriptID) {
                ForEach(scripts) { script in
                    ScriptRow(script: script)
                        .tag(script.id)
                        .contextMenu {
                            Button("编辑") {
                                editingScript = script
                                isEditing = true
                            }
                            Button("删除", role: .destructive) {
                                scripts.removeAll { $0.id == script.id }
                            }
                            Divider()
                            Button(script.isEnabled ? "禁用" : "启用") {
                                if let index = scripts.firstIndex(where: { $0.id == script.id }) {
                                    scripts[index].isEnabled.toggle()
                                }
                            }
                        }
                }
            }
            .listStyle(.sidebar)
            
            HStack {
                Button("添加脚本") {
                    let newScript = Script(name: "新脚本 \(scripts.count + 1)")
                    scripts.append(newScript)
                    selectedScriptID = newScript.id
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding()
        }
        .frame(width: 250)
    }
    
    private var editorArea: some View {
        VStack(spacing: 0) {
            if let script = selectedScript {
                ScriptCodeEditor(script: binding(for: script.id))
            } else {
                VStack {
                    Spacer()
                    Text("选择或创建一个脚本")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
    
    private func binding(for scriptID: Script.ID) -> Binding<Script> {
        guard let index = scripts.firstIndex(where: { $0.id == scriptID }) else {
            fatalError("Script not found")
        }
        return $scripts[index]
    }
    
    private func runSelectedScript() {
        guard let script = selectedScript else { return }
        
        isRunning = true
        consoleOutput = "运行脚本: \(script.name)\n"
        
        // 模拟执行
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            consoleOutput += "脚本执行完成\n"
            isRunning = false
        }
    }
}

struct ScriptRow: View {
    let script: Script
    
    var body: some View {
        HStack {
            Image(systemName: script.isEnabled ? "play.circle.fill" : "play.circle")
                .foregroundColor(script.isEnabled ? .green : .gray)
            
            VStack(alignment: .leading) {
                Text(script.name)
                    .font(.headline)
                Text(script.scriptType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(script.engine.displayName)
                .font(.caption2)
                .padding(4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

struct ScriptCodeEditor: View {
    @Binding var script: Script
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("脚本名称", text: $script.name)
                    .textFieldStyle(.plain)
                    .font(.headline)
                
                Picker("引擎", selection: $script.engine) {
                    ForEach(ScriptEngineType.allCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                
                Toggle("启用", isOn: $script.isEnabled)
            }
            .padding()
            
            TextEditor(text: $script.content)
                .font(.system(.body, design: .monospaced))
                .padding()
        }
    }
}
```

- [ ] **Step 2: 创建ScriptConsoleView**

```swift
import SwiftUI

struct ScriptConsoleView: View {
    let output: String
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("控制台")
                    .font(.headline)
                
                Spacer()
                
                Button(isExpanded ? "收起" : "展开") {
                    isExpanded.toggle()
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            
            if isExpanded {
                ScrollView {
                    Text(output)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(minHeight: 150)
                .background(Color.black.opacity(0.05))
            }
        }
    }
}
```

- [ ] **Step 3: 更新AppContainer集成ScriptEditor**

```swift
// 在AppContainer中添加
@State private var scripts: [Script] = []

// 在body中添加脚本编辑器标签页
```

- [ ] **Step 4: 运行应用验证UI**

Run: `./script/build_and_run.sh`
Expected: 脚本编辑器UI正常显示

- [ ] **Step 5: 提交更改**

```bash
git add Sources/MacAPITester/Features/ScriptEditor/ScriptEditorView.swift
git add Sources/MacAPITester/Features/ScriptEditor/ScriptConsoleView.swift
git add Sources/MacAPITester/App/AppContainer.swift
git commit -m "feat: 添加脚本编辑器UI"
```

---

## 验证清单

- [ ] 脚本模型正确创建
- [ ] 脚本执行引擎正常工作
- [ ] 脚本编辑器UI正常显示
- [ ] 控制台输出正常
- [ ] 所有测试通过

---

## 回滚计划

如果脚本功能失败，可以回滚：

1. 删除新增的脚本相关文件
2. 恢复AppContainer.swift
3. 重新构建和测试
