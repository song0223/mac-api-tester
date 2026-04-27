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
        
        applyVariables(&currentRequest, variables: variables)
        
        let startTime = Date()
        let response = try await httpClient.send(currentRequest)
        let duration = Date().timeIntervalSince(startTime)
        
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
        let testCases = testCaseManager.getTestCases(in: suite.id)
            .filter { $0.isEnabled }
            .sorted { $0.executionOrder < $1.executionOrder }
        
        var results: [TestResult] = []
        let startTime = Date()
        
        if concurrency <= 1 {
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
            results = try await withThrowingTaskGroup(of: TestResult.self) { group in
                var collectedResults: [TestResult] = []
                
                for testCase in testCases {
                    group.addTask { [httpClient] in
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
                        
                        let testCaseScripts = scripts[testCase.requestID] ?? []
                        
                        var currentRequest = request
                        var variables = testCase.variables
                        
                        let taskScriptEngine = ScriptEngine()
                        
                        let preScripts = testCaseScripts.filter { $0.scriptType == .preRequest }
                        if !preScripts.isEmpty {
                            let context = ScriptExecutionContext(request: currentRequest, variables: variables)
                            let result = try taskScriptEngine.executeScripts(preScripts, context: context)
                            
                            if let modifiedRequest = result.modifiedRequest {
                                currentRequest = modifiedRequest
                            }
                            if let modifiedVariables = result.modifiedVariables {
                                variables = modifiedVariables
                            }
                        }
                        
                        var urlString = currentRequest.url?.absoluteString ?? ""
                        for (key, value) in variables {
                            urlString = urlString.replacingOccurrences(of: "{{\(key)}}", with: value)
                        }
                        if let newURL = URL(string: urlString) {
                            currentRequest.url = newURL
                        }
                        
                        let startTime = Date()
                        let response = try await httpClient.send(currentRequest)
                        let duration = Date().timeIntervalSince(startTime)
                        
                        let postScripts = testCaseScripts.filter { $0.scriptType == .postResponse }
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
                            _ = try taskScriptEngine.executeScripts(postScripts, context: context)
                        }
                        
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
                        
                        return TestResult(
                            testCase: testCase,
                            execution: execution,
                            passed: failures.isEmpty,
                            failures: failures
                        )
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
