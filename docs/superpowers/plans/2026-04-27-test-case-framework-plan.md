# 测试用例框架实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现完整测试框架，支持用例集、测试套件、自动化测试流程

**Architecture:** 创建独立的测试用例模块，包含TestCaseManager和TestRunner，支持顺序/并行执行

**Tech Stack:** Swift, Foundation, SwiftUI

---

## 文件结构

### 新增文件
- `Sources/MacAPITester/Core/TestCases/TestCaseManager.swift` - 测试用例管理器
- `Sources/MacAPITester/Core/TestCases/TestRunner.swift` - 测试运行器
- `Sources/MacAPITester/Core/TestCases/TestCaseModels.swift` - 测试用例数据模型
- `Sources/MacAPITester/Features/TestCaseEditor/TestCaseEditorView.swift` - 测试用例编辑器UI
- `Sources/MacAPITester/Features/TestCaseEditor/TestSuiteEditorView.swift` - 测试套件编辑器UI
- `Sources/MacAPITester/Features/TestCaseEditor/TestRunnerView.swift` - 测试运行器UI
- `Tests/MacAPITesterTests/TestCaseManagerTests.swift` - 测试用例管理器测试
- `Tests/MacAPITesterTests/TestRunnerTests.swift` - 测试运行器测试

### 修改文件
- `Sources/MacAPITester/App/AppContainer.swift` - 集成测试用例功能
- `Sources/MacAPITester/Core/Domain/Models.swift` - 添加测试用例相关模型

---

## 任务分解

### Task 1: 创建测试用例数据模型

**Files:**
- Create: `Sources/MacAPITester/Core/TestCases/TestCaseModels.swift`

- [ ] **Step 1: 创建测试用例数据模型**

```swift
import Foundation

struct TestCase: Identifiable, Equatable, Codable {
    let id: UUID
    var requestID: UUID
    var name: String
    var description: String
    var variables: [String: String]
    var expectedStatusCode: Int?
    var expectedBodyContains: String?
    var expectedHeaders: [String: String]
    var isEnabled: Bool
    var executionOrder: Int
    
    init(
        id: UUID = UUID(),
        requestID: UUID,
        name: String = "新测试用例",
        description: String = "",
        variables: [String: String] = [:],
        expectedStatusCode: Int? = nil,
        expectedBodyContains: String? = nil,
        expectedHeaders: [String: String] = [:],
        isEnabled: Bool = true,
        executionOrder: Int = 0
    ) {
        self.id = id
        self.requestID = requestID
        self.name = name
        self.description = description
        self.variables = variables
        self.expectedStatusCode = expectedStatusCode
        self.expectedBodyContains = expectedBodyContains
        self.expectedHeaders = expectedHeaders
        self.isEnabled = isEnabled
        self.executionOrder = executionOrder
    }
}

struct TestSuite: Identifiable, Equatable, Codable {
    let id: UUID
    var projectID: UUID
    var name: String
    var description: String
    var testCaseIDs: [UUID]
    
    init(
        id: UUID = UUID(),
        projectID: UUID,
        name: String = "新测试套件",
        description: String = "",
        testCaseIDs: [UUID] = []
    ) {
        self.id = id
        self.projectID = projectID
        self.name = name
        self.description = description
        self.testCaseIDs = testCaseIDs
    }
}

enum TestStatus: String, Codable, CaseIterable {
    case passed = "passed"
    case failed = "failed"
    case error = "error"
    case skipped = "skipped"
    case pending = "pending"
    case running = "running"
    
    var displayName: String {
        switch self {
        case .passed: return "通过"
        case .failed: return "失败"
        case .error: return "错误"
        case .skipped: return "跳过"
        case .pending: return "等待"
        case .running: return "运行中"
        }
    }
    
    var color: String {
        switch self {
        case .passed: return "green"
        case .failed: return "red"
        case .error: return "orange"
        case .skipped: return "gray"
        case .pending: return "blue"
        case .running: return "yellow"
        }
    }
}

struct TestExecution: Identifiable, Codable {
    let id: UUID
    var suiteID: UUID?
    var testCaseID: UUID
    var status: TestStatus
    var responseStatusCode: Int?
    var responseTimeMs: Int?
    var errorMessage: String?
    var responseBody: String?
    var executedAt: Date
    
    init(
        id: UUID = UUID(),
        suiteID: UUID? = nil,
        testCaseID: UUID,
        status: TestStatus = .pending,
        responseStatusCode: Int? = nil,
        responseTimeMs: Int? = nil,
        errorMessage: String? = nil,
        responseBody: String? = nil,
        executedAt: Date = Date()
    ) {
        self.id = id
        self.suiteID = suiteID
        self.testCaseID = testCaseID
        self.status = status
        self.responseStatusCode = responseStatusCode
        self.responseTimeMs = responseTimeMs
        self.errorMessage = errorMessage
        self.responseBody = responseBody
        self.executedAt = executedAt
    }
}

struct TestResult: Identifiable {
    let id: UUID
    var testCase: TestCase
    var execution: TestExecution
    var passed: Bool
    var failures: [String]
    
    init(
        id: UUID = UUID(),
        testCase: TestCase,
        execution: TestExecution,
        passed: Bool = false,
        failures: [String] = []
    ) {
        self.id = id
        self.testCase = testCase
        self.execution = execution
        self.passed = passed
        self.failures = failures
    }
}

struct TestSuiteResult: Identifiable {
    let id: UUID
    var suite: TestSuite
    var results: [TestResult]
    var passedCount: Int
    var failedCount: Int
    var errorCount: Int
    var skippedCount: Int
    var totalCount: Int
    var duration: TimeInterval
    
    init(
        id: UUID = UUID(),
        suite: TestSuite,
        results: [TestResult] = [],
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.suite = suite
        self.results = results
        self.passedCount = results.filter { $0.passed }.count
        self.failedCount = results.filter { !$0.passed && $0.execution.status == .failed }.count
        self.errorCount = results.filter { $0.execution.status == .error }.count
        self.skippedCount = results.filter { $0.execution.status == .skipped }.count
        self.totalCount = results.count
        self.duration = duration
    }
    
    var passRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(passedCount) / Double(totalCount)
    }
}
```

