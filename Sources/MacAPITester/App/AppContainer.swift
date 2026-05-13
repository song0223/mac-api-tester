import AppKit
import Foundation
import SwiftUI

struct AppContainer: View {
    @State private var store = AppStore()
    private let workspaceBackground = Color(red: 249 / 255, green: 249 / 255, blue: 249 / 255)

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                CollectionsView(
                    projects: store.projects,
                    selectedProjectID: $store.selectedProjectID,
                    requests: store.requests,
                    selectedRequestID: $store.selectedRequestID,
                    requestCountByProject: store.requestCountByProject,
                    onAddProject: store.addProject,
                    onDeleteProject: store.deleteProject,
                    onRenameProject: store.renameProject,
                    onAddRequest: store.addRequest,
                    onDeleteRequest: store.deleteRequest
                )
            } detail: {
                ZStack {
                    // 稳定的基础视图 - 始终存在
                    VStack(spacing: 0) {
                        WorkspaceTabs(store: store)
                        Divider()

                        if let requestBinding = store.selectedRequestBinding {
                            WorkspaceMetaRow(store: store, request: requestBinding)
                            Divider()

                            ScrollView(.vertical) {
                                VStack(spacing: 4) {
                                    RequestEditorView(
                                        request: requestBinding,
                                        isSending: store.isSending,
                                        errorMessage: store.errorMessage,
                                        onSend: store.triggerSend,
                                        showInlineRunButton: false
                                    )

                                    ResponseViewerView(
                                        response: store.latestResponse,
                                        historyItems: store.historyItems,
                                        errorMessage: store.errorMessage,
                                        historySearchText: $store.historySearchText,
                                        responseFields: $store.responseFields,
                                        onHistorySearch: { store.loadHistory() },
                                        onFieldsChanged: { store.syncResponseFieldsToDatabase() },
                                        onResponseBodyChanged: { newBody in
                                            store.handleResponseBodyChanged(newBody)
                                        }
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                            }

                            BottomActionBar(store: store)
                        } else {
                            Spacer()
                            PlaceholderView(
                                title: "请选择一个接口",
                                message: "请在左侧选择接口，或先新建项目并添加接口。"
                            )
                            Spacer()
                        }
                    }
                    .background(workspaceBackground)

                    // 状态消息叠加层 - 独立于主内容
                    if let statusMessage = store.statusMessage, !statusMessage.isEmpty {
                        VStack {
                            Spacer()
                            Text(statusMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.78), in: Capsule())
                                .padding(.bottom, 68)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeInOut(duration: 0.2), value: store.statusMessage)
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
        }
        .frame(minWidth: 1280, minHeight: 820)
        .task {
            store.loadHistoryIfNeeded()
        }
        .onChange(of: store.selectedRequestID) { _, newValue in
            withAnimation(.easeOut(duration: 0.15)) {
                store.handleSelectedRequestChange(newValue)
            }
        }
        .onChange(of: store.selectedProjectID) { _, newValue in
            withAnimation(.easeOut(duration: 0.12)) {
                store.handleSelectedProjectChange(newValue)
            }
        }
        .onChange(of: store.statusMessage) { _, newValue in
            store.handleStatusMessageChange(newValue)
        }
        .sheet(item: $store.presentedSheet) { destination in
            SheetDestinationView(store: store, destination: destination)
        }
        .onChange(of: store.newDocServerPort) { _, newPort in
            store.handleDocServerPortChange(newPort)
        }
    }
}

// MARK: - Sheet 路由视图

struct SheetDestinationView: View {
    @Bindable var store: AppStore
    let destination: SheetDestination

    var body: some View {
        switch destination {
        case .cookiesEditor:
            CookiesEditorView(
                cookieJar: $store.cookieJar,
                onImport: { data in
                    try? store.cookieManager.importCookies(from: data)
                    store.cookieJar = store.cookieManager.cookieJar
                },
                onExport: {
                    try? store.cookieManager.exportCookies()
                }
            )
        case .scriptEditor:
            ScriptEditorView(
                scripts: $store.scripts,
                onRequestUpdate: { _ in }
            )
        case .testCaseEditor(let requestID):
            TestCaseEditorView(
                testCases: $store.testCases,
                requestID: requestID
            )
        case .docServerSettings:
            DocServerSettingsSheet(store: store)
        case .environmentEditor:
            EnvironmentEditorView(
                environments: $store.environments,
                activeEnvironmentID: $store.activeEnvironmentID,
                onSave: { store.syncEnvironmentsToDatabase() }
            )
        case .curlImport:
            CurlImportSheet(store: store)
        case .history:
            HistorySheet(store: store)
        case .databaseSettings:
            DatabaseSettingsSheet()
        }
    }
}

// MARK: - Sheet 子视图（拥有自己的 dismiss 逻辑）

struct DocServerSettingsSheet: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    let store: AppStore

    var body: some View {
        DocServerSettingsView(
            isPresented: .constant(true),
            server: store.docServer,
            onRestart: { newPort in
                store.restartDocServer(port: newPort)
                dismiss()
            }
        )
    }
}

