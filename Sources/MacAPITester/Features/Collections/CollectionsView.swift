import SwiftUI

struct CollectionsView: View {
    let projects: [RequestProject]
    @Binding var selectedProjectID: RequestProject.ID?
    let requests: [RequestDocument]
    @Binding var selectedRequestID: RequestDocument.ID?
    let requestCountByProject: [RequestProject.ID: Int]
    let onAddProject: () -> Void
    let onDeleteProject: (RequestProject.ID) -> Void
    let onRenameProject: (RequestProject.ID, String) -> Void
    let onAddRequest: () -> Void
    let onDeleteRequest: (RequestDocument.ID) -> Void

    @State private var searchText = ""
    @State private var editingProjectID: RequestProject.ID?
    @State private var editingProjectName = ""
    @State private var pendingDeleteRequest: RequestDocument?
    @State private var pendingDeleteProject: RequestProject?

    private var requestsInSelectedProject: [RequestDocument] {
        guard let selectedProjectID else { return [] }
        return requests.filter { $0.projectID == selectedProjectID }
    }

    private var filteredRequests: [RequestDocument] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return requestsInSelectedProject }
        return requestsInSelectedProject.filter {
            $0.name.localizedCaseInsensitiveContains(keyword) || $0.urlString.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            projectSection

            Divider()
                .padding(.top, 8)

            HStack(spacing: 8) {
                TextField("搜索接口", text: $searchText)
                    .inputFieldStyle()

                Button(action: onAddRequest) {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .pointingHandCursor()
                .help("新增接口")
                .disabled(selectedProjectID == nil)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List(selection: $selectedRequestID) {
                if selectedProjectID == nil {
                    Text("请先创建并选择一个项目")
                        .foregroundStyle(.secondary)
                } else if filteredRequests.isEmpty {
                    Text("当前项目暂无接口")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredRequests) { request in
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.blue)

                            Text(request.name)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text(request.method.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(request.method == .post ? Color.orange.opacity(0.2) : Color.green.opacity(0.2), in: Capsule())

                            Button {
                                pendingDeleteRequest = request
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.borderless)
                            .pointingHandCursor()
                            .help("删除接口")
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                        .pointingHandCursor()
                        .tag(request.id)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 260)
        .confirmationDialog(
            "确认删除接口？",
            isPresented: Binding(
                get: { pendingDeleteRequest != nil },
                set: { if !$0 { pendingDeleteRequest = nil } }
            ),
            presenting: pendingDeleteRequest
        ) { request in
            Button("删除 \(request.name)", role: .destructive) {
                onDeleteRequest(request.id)
                pendingDeleteRequest = nil
            }
            Button("取消", role: .cancel) {
                pendingDeleteRequest = nil
            }
        } message: { request in
            Text("删除后不可恢复。接口：\(request.name)")
        }
        .confirmationDialog(
            "确认删除项目？",
            isPresented: Binding(
                get: { pendingDeleteProject != nil },
                set: { if !$0 { pendingDeleteProject = nil } }
            ),
            presenting: pendingDeleteProject
        ) { project in
            Button("删除 \(project.name)", role: .destructive) {
                onDeleteProject(project.id)
                pendingDeleteProject = nil
            }
            Button("取消", role: .cancel) {
                pendingDeleteProject = nil
            }
        } message: { _ in
            Text("会同时删除该项目下所有接口，且不可恢复。")
        }
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("项目")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: onAddProject) {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .pointingHandCursor()
                .help("新增项目")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(projects) { project in
                        let isSelected = project.id == selectedProjectID
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isSelected ? .blue : .secondary)
                            if editingProjectID == project.id {
                                HStack(spacing: 6) {
                                    TextField("项目名称", text: $editingProjectName)
                                        .inputFieldStyle()
                                        .font(.system(size: 12, weight: .semibold))
                                        .onSubmit {
                                            commitProjectRename(projectID: project.id)
                                        }

                                    Button {
                                        commitProjectRename(projectID: project.id)
                                    } label: {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.green)
                                    }
                                    .buttonStyle(.borderless)
                                    .pointingHandCursor()
                                    .help("确认修改")

                                    Button {
                                        cancelProjectRename()
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                    .pointingHandCursor()
                                    .help("取消修改")
                                }
                            } else {
                                Text(project.name)
                                    .lineLimit(1)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            }
                            Spacer(minLength: 4)
                            Text("\(requestCountByProject[project.id, default: 0])")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Button {
                                startEditingProject(project)
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .pointingHandCursor()
                            .help("重命名项目")
                            Button {
                                pendingDeleteProject = project
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .pointingHandCursor()
                            .help("删除项目")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ? Color.blue.opacity(0.12) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedProjectID = project.id
                        }
                        .pointingHandCursor()
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private func startEditingProject(_ project: RequestProject) {
        selectedProjectID = project.id
        editingProjectID = project.id
        editingProjectName = project.name
    }

    private func cancelProjectRename() {
        editingProjectID = nil
        editingProjectName = ""
    }

    private func commitProjectRename(projectID: RequestProject.ID) {
        let newName = editingProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else {
            cancelProjectRename()
            return
        }
        onRenameProject(projectID, newName)
        cancelProjectRename()
    }
}
