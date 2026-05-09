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
                        .foregroundStyle(.secondary)
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

        Task { @MainActor in
            let runner = TestRunner(testCaseManager: testCaseManager)

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
                .foregroundStyle(result.failedCount > 0 ? .red : .green)

            VStack(alignment: .leading) {
                Text(result.suite.name)
                    .font(.headline)
                Text("\(result.passedCount)/\(result.totalCount) 通过")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.2fs", result.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
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
                    .foregroundStyle(result.failedCount > 0 ? .red : .green)
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
                .foregroundStyle(result.passed ? .green : .red)

            VStack(alignment: .leading) {
                Text(result.testCase.name)
                    .font(.headline)
                if let error = result.execution.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
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
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}