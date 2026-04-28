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