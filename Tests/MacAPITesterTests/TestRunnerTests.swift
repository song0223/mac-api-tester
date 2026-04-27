import Testing
import Foundation
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
