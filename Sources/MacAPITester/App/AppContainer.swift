import AppKit
import Foundation
import SwiftUI

struct AppContainer: View {
    @State private var projects: [RequestProject]
    @State private var selectedProjectID: RequestProject.ID?
    @State private var requests: [RequestDocument]
    @State private var openedRequestIDs: [RequestDocument.ID]
    @State private var selectedRequestID: RequestDocument.ID?
    @State private var latestResponse: RequestResponseSnapshot?
    @State private var historyItems: [RequestHistoryItem] = []
    @State private var errorMessage: String?
    @State private var isSending = false
    @State private var hasLoadedHistory = false
    @State private var statusMessage: String?
    @State private var showingCookiesEditor = false
    @State private var showingScriptEditor = false
    @State private var showingTestCaseEditor = false
    @State private var showingDocServerSettings = false
    @State private var newDocServerPort: Int?
    @State private var cookieJar = CookieJar()
    @State private var scripts: [Script] = []
    @State private var testCases: [TestCase] = []
    @State private var testSuites: [TestSuite] = []
    private let workspaceBackground = Color(red: 249 / 255, green: 249 / 255, blue: 249 / 255)

    private let templateRenderer = TemplateRenderer()
    private let httpClient = HTTPClient()
    private var historyPersistence: HistoryPersistence
    private let cookieManager: CookieManager
    private var testCaseManager: TestCaseManager
    private var projectRepository: MySQLProjectRepository?
    private var requestDocumentRepository: MySQLRequestDocumentRepository?
    private var mysqlDatabase: MySQLDatabase?
    @State private var docServer: DocServer?

