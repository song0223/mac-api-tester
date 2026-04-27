import Testing
import Foundation
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
