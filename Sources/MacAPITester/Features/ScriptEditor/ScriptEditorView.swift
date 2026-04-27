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
