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
                .foregroundStyle(.secondary)

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
                .foregroundStyle(.blue)

            VStack(alignment: .leading) {
                Text(suite.name)
                    .font(.headline)
                Text(suite.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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