    init() {
        let storage = CookieStorage()
        let manager = CookieManager(storage: storage)
        self.cookieManager = manager
        _cookieJar = State(initialValue: manager.cookieJar)

        do {
            print("正在初始化MySQL数据库...")
            let mysqlDatabase = try MySQLDatabase()
            print("MySQL数据库连接成功")
            let migration = DatabaseMigration(mysqlDatabase: mysqlDatabase)
            try migration.migrate()
            print("数据库迁移完成")
            self.mysqlDatabase = mysqlDatabase
            self.historyPersistence = HistoryPersistence(database: mysqlDatabase)
            self.testCaseManager = TestCaseManager(database: mysqlDatabase)
            self.projectRepository = try MySQLProjectRepository(database: mysqlDatabase)
            self.requestDocumentRepository = try MySQLRequestDocumentRepository(database: mysqlDatabase)
            print("仓库初始化完成")
            
            let server = DocServer(database: mysqlDatabase)
            try? server.start()
            _docServer = State(initialValue: server)
            
            // 从数据库加载数据
            let loadedProjects = try projectRepository?.fetchAllProjects() ?? []
            let allRequestDocuments = try requestDocumentRepository?.fetchAllRequestDocuments() ?? []
            
            if loadedProjects.isEmpty {
                // 数据库为空，创建默认项目
                let initialProject = RequestProject(name: "默认项目")
                let initialRequest = RequestDocument.starter(projectID: initialProject.id)
                _projects = State(initialValue: [initialProject])
                _selectedProjectID = State(initialValue: initialProject.id)
                _requests = State(initialValue: [initialRequest])
                _openedRequestIDs = State(initialValue: [initialRequest.id])
                _selectedRequestID = State(initialValue: initialRequest.id)
                
                // 保存到数据库
                try projectRepository?.createProject(id: initialProject.id.uuidString, name: initialProject.name)
                try requestDocumentRepository?.createRequestDocument(initialRequest.toMySQLRecord())
            } else {
                // 从数据库加载
                let projects = loadedProjects.map { RequestProject(id: UUID(uuidString: $0.id) ?? UUID(), name: $0.name) }
                let requests = allRequestDocuments.compactMap { RequestDocument.fromMySQLRecord($0) }
                
                _projects = State(initialValue: projects)
                _selectedProjectID = State(initialValue: projects.first?.id)
                _requests = State(initialValue: requests)
                _openedRequestIDs = State(initialValue: Array(requests.prefix(5).map { $0.id }))
                _selectedRequestID = State(initialValue: requests.first?.id)
            }
        } catch {
            print("MySQL初始化失败，使用内存存储: \(error)")
            self.mysqlDatabase = nil
            self.projectRepository = nil
            self.requestDocumentRepository = nil
            self.historyPersistence = HistoryPersistence.inMemory
            self.testCaseManager = TestCaseManager()
            _docServer = State(initialValue: nil)

            // 使用默认数据
            let initialProject = RequestProject(name: "默认项目")
            let initialRequest = RequestDocument.starter(projectID: initialProject.id)
            _projects = State(initialValue: [initialProject])
            _selectedProjectID = State(initialValue: initialProject.id)
            _requests = State(initialValue: [initialRequest])
            _openedRequestIDs = State(initialValue: [initialRequest.id])
            _selectedRequestID = State(initialValue: initialRequest.id)
            _statusMessage = State(initialValue: "⚠️ MySQL连接失败，使用临时内存存储（数据不会持久化）")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                CollectionsView(
                    projects: projects,
                    selectedProjectID: $selectedProjectID,
                    requests: requests,
                    selectedRequestID: $selectedRequestID,
                    requestCountByProject: requestCountByProject,
                    onAddProject: addProject,
                    onDeleteProject: deleteProject,
                    onRenameProject: renameProject,
                    onAddRequest: addRequest,
                    onDeleteRequest: deleteRequest
                )
            } detail: {
                if let requestBinding = selectedRequestBinding {
                    VStack(spacing: 0) {
                        workspaceTabs
                        Divider()
                        workspaceMetaRow(request: requestBinding)
                        Divider()

                        ScrollView(.vertical) {
                            VStack(spacing: 0) {
                                RequestEditorView(
                                    request: requestBinding,
                                    isSending: isSending,
                                    errorMessage: errorMessage,
                                    onSend: triggerSend,
                                    showInlineRunButton: false
                                )

                                Divider()

                                ResponseViewerView(
                                    response: latestResponse,
                                    historyItems: historyItems,
                                    errorMessage: errorMessage
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .top)
                        }

                        bottomActionBar
                    }
                    .background(workspaceBackground)
                    .overlay(alignment: .bottom) {
                        if let statusMessage, !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.78), in: Capsule())
                                .padding(.bottom, 68)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: statusMessage)
                } else {
                    placeholderView(
                        title: "请选择一个接口",
                        message: "请在左侧选择接口，或先新建项目并添加接口。"
                    )
                }
            }
            .navigationSplitViewStyle(.balanced)
        }
        .frame(minWidth: 1280, minHeight: 820)
        .task {
            loadHistoryIfNeeded()
        }
        .onChange(of: selectedRequestID) { _, newValue in
            guard let newValue else { return }
            openRequestTabIfNeeded(newValue)
            if let ownerProjectID = requests.first(where: { $0.id == newValue })?.projectID {
                selectedProjectID = ownerProjectID
            }
        }
        .onChange(of: selectedProjectID) { _, newValue in
            guard let projectID = newValue else { return }
            guard let selectedRequestID,
                  requests.contains(where: { $0.id == selectedRequestID && $0.projectID == projectID }) else {
                let fallback = requests.first(where: { $0.projectID == projectID })
                self.selectedRequestID = fallback?.id
                if let fallback {
                    openRequestTabIfNeeded(fallback.id)
                } else {
                    latestResponse = nil
                    errorMessage = nil
                }
                return
            }
        }
        .onChange(of: statusMessage) { _, newValue in
            guard let newValue, !newValue.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if statusMessage == newValue {
                    statusMessage = nil
                }
            }
        }
    }

    private var workspaceTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(openedRequests) { request in
                    let isSelected = request.id == selectedRequestID
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isSelected ? Color.blue : Color.gray.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(request.name)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)

                        Button {
                            closeRequestTab(request.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isSelected ? Color.blue.opacity(0.12) : Color.clear)
                    .onTapGesture {
                        selectedRequestID = request.id
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func workspaceMetaRow(request: Binding<RequestDocument>) -> some View {
        HStack(spacing: 10) {
            statusAndNameRow(request: request)
                .frame(width: 300)

            simpleInput(text: request.descriptionText, placeholder: "(选填) 请输入接口描述")

            Divider()
                .frame(height: 28)

            Image(systemName: "clock")
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func statusAndNameRow(request: Binding<RequestDocument>) -> some View {
        HStack(spacing: 0) {
            TextField("接口名称", text: request.name)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        }
        .background(
            Color(red: 244 / 255, green: 244 / 255, blue: 244 / 255),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func simpleInput(text: Binding<String>, placeholder: String, minWidth: CGFloat = 160) -> some View {
        inputContainer(minWidth: minWidth) {
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
        }
    }

    private func inputContainer<Content: View>(minWidth: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 12)
        .frame(minWidth: minWidth, minHeight: 36)
        .background(
            Color(red: 244 / 255, green: 244 / 255, blue: 244 / 255),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var bottomActionBar: some View {
        HStack(spacing: 8) {
            // 核心操作按钮组
            Button("保存") {
                saveCurrentDraft()
            }
            .frame(width: 100, height: 40)
            .font(.system(size: 14, weight: .semibold))
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button("生成文档") {
                generateDocument()
            }
            .frame(width: 100, height: 40)
            .font(.system(size: 14, weight: .semibold))
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(isSending ? "调试中..." : "运行调试") {
                triggerSend()
            }
            .frame(width: 120, height: 40)
            .font(.system(size: 14, weight: .semibold))
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSending || selectedRequestBinding == nil)

            Divider()
                .frame(height: 24)

            // 工具按钮组
            Button("Cookies") {
                showingCookiesEditor = true
            }
            .frame(width: 80, height: 40)
            .font(.system(size: 13, weight: .medium))
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button("脚本") {
                showingScriptEditor = true
            }
            .frame(width: 60, height: 40)
            .font(.system(size: 13, weight: .medium))
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button("测试用例") {
                showingTestCaseEditor = true
            }
            .frame(width: 80, height: 40)
            .font(.system(size: 13, weight: .medium))
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button("文档设置") {
                showingDocServerSettings = true
            }
            .frame(width: 80, height: 40)
            .font(.system(size: 13, weight: .medium))
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(workspaceBackground)
        .sheet(isPresented: $showingCookiesEditor) {
            CookiesEditorView(
                cookieJar: $cookieJar,
                onImport: { data in
                    try? cookieManager.importCookies(from: data)
                    cookieJar = cookieManager.cookieJar
                },
                onExport: {
                    try? cookieManager.exportCookies()
                }
            )
        }
        .sheet(isPresented: $showingScriptEditor) {
            ScriptEditorView(
                scripts: $scripts,
                onRequestUpdate: { _ in }
            )
        }
        .sheet(isPresented: $showingTestCaseEditor) {
            TestCaseEditorView(
                testCases: $testCases,
                requestID: selectedRequestID ?? UUID()
            )
        }
        .sheet(isPresented: $showingDocServerSettings) {
            DocServerSettingsView(
                isPresented: $showingDocServerSettings,
                server: docServer,
                onRestart: { newPort in
                    newDocServerPort = newPort
                }
            )
        }
        .onChange(of: newDocServerPort) { _, newPort in
            guard let newPort else { return }
            docServer?.stop()
            guard let mysqlDatabase else { return }
            docServer = DocServer(port: newPort, database: mysqlDatabase)
            try? docServer?.start()
            newDocServerPort = nil
        }
    }

    private var selectedRequestIndex: Int? {
        requests.firstIndex(where: { $0.id == selectedRequestID })
    }

    private var openedRequests: [RequestDocument] {
        openedRequestIDs.compactMap { id in
            requests.first(where: { $0.id == id })
        }
        .filter { request in
            guard let selectedProjectID else { return true }
            return request.projectID == selectedProjectID
        }
    }

    private var requestCountByProject: [RequestProject.ID: Int] {
        requests.reduce(into: [RequestProject.ID: Int]()) { partial, request in
            partial[request.projectID, default: 0] += 1
        }
    }

    private var selectedRequestBinding: Binding<RequestDocument>? {
        guard let selectedRequestIndex else {
            return nil
        }
        return $requests[selectedRequestIndex]
    }

    private func addRequest() {
        guard let selectedProjectID else {
            addProject()
            return
        }
        let nextIndex = requests.filter { $0.projectID == selectedProjectID }.count + 1
        let request = RequestDocument.starter(
            named: "Request \(nextIndex)",
            projectID: selectedProjectID
        )
        requests.append(request)
        openRequestTabIfNeeded(request.id)
        selectedRequestID = request.id
        errorMessage = nil
        statusMessage = "已新增接口草稿：\(request.name)"
        
        // 同步到数据库
        syncRequestToDatabase(request, isNew: true)
    }

    private func closeRequestTab(_ id: RequestDocument.ID) {
        guard let index = openedRequestIDs.firstIndex(of: id) else {
            return
        }

        openedRequestIDs.remove(at: index)

        if selectedRequestID == id {
            if let fallbackID = openedRequestIDs.last {
                selectedRequestID = fallbackID
            } else {
                selectedRequestID = nil
                latestResponse = nil
                errorMessage = nil
            }
        }

        statusMessage = "已关闭接口标签"
    }

    private func deleteRequest(_ id: RequestDocument.ID) {
        guard let requestIndex = requests.firstIndex(where: { $0.id == id }) else {
            return
        }

        let removedRequest = requests.remove(at: requestIndex)
        openedRequestIDs.removeAll(where: { $0 == id })

        if selectedRequestID == id {
            if let fallbackOpened = openedRequestIDs.last {
                selectedRequestID = fallbackOpened
            } else if let firstRequest = requests.first(where: { $0.projectID == selectedProjectID }) ?? requests.first {
                selectedRequestID = firstRequest.id
                openRequestTabIfNeeded(firstRequest.id)
            } else {
                selectedRequestID = nil
                latestResponse = nil
                errorMessage = nil
            }
        }

        statusMessage = "已删除接口：\(removedRequest.name)"
        
        // 从数据库删除
        syncRequestDeletion(id)
    }

    private func addProject() {
        let project = RequestProject(name: "项目 \(projects.count + 1)")
        projects.append(project)
        selectedProjectID = project.id
        let seedRequest = RequestDocument.starter(named: "Request 1", projectID: project.id)
        requests.append(seedRequest)
        openRequestTabIfNeeded(seedRequest.id)
        selectedRequestID = seedRequest.id
        statusMessage = "已新增项目：\(project.name)"
        
        // 同步到数据库
        syncProjectToDatabase(project, isNew: true)
        syncRequestToDatabase(seedRequest, isNew: true)
    }

    private func renameProject(_ id: RequestProject.ID, _ newName: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = newName
        statusMessage = "已重命名项目：\(newName)"
        
        // 同步到数据库
        syncProjectToDatabase(projects[index], isNew: false)
    }

    private func deleteProject(_ id: RequestProject.ID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == id }) else {
            return
        }

        let removingProject = projects.remove(at: projectIndex)
        let removingRequestIDs = Set(requests.filter { $0.projectID == id }.map(\.id))
        requests.removeAll(where: { removingRequestIDs.contains($0.id) })
        openedRequestIDs.removeAll(where: { removingRequestIDs.contains($0) })

        if projects.isEmpty {
            addProject()
        } else if selectedProjectID == id {
            selectedProjectID = projects[max(0, min(projectIndex, projects.count - 1))].id
        }

        if let selectedRequestID, removingRequestIDs.contains(selectedRequestID) {
            if let fallback = requests.first(where: { $0.projectID == selectedProjectID }) ?? requests.first {
                self.selectedRequestID = fallback.id
                openRequestTabIfNeeded(fallback.id)
            } else {
                self.selectedRequestID = nil
                latestResponse = nil
                errorMessage = nil
            }
        }

        statusMessage = "已删除项目：\(removingProject.name)"
        
        // 从数据库删除
        syncProjectDeletion(id)
        for requestID in removingRequestIDs {
            syncRequestDeletion(requestID)
        }
    }

    private func openRequestTabIfNeeded(_ id: RequestDocument.ID) {
        guard requests.contains(where: { $0.id == id }) else {
            return
        }
        if !openedRequestIDs.contains(id) {
            openedRequestIDs.append(id)
        }
    }
    
    // MARK: - 数据库同步方法
    
    private func syncProjectToDatabase(_ project: RequestProject, isNew: Bool) {
        guard let projectRepository else { return }
        
        do {
            if isNew {
                try projectRepository.createProject(id: project.id.uuidString, name: project.name)
            } else {
                try projectRepository.updateProject(id: project.id.uuidString, name: project.name)
            }
        } catch {
            print("同步项目到数据库失败: \(error)")
        }
    }
    
    private func syncProjectDeletion(_ id: RequestProject.ID) {
        guard let projectRepository else { return }
        
        do {
            try projectRepository.deleteProject(id: id.uuidString)
        } catch {
            print("从数据库删除项目失败: \(error)")
        }
    }
    
    private func syncRequestToDatabase(_ request: RequestDocument, isNew: Bool) {
        guard let requestDocumentRepository else { 
            print("requestDocumentRepository为空，跳过同步")
            return 
        }
        
        do {
            let record = request.toMySQLRecord()
            print("准备同步请求到数据库: \(request.name), isNew: \(isNew)")
            if isNew {
                try requestDocumentRepository.createRequestDocument(record)
                print("请求创建成功: \(request.name)")
            } else {
                try requestDocumentRepository.updateRequestDocument(record)
                print("请求更新成功: \(request.name)")
            }
        } catch {
            print("同步请求到数据库失败: \(error)")
        }
    }
    
    private func syncRequestDeletion(_ id: RequestDocument.ID) {
        guard let requestDocumentRepository else { return }
        
        do {
            try requestDocumentRepository.deleteRequestDocument(id: id.uuidString)
        } catch {
            print("从数据库删除请求失败: \(error)")
        }
    }

    @MainActor
    private func triggerSend() {
        guard !isSending, selectedRequestIndex != nil else {
            return
        }

        isSending = true
        errorMessage = nil
        statusMessage = "正在运行调试..."

        Task {
            await sendSelectedRequest()
        }
    }

    @MainActor
    private func sendSelectedRequest() async {
        defer {
            isSending = false
        }

        guard let selectedRequestIndex else {
            return
        }

        let requestDocument = requests[selectedRequestIndex]

        do {
            let variables = try parseVariables(from: requestDocument.variablesText)
            let urlRequest = try buildRequest(from: requestDocument, variables: variables)
            let response = try await httpClient.send(urlRequest)
            let snapshot = RequestResponseSnapshot(
                statusCode: response.statusCode,
                duration: response.duration,
                headersText: formatHeaders(response.headers),
                bodyText: formatBody(response.body),
                timestamp: Date()
            )

            latestResponse = snapshot
            persistHistory(for: requestDocument, request: urlRequest, response: snapshot)
            statusMessage = "调试完成：\(response.statusCode) (\(Int((response.duration * 1000).rounded()))ms)"
        } catch {
            errorMessage = readableErrorMessage(from: error)
            statusMessage = "调试失败"
        }
    }

    private func saveCurrentDraft() {
        guard let binding = selectedRequestBinding else { return }
        let request = binding.wrappedValue
        statusMessage = "已保存草稿：\(request.name)"
        
        // 同步到数据库
        syncRequestToDatabase(request, isNew: false)
        
        // 生成文档
        generateDocumentation()
    }

    private func generateDocument() {
        guard let binding = selectedRequestBinding else { return }
        let request = binding.wrappedValue

        let markdown = """
        # \(request.name)

        - Method: \(request.method.rawValue)
        - URL: \(request.urlString)

        ## Query
        \(request.queryText.isEmpty ? "(空)" : request.queryText)

        ## Headers
        \(request.headersText.isEmpty ? "(空)" : request.headersText)

        ## Body
        \(request.bodyText.isEmpty ? "(空)" : request.bodyText)
        """

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
        statusMessage = "接口文档已复制到剪贴板"
    }

    private func generateDocumentation() {
        guard let selectedProjectID,
              let project = projects.first(where: { $0.id == selectedProjectID }) else {
            return
        }
        
        let projectRequests = requests.filter { $0.projectID == selectedProjectID }
        
        do {
            let model = DocGenerator.buildDocModel(project: project, requests: projectRequests)
            let html = HTMLRenderer().render(DocGenerator.renderMarkdown(model), title: project.name)
            
            guard let database = mysqlDatabase else { return }
            let repository = try DocRepository(database: database)
            
            try repository.saveDocument(
                id: project.id.uuidString,
                projectID: project.id.uuidString,
                title: project.name,
                html: html
            )
            
            if let url = docServer?.accessURL {
                statusMessage = "文档已更新，访问 \(url) 查看"
            }
        } catch {
            statusMessage = "文档生成失败: \(error.localizedDescription)"
        }
    }

    private func buildRequest(
        from requestDocument: RequestDocument,
        variables: [String: String]
    ) throws -> URLRequest {
        let headers = try parseHeaders(from: requestDocument.headersText)
        let renderedURL = try renderTemplate(requestDocument.urlString, variables: variables)
        let urlParts = try split(renderedURL: renderedURL)
        let tableQueryItems = try parseQueryItems(from: requestDocument.queryText, variables: variables)
        let effectiveQueryItems = tableQueryItems.isEmpty ? urlParts.queryItems : tableQueryItems

        let effectiveQueryMap = effectiveQueryItems.reduce(into: [String: String]()) { partial, item in
            partial[item.name] = item.value ?? ""
        }

        var draft = APIRequestDraft(
            method: requestDocument.method,
            path: urlParts.path,
            query: effectiveQueryMap,
            queryItems: effectiveQueryItems,
            headers: headers,
            body: normalizedBody(requestDocument.bodyText),
            variables: variables,
            bearerToken: nil
        )

        try applyAuth(
            requestDocument.auth,
            variables: variables,
            headers: &draft.headers,
            bearerToken: &draft.bearerToken
        )

        return try RequestBuilder(baseURL: urlParts.baseURL).build(draft)
    }

    private func parseVariables(from text: String) throws -> [String: String] {
        try parseKeyValueText(
            text,
            section: "Environment Variables",
            separators: ["=", ":"],
            example: "API_HOST=https://api.example.com"
        )
    }

    private func parseHeaders(from text: String) throws -> [String: String] {
        try parseKeyValueText(
            text,
            section: "Headers",
            separators: [":", "="],
            example: "Authorization: Bearer token"
        )
    }

    private func parseQueryItems(from text: String, variables: [String: String]) throws -> [URLQueryItem] {
        let parsed = try parseKeyValueText(
            text,
            section: "Query",
            separators: ["=", ":"],
            example: "page=1"
        )

        return try parsed.map { key, value in
            URLQueryItem(
                name: try renderTemplate(key, variables: variables),
                value: try renderTemplate(value, variables: variables)
            )
        }
    }

    private func parseKeyValueText(
        _ text: String,
        section: String,
        separators: [Character],
        example: String
    ) throws -> [String: String] {
        var parsed: [String: String] = [:]

        for (lineNumber, rawLine) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
            let line = String(rawLine).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            guard let separatorIndex = line.firstIndex(where: { separators.contains($0) }) else {
                throw RequestComposerError.invalidLine(
                    section: section,
                    lineNumber: lineNumber + 1,
                    example: example
                )
            }

            let key = String(line[..<separatorIndex]).trimmingCharacters(in: CharacterSet.whitespaces)
            let valueStart = line.index(after: separatorIndex)
            let value = String(line[valueStart...]).trimmingCharacters(in: CharacterSet.whitespaces)

            guard !key.isEmpty else {
                throw RequestComposerError.invalidLine(
                    section: section,
                    lineNumber: lineNumber + 1,
                    example: example
                )
            }

            parsed[String(key)] = String(value)
        }

        return parsed
    }

    private func renderTemplate(_ template: String, variables: [String: String]) throws -> String {
        do {
            return try templateRenderer.render(template, variables: variables)
        } catch let error as TemplateRendererError {
            throw AppRequestError.template(error)
        }
    }

    private func split(renderedURL: String) throws -> (baseURL: URL, path: String, query: [String: String], queryItems: [URLQueryItem]) {
        guard let components = URLComponents(string: renderedURL),
              let scheme = components.scheme,
              let host = components.host else {
            throw AppRequestError.invalidURL(renderedURL)
        }

        var baseComponents = URLComponents()
        baseComponents.scheme = scheme
        baseComponents.host = host
        baseComponents.port = components.port
        baseComponents.user = components.user
        baseComponents.password = components.password

        guard let baseURL = baseComponents.url else {
            throw AppRequestError.invalidURL(renderedURL)
        }

        var query: [String: String] = [:]
        let queryItems = components.queryItems ?? []
        for item in queryItems {
            query[item.name] = item.value ?? ""
        }

        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        return (baseURL, path, query, queryItems)
    }

    private func normalizedBody(_ bodyText: String) -> String? {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : bodyText
    }

    private func applyAuth(
        _ auth: RequestAuthConfiguration,
        variables: [String: String],
        headers: inout [String: String],
        bearerToken: inout String?
    ) throws {
        switch auth.type {
        case .none:
            bearerToken = nil
        case .bearer:
            bearerToken = try renderRequiredField(
                auth.bearerToken,
                fieldName: "Bearer token",
                variables: variables
            )
        case .basic:
            let username = try renderRequiredField(
                auth.basicUsername,
                fieldName: "Basic username",
                variables: variables
            )
            let password = try renderTemplate(auth.basicPassword, variables: variables)
            headers = removingAuthorization(from: headers)
            let encoded = Data("\(username):\(password)".utf8).base64EncodedString()
            headers["Authorization"] = "Basic \(encoded)"
            bearerToken = nil
        case .apiKey:
            let headerName = try renderRequiredField(
                auth.apiKeyHeader,
                fieldName: "API Key header",
                variables: variables
            )
            let headerValue = try renderRequiredField(
                auth.apiKeyValue,
                fieldName: "API Key value",
                variables: variables
            )
            headers[headerName] = headerValue
            bearerToken = nil
        }
    }

    private func renderRequiredField(
        _ value: String,
        fieldName: String,
        variables: [String: String]
    ) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RequestComposerError.emptyField(fieldName)
        }

        return try renderTemplate(trimmed, variables: variables)
    }

    private func removingAuthorization(from headers: [String: String]) -> [String: String] {
        var filtered = headers
        for key in filtered.keys where key.lowercased() == "authorization" {
            filtered.removeValue(forKey: key)
        }
        return filtered
    }

    private func formatBody(_ data: Data) -> String {
        guard !data.isEmpty else {
            return "无响应体。"
        }

        if let object = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(object),
           let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        if let string = String(data: data, encoding: .utf8) {
            return string
        }

        return "收到 \(data.count) 字节，响应体不是 UTF-8 文本。"
    }

    private func formatHeaders(_ headers: [String: String]) -> String {
        if headers.isEmpty {
            return "无响应头。"
        }

        return headers
            .sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending })
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }

    private func persistHistory(
        for requestDocument: RequestDocument,
        request: URLRequest,
        response: RequestResponseSnapshot
    ) {
        let message = historyMessage(for: requestDocument, request: request, response: response)
        historyPersistence.save(message: message, createdAt: response.timestamp)
        historyItems = historyPersistence.loadItems()
    }

    private func historyMessage(
        for requestDocument: RequestDocument,
        request: URLRequest,
        response: RequestResponseSnapshot
    ) -> String {
        let urlText = request.url?.absoluteString ?? requestDocument.urlString
        let milliseconds = Int((response.duration * 1000).rounded())
        return "\(requestDocument.method.rawValue) \(urlText) -> \(response.statusCode) (\(milliseconds) ms)"
    }

    private func loadHistoryIfNeeded() {
        guard !hasLoadedHistory else {
            return
        }

        hasLoadedHistory = true
        historyItems = historyPersistence.loadItems()
    }

    private func readableErrorMessage(from error: Error) -> String {
        if let composerError = error as? RequestComposerError {
            return composerError.localizedDescription
        }

        if let appError = error as? AppRequestError {
            switch appError {
            case let .invalidURL(urlString):
                return "URL 无效：\(urlString)。请输入完整地址，例如 https://api.example.com/v1/ping。"
            case let .template(.missingVariable(name)):
                return "缺少变量 \(name)。请在 Environment Variables 中补充对应值。"
            case .timeout:
                return "请求超时。可以检查网络状况，或稍后重试。"
            case .offline:
                return "当前网络不可用。请确认设备已联网后再试。"
            case .tls:
                return "TLS / 证书校验失败。请确认目标服务证书可被系统信任。"
            case .badResponse:
                return "未收到可解析的 HTTP 响应。请检查目标地址、代理或服务端状态。"
            }
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "发生了未识别的错误。" : message
    }

    @ViewBuilder
    private func placeholderView(title: String, message: String) -> some View {
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

private enum RequestComposerError: LocalizedError {
    case invalidLine(section: String, lineNumber: Int, example: String)
    case emptyField(String)

    var errorDescription: String? {
        switch self {
        case let .invalidLine(section, lineNumber, example):
            return "\(section) 第 \(lineNumber) 行格式无效。请使用类似 `\(example)` 的写法。"
        case let .emptyField(fieldName):
            return "\(fieldName) 不能为空。"
        }
    }
}

@MainActor
private final class HistoryPersistence {
    static let shared = HistoryPersistence.inMemory

    private let database: MySQLDatabase?
    private let repository: MySQLHistoryRepository?

    init(database: MySQLDatabase) {
        self.database = database
        do {
            self.repository = try MySQLHistoryRepository(database: database)
        } catch {
            print("HistoryRepository初始化失败: \(error)")
            self.repository = nil
        }
    }

    static var inMemory: HistoryPersistence {
        HistoryPersistence(database: nil)
    }

    private init(database: MySQLDatabase?) {
        self.database = database
        if let database {
            do {
                self.repository = try MySQLHistoryRepository(database: database)
            } catch {
                print("HistoryRepository初始化失败: \(error)")
                self.repository = nil
            }
        } else {
            self.repository = nil
        }
    }

    func save(message: String, createdAt: Date) {
        guard let repository else {
            return
        }

        do {
            try repository.insertHistory(message: message, createdAt: createdAt)
        } catch {
            print("保存历史记录失败: \(error)")
        }
    }

    func loadItems() -> [RequestHistoryItem] {
        guard let repository else {
            return []
        }

        do {
            let records = try repository.fetchHistory()
            return records
                .reversed()
                .map { record in
                    RequestHistoryItem(
                        timestamp: record.createdAt,
                        message: record.message
                    )
                }
        } catch {
            print("加载历史记录失败: \(error)")
            return []
        }
    }
}