struct CurlImportSheet: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    let store: AppStore

    var body: some View {
        CurlImportView(
            onImport: { result in
                store.importCurlResult(result)
                dismiss()
            },
            onCancel: {
                dismiss()
            }
        )
    }
}

struct HistorySheet: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @Bindable var store: AppStore

    var body: some View {
        HistoryView(
            historyItems: store.historyItems,
            historySearchText: $store.historySearchText,
            onSearch: { store.loadHistory() },
            onDismiss: { dismiss() }
        )
    }
}

struct DatabaseSettingsSheet: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var isPresented = true

    var body: some View {
        DatabaseSettingsView(
            isPresented: $isPresented,
            onSave: {
                dismiss()
            }
        )
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                dismiss()
            }
        }
    }
}

// MARK: - 工作区标签页

struct WorkspaceTabs: View {
    let store: AppStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(store.openedRequests) { request in
                    let isSelected = request.id == store.selectedRequestID
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isSelected ? Color.blue : Color.gray.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(request.name)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                        Button {
                            store.closeRequestTab(request.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                    }
                    .frame(minWidth: 80, maxWidth: 180)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isSelected ? Color.blue.opacity(0.12) : Color.clear)
                    .animation(.easeOut(duration: 0.1), value: isSelected)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.1)) {
                            store.selectedRequestID = request.id
                        }
                    }
                    .pointingHandCursor()
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 工作区元数据行

struct WorkspaceMetaRow: View {
    let store: AppStore
    @Binding var request: RequestDocument

    var body: some View {
        HStack(spacing: 10) {
            TextField("接口名称", text: $request.name)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(minWidth: 300, maxWidth: 300, minHeight: 36, maxHeight: 36, alignment: .leading)
                .background(
                    Color(red: 244 / 255, green: 244 / 255, blue: 244 / 255),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            TextField("(选填) 请输入接口描述", text: $request.descriptionText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36, alignment: .leading)
                .background(
                    Color(red: 244 / 255, green: 244 / 255, blue: 244 / 255),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            Divider()
                .frame(height: 28)

            Button(action: {
                store.copyAsCurl(request)
            }) {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .help("复制为 cURL 命令")

            Button(action: {
                store.presentedSheet = .history
            }) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .help("查看历史记录")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 底部操作栏

struct BottomActionBar: View {
    let store: AppStore

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：核心操作
            HStack(spacing: 6) {
                ToolButton(icon: "square.and.arrow.down", label: "保存", action: store.saveCurrentDraft)
                ToolButton(icon: "doc.text", label: "文档", action: store.generateDocument)

                Button(action: store.triggerSend) {
                    HStack(spacing: 6) {
                        if store.isSending {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                        }
                        Text(store.isSending ? "调试中" : "运行调试")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .disabled(store.isSending || store.selectedRequestBinding == nil)
            }

            Divider()
                .frame(height: 20)

            // 中间：工具按钮
            HStack(spacing: 4) {
                ToolButton(icon: "lock.shield", label: "Cookies") {
                    store.presentedSheet = .cookiesEditor
                }
                ToolButton(icon: "terminal", label: "脚本") {
                    store.presentedSheet = .scriptEditor
                }
                ToolButton(icon: "checklist", label: "用例") {
                    store.presentedSheet = .testCaseEditor(requestID: store.selectedRequestID ?? UUID())
                }
                ToolButton(icon: "doc.richtext", label: "文档设置") {
                    store.presentedSheet = .docServerSettings
                }
                ToolButton(icon: "slider.horizontal.3", label: "环境") {
                    store.presentedSheet = .environmentEditor
                }
                ToolButton(icon: "square.and.arrow.up", label: "cURL") {
                    store.presentedSheet = .curlImport
                }
                ToolButton(icon: "externaldrive.connected.to.line.below", label: "数据库") {
                    store.presentedSheet = .databaseSettings
                }
            }

            Spacer()

            // 右侧：当前环境标签
            if let activeEnv = store.environments.first(where: { $0.id == store.activeEnvironmentID }) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text(activeEnv.name)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.green.opacity(0.1), in: Capsule())
                .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

// MARK: - 工具按钮

struct ToolButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: Capsule())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

// MARK: - 占位视图

struct PlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }
}