- [ ] **Step 2: 编写测试用例模型测试**

```swift
import Testing
@testable import MacAPITester

@Suite("Test Case Models Tests")
struct TestCaseModelsTests {
    @Test func testCaseInitialization() {
        let testCase = TestCase(
            requestID: UUID(),
            name: "测试用例",
            expectedStatusCode: 200
        )
        #expect(testCase.name == "测试用例")
        #expect(testCase.expectedStatusCode == 200)
        #expect(testCase.isEnabled == true)
    }
    
    @Test func testSuiteInitialization() {
        let suite = TestSuite(
            projectID: UUID(),
            name: "测试套件"
        )
        #expect(suite.name == "测试套件")
        #expect(suite.testCaseIDs.isEmpty)
    }
    
    @Test func testStatusDisplayName() {
        #expect(TestStatus.passed.displayName == "通过")
        #expect(TestStatus.failed.displayName == "失败")
    }
    
    @Test func testSuiteResultCalculations() {
        let suite = TestSuite(projectID: UUID(), name: "测试套件")
        let results = [
            TestResult(
                testCase: TestCase(requestID: UUID(), name: "用例1"),
                execution: TestExecution(testCaseID: UUID(), status: .passed),
                passed: true
            ),
            TestResult(
                testCase: TestCase(requestID: UUID(), name: "用例2"),
                execution: TestExecution(testCaseID: UUID(), status: .failed),
                passed: false
            ),
        ]
        
        let suiteResult = TestSuiteResult(suite: suite, results: results)
        #expect(suiteResult.passedCount == 1)
        #expect(suiteResult.failedCount == 1)
        #expect(suiteResult.totalCount == 2)
        #expect(suiteResult.passRate == 0.5)
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test --filter TestCaseModelsTests`
Expected: 测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/TestCases/TestCaseModels.swift
git add Tests/MacAPITesterTests/TestCaseModelsTests.swift
git commit -m "feat: 添加测试用例数据模型"
```

### Task 2: 创建测试用例管理器

**Files:**
- Create: `Sources/MacAPITester/Core/TestCases/TestCaseManager.swift`

- [ ] **Step 1: 创建TestCaseManager类**

```swift
import Foundation

final class TestCaseManager {
    private let database: MySQLDatabase?
    private var testCases: [TestCase] = []
    private var testSuites: [TestSuite] = []
    
    init(database: MySQLDatabase? = nil) {
        self.database = database
        loadTestData()
    }
    
