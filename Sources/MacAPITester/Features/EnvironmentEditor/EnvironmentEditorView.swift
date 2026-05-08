import SwiftUI

struct EnvironmentEditorView: View {
    @Binding var environments: [Environment]
    @Binding var activeEnvironmentID: UUID?
    let onSave: () -> Void

    @State private var selectedEnvironmentID: UUID?
    @State private var newEnvironmentName = ""
    @State private var showingAddAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("环境变量")
                        .font(.system(size: 16, weight: .semibold))
                    Text("管理不同环境的变量配置")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    newEnvironmentName = "环境 \(environments.count + 1)"
                    showingAddAlert = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("新建环境")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            HStack(spacing: 0) {
                environmentList
                Divider()
                variableEditor
            }
        }
        .frame(minWidth: 720, minHeight: 500)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("新建环境", isPresented: $showingAddAlert) {
            TextField("环境名称", text: $newEnvironmentName)
            Button("取消", role: .cancel) {}
            Button("创建") {
                addEnvironment(name: newEnvironmentName)
            }
            .disabled(newEnvironmentName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("请输入环境名称")
        }
    }

    private var environmentList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedEnvironmentID) {
                ForEach(environments) { env in
                    HStack(spacing: 10) {
                        Image(systemName: env.isActive ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13))
                            .foregroundStyle(env.isActive ? .green : Color.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(env.name)
                                .font(.system(size: 13, weight: env.isActive ? .semibold : .regular))
                                .lineLimit(1)
                            Text("\(env.variables.filter { $0.enabled }.count) 个变量")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .tag(env.id)
                    .contextMenu {
                        Button(env.isActive ? "取消激活" : "设为激活") {
                            setActiveEnvironment(env.id)
                        }
                        Divider()
                        Button("删除", role: .destructive) {
                            deleteEnvironment(env.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 200)
    }

    @ViewBuilder
    private var variableEditor: some View {
        if let envID = selectedEnvironmentID,
           let envIndex = environments.firstIndex(where: { $0.id == envID }) {
            VariableEditorView(
                environment: $environments[envIndex],
                onSave: onSave
            )
        } else {
            VStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.secondary)
                Text("选择一个环境")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func addEnvironment(name: String) {
        let env = Environment(name: name, isActive: environments.isEmpty)
        environments.append(env)
        selectedEnvironmentID = env.id
        if environments.count == 1 {
            activeEnvironmentID = env.id
        }
        onSave()
    }

    private func setActiveEnvironment(_ id: UUID) {
        for i in environments.indices {
            environments[i].isActive = (environments[i].id == id)
        }
        activeEnvironmentID = id
        onSave()
    }

    private func deleteEnvironment(_ id: UUID) {
        environments.removeAll { $0.id == id }
        if activeEnvironmentID == id {
            activeEnvironmentID = environments.first?.id
            if let newActive = activeEnvironmentID {
                for i in environments.indices {
                    environments[i].isActive = (environments[i].id == newActive)
                }
            }
        }
        if selectedEnvironmentID == id {
            selectedEnvironmentID = nil
        }
        onSave()
    }
}

struct VariableEditorView: View {
    @Binding var environment: Environment
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("环境名称", text: $environment.name)
                    .inputFieldStyle()
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: 200)
                    .onChange(of: environment.name) { _, _ in
                        onSave()
                    }

                Spacer()

                Button {
                    environment.variables.append(EnvironmentVariable())
                    onSave()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("添加变量")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.quaternary.opacity(0.5), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            // Variable list
            if environment.variables.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.secondary)
                    Text("暂无变量")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("点击上方「添加变量」开始配置")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                Table(environment.variables) {
                    TableColumn("启用") { variable in
                        if let index = environment.variables.firstIndex(where: { $0.id == variable.id }) {
                            Toggle("", isOn: $environment.variables[index].enabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .onChange(of: environment.variables[index].enabled) { _, _ in
                                    onSave()
                                }
                        }
                    }
                    .width(44)

                    TableColumn("变量名") { variable in
                        if let index = environment.variables.firstIndex(where: { $0.id == variable.id }) {
                            TextField("key", text: $environment.variables[index].key)
                                .inputFieldStyle()
                                .font(.system(size: 12, design: .monospaced))
                                .onChange(of: environment.variables[index].key) { _, _ in
                                    onSave()
                                }
                        }
                    }

                    TableColumn("值") { variable in
                        if let index = environment.variables.firstIndex(where: { $0.id == variable.id }) {
                            TextField("value", text: $environment.variables[index].value)
                                .inputFieldStyle()
                                .font(.system(size: 12, design: .monospaced))
                                .onChange(of: environment.variables[index].value) { _, _ in
                                    onSave()
                                }
                        }
                    }

                    TableColumn("") { variable in
                        if let index = environment.variables.firstIndex(where: { $0.id == variable.id }) {
                            Button(role: .destructive) {
                                environment.variables.remove(at: index)
                                onSave()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .width(32)
                }
            }
        }
    }
}
