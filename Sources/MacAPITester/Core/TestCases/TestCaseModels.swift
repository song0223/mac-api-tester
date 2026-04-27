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