    private func loadTestData() {
        guard let database else { return }
        
        // 加载测试用例
        if let results = try? database.query("SELECT * FROM test_cases ORDER BY execution_order") {
            testCases = results.compactMap { row -> TestCase? in
                guard let idString = row["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let requestIDString = row["request_id"] as? String,
                      let requestID = UUID(uuidString: requestIDString),
                      let name = row["name"] as? String else {
                    return nil
                }
                
                return TestCase(
                    id: id,
                    requestID: requestID,
                    name: name,
                    description: row["description"] as? String ?? "",
                    expectedStatusCode: row["expected_status"] as? Int,
                    expectedBodyContains: row["expected_body_contains"] as? String,
                    isEnabled: (row["is_enabled"] as? Int) == 1,
                    executionOrder: row["execution_order"] as? Int ?? 0
                )
            }
        }
        
        // 加载测试套件
        if let results = try? database.query("SELECT * FROM test_suites") {
            testSuites = results.compactMap { row -> TestSuite? in
                guard let idString = row["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let projectIDString = row["project_id"] as? String,
                      let projectID = UUID(uuidString: projectIDString),
                      let name = row["name"] as? String else {
                    return nil
                }
                
                return TestSuite(
                    id: id,
                    projectID: projectID,
                    name: name,
                    description: row["description"] as? String ?? ""
                )
            }
        }
    }
    
    func createTestCase(_ testCase: TestCase) throws {
        testCases.append(testCase)
        
        guard let database else { return }
        
        try database.execute("""
            INSERT INTO test_cases (id, request_id, name, description, expected_status, expected_body_contains, is_enabled, execution_order)
            VALUES ('\(testCase.id.uuidString)', '\(testCase.requestID.uuidString)', '\(testCase.name)', '\(testCase.description)', \(testCase.expectedStatusCode.map { String($0) } ?? "NULL"), \(testCase.expectedBodyContains.map { "'\($0)'" } ?? "NULL"), \(testCase.isEnabled ? 1 : 0), \(testCase.executionOrder))
        """)
    }
    
    func updateTestCase(_ testCase: TestCase) throws {
        guard let index = testCases.firstIndex(where: { $0.id == testCase.id }) else {
            return
        }
        testCases[index] = testCase
        
        guard let database else { return }
        
        try database.execute("""
            UPDATE test_cases SET name = '\(testCase.name)', description = '\(testCase.description)', expected_status = \(testCase.expectedStatusCode.map { String($0) } ?? "NULL"), expected_body_contains = \(testCase.expectedBodyContains.map { "'\($0)'" } ?? "NULL"), is_enabled = \(testCase.isEnabled ? 1 : 0), execution_order = \(testCase.executionOrder) WHERE id = '\(testCase.id.uuidString)'
        """)
    }
    
    func deleteTestCase(id: UUID) throws {
        testCases.removeAll { $0.id == id }
        
        guard let database else { return }
        try database.execute("DELETE FROM test_cases WHERE id = '\(id.uuidString)'")
    }
    
    func createTestSuite(_ suite: TestSuite) throws {
        testSuites.append(suite)
        
        guard let database else { return }
        
        try database.execute("""
            INSERT INTO test_suites (id, project_id, name, description)
            VALUES ('\(suite.id.uuidString)', '\(suite.projectID.uuidString)', '\(suite.name)', '\(suite.description)')
        """)
    }
    
    func updateTestSuite(_ suite: TestSuite) throws {
        guard let index = testSuites.firstIndex(where: { $0.id == suite.id }) else {
            return
        }
        testSuites[index] = suite
        
        guard let database else { return }
        
        try database.execute("""
            UPDATE test_suites SET name = '\(suite.name)', description = '\(suite.description)' WHERE id = '\(suite.id.uuidString)'
        """)
    }
    
    func deleteTestSuite(id: UUID) throws {
        testSuites.removeAll { $0.id == id }
        
        guard let database else { return }
        try database.execute("DELETE FROM test_suites WHERE id = '\(id.uuidString)'")
    }
    
    func addTestCaseToSuite(testCaseID: UUID, suiteID: UUID) throws {
        guard let suiteIndex = testSuites.firstIndex(where: { $0.id == suiteID }) else {
            return
        }
        
        if !testSuites[suiteIndex].testCaseIDs.contains(testCaseID) {
            testSuites[suiteIndex].testCaseIDs.append(testCaseID)
        }
        
        guard let database else { return }
        
        try database.execute("""
            INSERT INTO suite_test_cases (suite_id, test_case_id) VALUES ('\(suiteID.uuidString)', '\(testCaseID.uuidString)')
        """)
    }
    
    func removeTestCaseFromSuite(testCaseID: UUID, suiteID: UUID) throws {
        guard let suiteIndex = testSuites.firstIndex(where: { $0.id == suiteID }) else {
            return
        }
        
        testSuites[suiteIndex].testCaseIDs.removeAll { $0 == testCaseID }
        
        guard let database else { return }
        
        try database.execute("""
            DELETE FROM suite_test_cases WHERE suite_id = '\(suiteID.uuidString)' AND test_case_id = '\(testCaseID.uuidString)'
        """)
    }
    
    func getTestCases(for requestID: UUID) -> [TestCase] {
        testCases.filter { $0.requestID == requestID }
    }
    
    func getTestCases(for suiteID: UUID) -> [TestCase] {
        guard let suite = testSuites.first(where: { $0.id == suiteID }) else {
            return []
        }
        return suite.testCaseIDs.compactMap { id in
            testCases.first { $0.id == id }
        }
    }
    
    func getTestSuites(for projectID: UUID) -> [TestSuite] {
        testSuites.filter { $0.projectID == projectID }
    }
    
    func exportTestCase(id: UUID) throws -> Data? {
        guard let testCase = testCases.first(where: { $0.id == id }) else {
            return nil
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(testCase)
    }
    
    func importTestCase(from data: Data, requestID: UUID) throws -> TestCase {
        let decoder = JSONDecoder()
        var testCase = try decoder.decode(TestCase.self, from: data)
        testCase.requestID = requestID
        try createTestCase(testCase)
        return testCase
    }
}
```

- [ ] **Step 2: 编写测试用例管理器测试**

```swift
import Testing
@testable import MacAPITester

@Suite("Test Case Manager Tests")
struct TestCaseManagerTests {
    @Test func createsAndRetrievesTestCase() throws {
        let manager = TestCaseManager()
        let requestID = UUID()
        let testCase = TestCase(requestID: requestID, name: "测试用例")
        
        try manager.createTestCase(testCase)
        
        let retrieved = manager.getTestCases(for: requestID)
        #expect(retrieved.count == 1)
        #expect(retrieved.first?.name == "测试用例")
    }
    
    @Test func createsAndManagesTestSuite() throws {
        let manager = TestCaseManager()
        let projectID = UUID()
        let suite = TestSuite(projectID: projectID, name: "测试套件")
        
        try manager.createTestSuite(suite)
        
        let suites = manager.getTestSuites(for: projectID)
        #expect(suites.count == 1)
        #expect(suites.first?.name == "测试套件")
    }
    
    @Test func addsTestCaseToSuite() throws {
        let manager = TestCaseManager()
        let requestID = UUID()
        let projectID = UUID()
        
        let testCase = TestCase(requestID: requestID, name: "测试用例")
        try manager.createTestCase(testCase)
        
        let suite = TestSuite(projectID: projectID, name: "测试套件")
        try manager.createTestSuite(suite)
        
        try manager.addTestCaseToSuite(testCaseID: testCase.id, suiteID: suite.id)
        
        let testCases = manager.getTestCases(for: suite.id)
        #expect(testCases.count == 1)
        #expect(testCases.first?.name == "测试用例")
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test --filter TestCaseManagerTests`
Expected: 测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/TestCases/TestCaseManager.swift
git add Tests/MacAPITesterTests/TestCaseManagerTests.swift
git commit -m "feat: 添加测试用例管理器"
```

### Task 3: 创建测试运行器

**Files:**
- Create: `Sources/MacAPITester/Core/TestCases/TestRunner.swift`

- [ ] **Step 1: 创建TestRunner类**

```swift
import Foundation

protocol TestRunnerDelegate: AnyObject {
    func testRunner(_ runner: TestRunner, didStartTestCase testCase: TestCase)
    func testRunner(_ runner: TestRunner, didCompleteTestCase testCase: TestCase, result: TestResult)
    func testRunner(_ runner: TestRunner, didCompleteSuite result: TestSuiteResult)
}

final class TestRunner {
    weak var delegate: TestRunnerDelegate?
    
    private let httpClient: HTTPClient
    private let testCaseManager: TestCaseManager
    private let scriptEngine: ScriptEngine
    private var isRunning = false
    
    init(
        httpClient: HTTPClient = HTTPClient(),
        testCaseManager: TestCaseManager,
        scriptEngine: ScriptEngine = ScriptEngine()
    ) {
        self.httpClient = httpClient
        self.testCaseManager = testCaseManager
        self.scriptEngine = scriptEngine
    }
    
    func runTestCase(_ testCase: TestCase, request: URLRequest, scripts: [Script] = []) async throws -> TestResult {
        delegate?.testRunner(self, didStartTestCase: testCase)
        
        var currentRequest = request
        var variables = testCase.variables
        
        // 执行前脚本
        let preScripts = scripts.filter { $0.scriptType == .preRequest }
        if !preScripts.isEmpty {
            let context = ScriptExecutionContext(request: currentRequest, variables: variables)
            let result = try scriptEngine.executeScripts(preScripts, context: context)
            
            if let modifiedRequest = result.modifiedRequest {
                currentRequest = modifiedRequest
            }
            if let modifiedVariables = result.modifiedVariables {
                variables = modifiedVariables
            }
        }
        
        // 应用变量到请求
        applyVariables(&currentRequest, variables: variables)
        
        // 执行请求
        let startTime = Date()
        let response = try await httpClient.send(currentRequest)
        let duration = Date().timeIntervalSince(startTime)
        
        // 执行后脚本
        let postScripts = scripts.filter { $0.scriptType == .postResponse }
        if !postScripts.isEmpty {
            let httpResponse = HTTPURLResponse(
                url: currentRequest.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            )!
            let context = ScriptExecutionContext(
                request: currentRequest,
                response: httpResponse,
                responseBody: response.body,
                variables: variables
            )
            _ = try scriptEngine.executeScripts(postScripts, context: context)
        }
        
        // 验证响应
        var failures: [String] = []
        
        if let expectedStatus = testCase.expectedStatusCode, expectedStatus != response.statusCode {
            failures.append("期望状态码 \(expectedStatus)，实际 \(response.statusCode)")
        }
        
        if let expectedBody = testCase.expectedBodyContains {
            let bodyString = String(data: response.body, encoding: .utf8) ?? ""
            if !bodyString.contains(expectedBody) {
                failures.append("响应体不包含期望内容: \(expectedBody)")
            }
        }
        
        for (headerName, expectedValue) in testCase.expectedHeaders {
            if let actualValue = response.headers[headerName], actualValue != expectedValue {
                failures.append("Header \(headerName) 期望值 \(expectedValue)，实际 \(actualValue)")
            }
        }
        
        let execution = TestExecution(
            testCaseID: testCase.id,
            status: failures.isEmpty ? .passed : .failed,
            responseStatusCode: response.statusCode,
            responseTimeMs: Int(duration * 1000),
            errorMessage: failures.isEmpty ? nil : failures.joined(separator: "\n"),
            responseBody: String(data: response.body, encoding: .utf8)
        )
        
        let result = TestResult(
            testCase: testCase,
            execution: execution,
            passed: failures.isEmpty,
            failures: failures
        )
        
        delegate?.testRunner(self, didCompleteTestCase: testCase, result: result)
        return result
    }
    
    func runTestSuite(_ suite: TestSuite, requests: [UUID: URLRequest], scripts: [UUID: [Script]] = [:], concurrency: Int = 1) async throws -> TestSuiteResult {
        let testCases = testCaseManager.getTestCases(for: suite.id)
            .filter { $0.isEnabled }
            .sorted { $0.executionOrder < $1.executionOrder }
        
        var results: [TestResult] = []
        let startTime = Date()
        
        if concurrency <= 1 {
            // 顺序执行
            for testCase in testCases {
                guard let request = requests[testCase.requestID] else {
                    let execution = TestExecution(
                        testCaseID: testCase.id,
                        status: .error,
                        errorMessage: "找不到对应的请求"
                    )
                    let result = TestResult(
                        testCase: testCase,
                        execution: execution,
                        passed: false,
                        failures: ["找不到对应的请求"]
                    )
                    results.append(result)
                    continue
                }
                
                let result = try await runTestCase(testCase, request: request, scripts: scripts[testCase.requestID] ?? [])
                results.append(result)
            }
        } else {
            // 并行执行
            results = try await withThrowingTaskGroup(of: TestResult.self) { group in
                var collectedResults: [TestResult] = []
                
                for testCase in testCases {
                    group.addTask {
                        guard let request = requests[testCase.requestID] else {
                            let execution = TestExecution(
                                testCaseID: testCase.id,
                                status: .error,
                                errorMessage: "找不到对应的请求"
                            )
                            return TestResult(
                                testCase: testCase,
                                execution: execution,
                                passed: false,
                                failures: ["找不到对应的请求"]
                            )
                        }
                        
                        return try await self.runTestCase(testCase, request: request, scripts: scripts[testCase.requestID] ?? [])
                    }
                }
                
                for try await result in group {
                    collectedResults.append(result)
                }
                
                return collectedResults
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let suiteResult = TestSuiteResult(suite: suite, results: results, duration: duration)
        
        delegate?.testRunner(self, didCompleteSuite: suiteResult)
        return suiteResult
    }
    
    private func applyVariables(_ request: inout URLRequest, variables: [String: String]) {
        guard let url = request.url else { return }
        
        var urlString = url.absoluteString
        for (key, value) in variables {
            urlString = urlString.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        if let newURL = URL(string: urlString) {
            request.url = newURL
        }
    }
}
```

- [ ] **Step 2: 编写测试运行器测试**

```swift
import Testing
@testable import MacAPITester

@Suite("Test Runner Tests")
struct TestRunnerTests {
    @Test func runsTestCaseSuccessfully() async throws {
        let manager = TestCaseManager()
        let runner = TestRunner(testCaseManager: manager)
        
        let testCase = TestCase(
            requestID: UUID(),
            name: "测试用例",
            expectedStatusCode: 200
        )
        
        let request = URLRequest(url: URL(string: "https://httpbin.org/get")!)
        
        let result = try await runner.runTestCase(testCase, request: request)
        
        #expect(result.execution.status == .passed)
        #expect(result.passed == true)
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test --filter TestRunnerTests`
Expected: 测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/TestCases/TestRunner.swift
git add Tests/MacAPITesterTests/TestRunnerTests.swift
git commit -m "feat: 添加测试运行器"
```

### Task 4: 创建测试用例编辑器UI

**Files:**
- Create: `Sources/MacAPITester/Features/TestCaseEditor/TestCaseEditorView.swift`
- Create: `Sources/MacAPITester/Features/TestCaseEditor/TestSuiteEditorView.swift`
- Create: `Sources/MacAPITester/Features/TestCaseEditor/TestRunnerView.swift`

- [ ] **Step 1: 创建TestCaseEditorView**

```swift
import SwiftUI

struct TestCaseEditorView: View {
    @Binding var testCases: [TestCase]
    let requestID: UUID
    
    @State private var selectedTestCaseID: TestCase.ID?
    @State private var isEditing = false
    @State private var editingTestCase = TestCase(requestID: UUID())
    
    var filteredTestCases: [TestCase] {
        testCases.filter { $0.requestID == requestID }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            testCaseList
            Divider()
            footer
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private var header: some View {
        HStack {
            Text("测试用例")
                .font(.headline)
            
            Spacer()
            
            Button("添加用例") {
                editingTestCase = TestCase(requestID: requestID)
                isEditing = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var testCaseList: some View {
        List(selection: $selectedTestCaseID) {
            ForEach(filteredTestCases) { testCase in
                TestCaseRow(testCase: testCase)
                    .tag(testCase.id)
                    .contextMenu {
                        Button("编辑") {
                            editingTestCase = testCase
                            isEditing = true
                        }
                        Button("删除", role: .destructive) {
                            testCases.removeAll { $0.id == testCase.id }
                        }
                        Divider()
                        Button(testCase.isEnabled ? "禁用" : "启用") {
                            if let index = testCases.firstIndex(where: { $0.id == testCase.id }) {
                                testCases[index].isEnabled.toggle()
                            }
                        }
                    }
            }
        }
        .listStyle(.inset)
    }
    
    private var footer: some View {
        HStack {
            Text("共 \(filteredTestCases.count) 个用例")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $isEditing) {
            TestCaseEditSheet(
                testCase: $editingTestCase,
                onSave: { testCase in
                    if let index = testCases.firstIndex(where: { $0.id == testCase.id }) {
                        testCases[index] = testCase
                    } else {
                        testCases.append(testCase)
                    }
                    isEditing = false
                },
                onCancel: {
                    isEditing = false
                }
            )
        }
    }
}

struct TestCaseRow: View {
    let testCase: TestCase
    
    var body: some View {
        HStack {
            Image(systemName: testCase.isEnabled ? "checkmark.circle.fill" : "checkmark.circle")
                .foregroundColor(testCase.isEnabled ? .green : .gray)
            
            VStack(alignment: .leading) {
                Text(testCase.name)
                    .font(.headline)
                Text(testCase.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let statusCode = testCase.expectedStatusCode {
                Text("期望: \(statusCode)")
                    .font(.caption)
                    .padding(4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TestCaseEditSheet: View {
    @Binding var testCase: TestCase
    let onSave: (TestCase) -> Void
    let onCancel: () -> Void
    
    @State private var variablesText = ""
    @State private var expectedHeadersText = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("编辑测试用例")
                .font(.headline)
            
            Form {
                TextField("名称", text: $testCase.name)
                TextField("描述", text: $testCase.description)
                
                Section("变量") {
                    TextEditor(text: $variablesText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                }
                
                Section("期望") {
                    TextField("状态码", value: $testCase.expectedStatusCode, format: .number)
                    TextField("响应体包含", text: Binding(
                        get: { testCase.expectedBodyContains ?? "" },
                        set: { testCase.expectedBodyContains = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextEditor(text: $expectedHeadersText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80)
                }
                
                Toggle("启用", isOn: $testCase.isEnabled)
            }
            
            HStack {
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("保存") {
                    testCase.variables = parseVariables(variablesText)
                    testCase.expectedHeaders = parseHeaders(expectedHeadersText)
                    onSave(testCase)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500)
        .onAppear {
            variablesText = formatVariables(testCase.variables)
            expectedHeadersText = formatHeaders(testCase.expectedHeaders)
        }
    }
    
    private func parseVariables(_ text: String) -> [String: String] {
        var variables: [String: String] = [:]
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: "=")
            if parts.count == 2 {
                variables[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return variables
    }
    
    private func parseHeaders(_ text: String) -> [String: String] {
        var headers: [String: String] = [:]
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: ":")
            if parts.count == 2 {
                headers[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return headers
    }
    
    private func formatVariables(_ variables: [String: String]) -> String {
        variables.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
    }
    
    private func formatHeaders(_ headers: [String: String]) -> String {
        headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }
}
```

- [ ] **Step 2: 创建TestSuiteEditorView**

```swift
import SwiftUI

struct TestSuiteEditorView: View {
    @Binding var testSuites: [TestSuite]
    let projectID: UUID
    let testCaseManager: TestCaseManager
    
    @State private var selectedSuiteID: TestSuite.ID?
    @State private var isEditing = false
    @State private var editingSuite = TestSuite(projectID: UUID())
    
    var filteredSuites: [TestSuite] {
        testSuites.filter { $0.projectID == projectID }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            suiteList
            Divider()
            footer
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private var header: some View {
        HStack {
            Text("测试套件")
                .font(.headline)
            
            Spacer()
            
            Button("添加套件") {
                editingSuite = TestSuite(projectID: projectID)
                isEditing = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var suiteList: some View {
        List(selection: $selectedSuiteID) {
            ForEach(filteredSuites) { suite in
                TestSuiteRow(suite: suite, testCaseManager: testCaseManager)
                    .tag(suite.id)
                    .contextMenu {
                        Button("编辑") {
                            editingSuite = suite
                            isEditing = true
                        }
                        Button("删除", role: .destructive) {
                            testSuites.removeAll { $0.id == suite.id }
                        }
                    }
            }
        }
        .listStyle(.inset)
    }
    
    private var footer: some View {
        HStack {
            Text("共 \(filteredSuites.count) 个套件")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $isEditing) {
            TestSuiteEditSheet(
                suite: $editingSuite,
                testCaseManager: testCaseManager,
                onSave: { suite in
                    if let index = testSuites.firstIndex(where: { $0.id == suite.id }) {
                        testSuites[index] = suite
                    } else {
                        testSuites.append(suite)
                    }
                    isEditing = false
                },
                onCancel: {
                    isEditing = false
                }
            )
        }
    }
}

struct TestSuiteRow: View {
    let suite: TestSuite
    let testCaseManager: TestCaseManager
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(suite.name)
                    .font(.headline)
                Text(suite.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("\(suite.testCaseIDs.count) 个用例")
                .font(.caption)
                .padding(4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

struct TestSuiteEditSheet: View {
    @Binding var suite: TestSuite
    let testCaseManager: TestCaseManager
    let onSave: (TestSuite) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("编辑测试套件")
                .font(.headline)
            
            Form {
                TextField("名称", text: $suite.name)
                TextField("描述", text: $suite.description)
            }
            
            HStack {
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("保存") {
                    onSave(suite)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
```

- [ ] **Step 3: 创建TestRunnerView**

```swift
import SwiftUI

struct TestRunnerView: View {
    let testSuites: [TestSuite]
    let testCaseManager: TestCaseManager
    let requests: [RequestDocument]
    
    @State private var selectedSuiteID: TestSuite.ID?
    @State private var isRunning = false
    @State private var results: [TestSuiteResult] = []
    @State private var currentResult: TestSuiteResult?
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private var header: some View {
        HStack {
            Text("测试运行器")
                .font(.headline)
            
            Spacer()
            
            Picker("选择套件", selection: $selectedSuiteID) {
                Text("请选择").tag(nil as TestSuite.ID?)
                ForEach(testSuites) { suite in
                    Text(suite.name).tag(suite.id as TestSuite.ID?)
                }
            }
            .frame(width: 200)
            
            Button("运行") {
                runSelectedSuite()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedSuiteID == nil || isRunning)
        }
        .padding()
    }
    
    private var content: some View {
        HSplitView {
            resultListView
                .frame(minWidth: 300)
            
            detailView
                .frame(minWidth: 400)
        }
    }
    
    private var resultListView: some View {
        VStack(spacing: 0) {
            List(selection: Binding(
                get: { currentResult?.id },
                set: { id in
                    currentResult = results.first { $0.id == id }
                }
            )) {
                ForEach(results) { result in
                    TestSuiteResultRow(result: result)
                        .tag(result.id)
                }
            }
            .listStyle(.inset)
        }
    }
    
    private var detailView: some View {
        VStack(spacing: 0) {
            if let result = currentResult {
                TestSuiteDetailView(result: result)
            } else {
                VStack {
                    Spacer()
                    Text("选择一个测试结果查看详情")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
    
    private func runSelectedSuite() {
        guard let suiteID = selectedSuiteID,
              let suite = testSuites.first(where: { $0.id == suiteID }) else {
            return
        }
        
        isRunning = true
        
        Task {
            let runner = TestRunner(testCaseManager: testCaseManager)
            
            // 准备请求
            var requestsMap: [UUID: URLRequest] = [:]
            for request in requests {
                if let url = URL(string: request.urlString) {
                    requestsMap[request.id] = URLRequest(url: url)
                }
            }
            
            do {
                let result = try await runner.runTestSuite(suite, requests: requestsMap)
                results.append(result)
                currentResult = result
            } catch {
                print("测试执行失败: \(error)")
            }
            
            isRunning = false
        }
    }
}

struct TestSuiteResultRow: View {
    let result: TestSuiteResult
    
    var body: some View {
        HStack {
            Image(systemName: result.failedCount > 0 ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(result.failedCount > 0 ? .red : .green)
            
            VStack(alignment: .leading) {
                Text(result.suite.name)
                    .font(.headline)
                Text("\(result.passedCount)/\(result.totalCount) 通过")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.2fs", result.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct TestSuiteDetailView: View {
    let result: TestSuiteResult
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            resultList
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(result.suite.name)
                    .font(.headline)
                Text("通过率: \(String(format: "%.1f%%", result.passRate * 100))")
                    .font(.caption)
                    .foregroundColor(result.failedCount > 0 ? .red : .green)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                StatBadge(label: "通过", count: result.passedCount, color: .green)
                StatBadge(label: "失败", count: result.failedCount, color: .red)
                StatBadge(label: "错误", count: result.errorCount, color: .orange)
                StatBadge(label: "跳过", count: result.skippedCount, color: .gray)
            }
        }
        .padding()
    }
    
    private var resultList: some View {
        List(result.results) { testResult in
            TestResultRow(result: testResult)
        }
        .listStyle(.inset)
    }
}

struct StatBadge: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
        }
        .frame(width: 60)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct TestResultRow: View {
    let result: TestResult
    
    var body: some View {
        HStack {
            Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.passed ? .green : .red)
            
            VStack(alignment: .leading) {
                Text(result.testCase.name)
                    .font(.headline)
                if let error = result.execution.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if let statusCode = result.execution.responseStatusCode {
                Text("\(statusCode)")
                    .font(.caption)
                    .padding(4)
                    .background(result.passed ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(4)
            }
            
            if let responseTime = result.execution.responseTimeMs {
                Text("\(responseTime)ms")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 4: 更新AppContainer集成TestCaseEditor**

```swift
// 在AppContainer中添加
@State private var testCases: [TestCase] = []
@State private var testSuites: [TestSuite] = []
private let testCaseManager: TestCaseManager

init() {
    // ... 现有代码
    self.testCaseManager = TestCaseManager()
}

// 在body中添加测试用例编辑器标签页
```

- [ ] **Step 5: 运行应用验证UI**

Run: `./script/build_and_run.sh`
Expected: 测试用例编辑器UI正常显示

- [ ] **Step 6: 提交更改**

```bash
git add Sources/MacAPITester/Features/TestCaseEditor/TestCaseEditorView.swift
git add Sources/MacAPITester/Features/TestCaseEditor/TestSuiteEditorView.swift
git add Sources/MacAPITester/Features/TestCaseEditor/TestRunnerView.swift
git add Sources/MacAPITester/App/AppContainer.swift
git commit -m "feat: 添加测试用例编辑器UI"
```

---

## 验证清单

- [ ] 测试用例模型正确创建
- [ ] 测试用例管理器正常工作
- [ ] 测试运行器正常执行
- [ ] 测试用例编辑器UI正常显示
- [ ] 测试套件编辑器UI正常显示
- [ ] 测试运行器UI正常显示
- [ ] 所有测试通过

---

## 回滚计划

如果测试用例功能失败，可以回滚：

1. 删除新增的测试用例相关文件
2. 恢复AppContainer.swift
3. 重新构建和测试
