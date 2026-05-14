import AppKit
import Foundation
import SwiftUI

@Observable
@MainActor
final class AppStore {
    // MARK: - 子 Store

    let projectStore = ProjectStore()

    // MARK: - 环境变量状态

    var environments: [Environment] = []
    var activeEnvironmentID: UUID?
    var environmentRepository: MySQLEnvironmentRepository?

    // MARK: - 历史记录状态

    var historyItems: [RequestHistoryItem] = []
    var historySearchText = ""
    var historyPersistence: HistoryPersistence

    // MARK: - 响应状态

    var latestResponse: RequestResponseSnapshot?
    var responseFields: [ResponseFieldInfo] = []

    // MARK: - UI 状态

    var errorMessage: String?
    var isSending = false
    var statusMessage: String?

    // MARK: - Sheet 路由

    var presentedSheet: SheetDestination?
    var newDocServerPort: Int?

    // MARK: - 功能模块状态

    var cookieJar = CookieJar()
    var scripts: [Script] = []
    var testCases: [TestCase] = []
    var testSuites: [TestSuite] = []
    var docServer: DocServer?

    // MARK: - 服务依赖

    let templateRenderer = TemplateRenderer()
    let httpClient = HTTPClient()
    let cookieManager: CookieManager
    var testCaseManager: TestCaseManager
    var mysqlDatabase: MySQLDatabase?

    // MARK: - 便捷访问器

    var projects: [RequestProject] {
        get { projectStore.projects }
        set { projectStore.projects = newValue }
    }

    var selectedProjectID: RequestProject.ID? {
        get { projectStore.selectedProjectID }
        set { projectStore.selectedProjectID = newValue }
    }

    var requests: [RequestDocument] {
        get { projectStore.requests }
        set { projectStore.requests = newValue }
    }

    var openedRequestIDs: [RequestDocument.ID] {
        get { projectStore.openedRequestIDs }
        set { projectStore.openedRequestIDs = newValue }
    }

    var selectedRequestID: RequestDocument.ID? {
        get { projectStore.selectedRequestID }
        set { projectStore.selectedRequestID = newValue }
    }

    var openedRequests: [RequestDocument] {
        projectStore.openedRequests
    }

    var requestCountByProject: [RequestProject.ID: Int] {
        projectStore.requestCountByProject
    }

    var selectedRequestIndex: Int? {
        projectStore.selectedRequestIndex
    }

    var selectedRequestBinding: Binding<RequestDocument>? {
        projectStore.selectedRequestBinding
    }

    // MARK: - 初始化

    init() {
        let storage = CookieStorage()
        let manager = CookieManager(storage: storage)
        self.cookieManager = manager
        self.cookieJar = manager.cookieJar
        self.historyPersistence = HistoryPersistence.inMemory

        do {
            print("正在初始化MySQL数据库...")
            let mysqlDatabase = try MySQLDatabase()
            print("MySQL数据库连接成功")
            let migration = DatabaseMigration(mysqlDatabase: mysqlDatabase)
            try migration.migrate()
            print("数据库迁移完成")
            self.mysqlDatabase = mysqlDatabase

            // 初始化仓库
            self.historyPersistence = HistoryPersistence(database: mysqlDatabase)
            self.testCaseManager = TestCaseManager(database: mysqlDatabase)
            projectStore.projectRepository = try MySQLProjectRepository(database: mysqlDatabase)
            projectStore.requestDocumentRepository = try MySQLRequestDocumentRepository(database: mysqlDatabase)
            self.environmentRepository = try MySQLEnvironmentRepository(database: mysqlDatabase)
            print("仓库初始化完成")

            let server = DocServer(database: mysqlDatabase)
            try? server.start()
            self.docServer = server

            // 从数据库加载数据
            let loadedProjects = try projectStore.projectRepository?.fetchAllProjects() ?? []
            let allRequestDocuments = try projectStore.requestDocumentRepository?.fetchAllRequestDocuments() ?? []

            // 加载环境变量
            let loadedEnvironments = try environmentRepository?.fetchAllEnvironments() ?? []
            var envs: [Environment] = []
            for envRecord in loadedEnvironments {
                let variables = try environmentRepository?.fetchVariables(envId: envRecord.id) ?? []
                let env = Environment(
                    id: UUID(uuidString: envRecord.id) ?? UUID(),
                    name: envRecord.name,
                    isActive: envRecord.isActive,
                    variables: variables.map { v in
                        EnvironmentVariable(
                            id: UUID(uuidString: v.id) ?? UUID(),
                            key: v.keyName,
                            value: v.value,
                            enabled: v.enabled
                        )
                    }
                )
                envs.append(env)
            }
            self.environments = envs
            self.activeEnvironmentID = envs.first(where: { $0.isActive })?.id

            if loadedProjects.isEmpty {
                // 数据库为空，创建默认项目
                let initialProject = RequestProject(name: "默认项目")
                let initialRequest = RequestDocument.starter(projectID: initialProject.id)
                projectStore.projects = [initialProject]
                projectStore.selectedProjectID = initialProject.id
                projectStore.requests = [initialRequest]
                projectStore.openedRequestIDs = [initialRequest.id]
                projectStore.selectedRequestID = initialRequest.id

                // 保存到数据库
                try projectStore.projectRepository?.createProject(id: initialProject.id.uuidString, name: initialProject.name)
                try projectStore.requestDocumentRepository?.createRequestDocument(initialRequest.toMySQLRecord())
            } else {
                // 从数据库加载
                let projects = loadedProjects.map { RequestProject(id: UUID(uuidString: $0.id) ?? UUID(), name: $0.name) }
                let requests = allRequestDocuments.compactMap { RequestDocument.fromMySQLRecord($0) }

                projectStore.projects = projects
                projectStore.selectedProjectID = projects.first?.id
                projectStore.requests = requests
                projectStore.openedRequestIDs = Array(requests.prefix(5).map { $0.id })
                projectStore.selectedRequestID = requests.first?.id
                responseFields = requests.first?.responseFields ?? []

                // 加载第一个请求的响应状态
                if let firstRequest = requests.first {
                    if firstRequest.responseStatusCode > 0 {
                        latestResponse = RequestResponseSnapshot(
                            statusCode: firstRequest.responseStatusCode,
                            duration: firstRequest.responseDuration,
                            headersText: firstRequest.responseHeadersText,
                            bodyText: firstRequest.responseBody,
                            timestamp: Date()
                        )
                    } else if !firstRequest.responseBody.isEmpty {
                        latestResponse = RequestResponseSnapshot(
                            statusCode: 0,
                            duration: 0,
                            headersText: firstRequest.responseHeadersText,
                            bodyText: firstRequest.responseBody,
                            timestamp: Date()
                        )
                    }
                }
            }

            // 更新缓存
            projectStore.refreshCaches()
        } catch {
            print("MySQL初始化失败，使用内存存储: \(error)")
            self.mysqlDatabase = nil
            self.testCaseManager = TestCaseManager()
            self.docServer = nil

            // 使用默认数据
            let initialProject = RequestProject(name: "默认项目")
            let initialRequest = RequestDocument.starter(projectID: initialProject.id)
            projectStore.projects = [initialProject]
            projectStore.selectedProjectID = initialProject.id
            projectStore.requests = [initialRequest]
            projectStore.openedRequestIDs = [initialRequest.id]
            projectStore.selectedRequestID = initialRequest.id
            projectStore.refreshCaches()
            statusMessage = "⚠️ MySQL连接失败，使用临时内存存储（数据不会持久化）"
        }
    }

    // MARK: - 选中变更处理

    func handleSelectedRequestChange(_ newValue: RequestDocument.ID?) {
        guard let newValue else { return }
        projectStore.handleSelectedRequestChange(newValue)
        if let request = requests.first(where: { $0.id == newValue }) {
            responseFields = request.responseFields
            if request.responseStatusCode > 0 {
                latestResponse = RequestResponseSnapshot(
                    statusCode: request.responseStatusCode,
                    duration: request.responseDuration,
                    headersText: request.responseHeadersText,
                    bodyText: request.responseBody,
                    timestamp: Date()
                )
            } else if !request.responseBody.isEmpty {
                latestResponse = RequestResponseSnapshot(
                    statusCode: 0,
                    duration: 0,
                    headersText: request.responseHeadersText,
                    bodyText: request.responseBody,
                    timestamp: Date()
                )
            } else {
                latestResponse = nil
            }
        }
    }

    func handleSelectedProjectChange(_ newValue: RequestProject.ID?) {
        projectStore.handleSelectedProjectChange(newValue)
        if newValue != nil {
            latestResponse = nil
            errorMessage = nil
            responseFields = []
        }
    }

    // MARK: - 状态消息自动消失

    func handleStatusMessageChange(_ newValue: String?) {
        guard let newValue, !newValue.isEmpty else { return }
        Task {
            try await Task.sleep(for: .seconds(2))
            if statusMessage == newValue {
                statusMessage = nil
            }
        }
    }

    // MARK: - 项目和请求操作

    func addRequest() {
        projectStore.addRequest()
        statusMessage = "已新增接口草稿"
    }

    func closeRequestTab(_ id: RequestDocument.ID) {
        projectStore.closeRequestTab(id)
        statusMessage = "已关闭接口标签"
    }

    func deleteRequest(_ id: RequestDocument.ID) {
        projectStore.deleteRequest(id)
        statusMessage = "已删除接口"
    }

    func addProject() {
        projectStore.addProject()
        statusMessage = "已新增项目"
    }

    func renameProject(_ id: RequestProject.ID, _ newName: String) {
        projectStore.renameProject(id, newName)
        statusMessage = "已重命名项目：\(newName)"
    }

    func deleteProject(_ id: RequestProject.ID) {
        projectStore.deleteProject(id)
        statusMessage = "已删除项目"
    }

    // MARK: - 数据库同步

    func syncResponseFieldsToDatabase() {
        guard let selectedRequestIndex else { return }
        requests[selectedRequestIndex].responseFields = responseFields
        projectStore.syncRequestToDatabase(requests[selectedRequestIndex], isNew: false)
    }

    func syncEnvironmentsToDatabase() {
        guard let environmentRepository else { return }

        do {
            // 获取数据库中现有的环境
            let existingEnvs = try environmentRepository.fetchAllEnvironments()
            let existingEnvIDs = Set(existingEnvs.map { $0.id })
            let currentEnvIDs = Set(environments.map { $0.id.uuidString })

            // 删除不再存在的环境
            for envID in existingEnvIDs where !currentEnvIDs.contains(envID) {
                try environmentRepository.deleteEnvironment(id: envID)
            }

            // 创建或更新环境
            for env in environments {
                let envID = env.id.uuidString
                if existingEnvIDs.contains(envID) {
                    try environmentRepository.updateEnvironment(id: envID, name: env.name, isActive: env.isActive)
                } else {
                    try environmentRepository.createEnvironment(id: envID, name: env.name, isActive: env.isActive)
                }

                // 同步环境变量
                let existingVars = try environmentRepository.fetchVariables(envId: envID)
                let existingVarIDs = Set(existingVars.map { $0.id })
                let currentVarIDs = Set(env.variables.map { $0.id.uuidString })

                // 删除不再存在的变量
                for varID in existingVarIDs where !currentVarIDs.contains(varID) {
                    try environmentRepository.deleteVariable(id: varID)
                }

                // 创建或更新变量
                for variable in env.variables {
                    let varID = variable.id.uuidString
                    if existingVarIDs.contains(varID) {
                        try environmentRepository.updateVariable(id: varID, keyName: variable.key, value: variable.value, enabled: variable.enabled)
                    } else {
                        try environmentRepository.createVariable(id: varID, envId: envID, keyName: variable.key, value: variable.value, enabled: variable.enabled)
                    }
                }
            }
        } catch {
            print("同步环境变量到数据库失败: \(error)")
        }
    }

    // MARK: - cURL 导入

    func importCurlResult(_ result: CurlParseResult) {
        projectStore.importCurlResult(result)
        statusMessage = "已从 cURL 导入请求"
    }

    func copyAsCurl(_ document: RequestDocument) {
        projectStore.copyAsCurl(document)
        statusMessage = "已复制 cURL 命令到剪贴板"
    }

    // MARK: - 请求发送

    func triggerSend() {
        guard !isSending, selectedRequestIndex != nil else { return }

        isSending = true
        errorMessage = nil
        statusMessage = "正在运行调试..."

        Task {
            await sendSelectedRequest()
        }
    }

    func sendSelectedRequest() async {
        defer {
            isSending = false
        }

        guard let selectedRequestIndex else { return }

        let requestDocument = requests[selectedRequestIndex]

        do {
            var variables = try parseVariables(from: requestDocument.variablesText)
            variables = mergeEnvironmentVariables(with: variables)

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

            // 保存响应内容到请求文档
            requests[selectedRequestIndex].responseBody = snapshot.bodyText
            requests[selectedRequestIndex].responseHeadersText = snapshot.headersText
            requests[selectedRequestIndex].responseStatusCode = snapshot.statusCode
            requests[selectedRequestIndex].responseDuration = snapshot.duration
            projectStore.syncRequestToDatabase(requests[selectedRequestIndex], isNew: false)

            // 重新生成文档
            generateDocumentation()

            statusMessage = "调试完成：\(response.statusCode) (\(Int((response.duration * 1000).rounded()))ms)"
        } catch {
            errorMessage = readableErrorMessage(from: error)
            statusMessage = "调试失败"
        }
    }

    // MARK: - 保存和文档

    func saveCurrentDraft() {
        guard let selectedRequestIndex else { return }
        let request = requests[selectedRequestIndex]
        statusMessage = "已保存草稿：\(request.name)"

        // 同步到数据库
        projectStore.syncRequestToDatabase(request, isNew: false)

        // 生成文档
        generateDocumentation()
    }

    func generateDocument() {
        guard let selectedRequestIndex else { return }
        let request = requests[selectedRequestIndex]

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

    func generateDocumentation() {
        guard let selectedProjectID,
              let project = projects.first(where: { $0.id == selectedProjectID }) else { return }

        let projectRequests = requests.filter { $0.projectID == selectedProjectID }

        do {
            guard let database = mysqlDatabase else { return }
            let repository = try DocRepository(database: database)

            // 删除该项目的旧文档
            try repository.deleteDocuments(projectID: project.id.uuidString)

            // 每个接口单独保存
            for request in projectRequests {
                let model = DocGenerator.buildDocModel(project: project, requests: [request])
                let markdown = DocGenerator.renderMarkdown(model)

                try repository.saveDocument(
                    id: request.id.uuidString,
                    projectID: project.id.uuidString,
                    title: request.name,
                    html: markdown
                )
            }

            if let url = docServer?.accessURL {
                statusMessage = "文档已更新，共 \(projectRequests.count) 个接口，访问 \(url) 查看"
            }
        } catch {
            statusMessage = "文档生成失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 历史记录

    func loadHistoryIfNeeded() {
        loadHistory()
    }

    func loadHistory() {
        let search = historySearchText.isEmpty ? nil : historySearchText
        historyItems = historyPersistence.loadItems(search: search)
    }

    func persistHistory(
        for requestDocument: RequestDocument,
        request: URLRequest,
        response: RequestResponseSnapshot
    ) {
        let urlText = request.url?.absoluteString ?? requestDocument.urlString
        let milliseconds = Int((response.duration * 1000).rounded())
        let message = "\(requestDocument.method.rawValue) \(urlText) -> \(response.statusCode) (\(milliseconds) ms)"
        historyPersistence.save(message: message, createdAt: response.timestamp)
        loadHistory()
    }

    // MARK: - 环境变量合并

    func mergeEnvironmentVariables(with requestVariables: [String: String]) -> [String: String] {
        var variables = requestVariables

        if let envID = activeEnvironmentID,
           let env = environments.first(where: { $0.id == envID }) {
            for v in env.variables where v.enabled && !v.key.isEmpty {
                if variables[v.key] == nil {
                    variables[v.key] = v.value
                }
            }
        }

        return variables
    }

    // MARK: - 请求构建辅助方法

    func buildRequest(
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

    func parseVariables(from text: String) throws -> [String: String] {
        try parseKeyValueText(
            text,
            section: "Environment Variables",
            separators: ["=", ":"],
            example: "API_HOST=https://api.example.com"
        )
    }

    func parseHeaders(from text: String) throws -> [String: String] {
        // 尝试 JSON 格式
        if let data = text.data(using: .utf8),
           let params = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var headers: [String: String] = [:]
            for dict in params {
                if let name = dict["name"] as? String, !name.isEmpty,
                   let value = dict["value"] as? String {
                    headers[name] = value
                }
            }
            return headers
        }

        // 兼容旧格式 key=value
        return try parseKeyValueText(
            text,
            section: "Headers",
            separators: [":", "="],
            example: "Authorization: Bearer token"
        )
    }

    func parseQueryItems(from text: String, variables: [String: String]) throws -> [URLQueryItem] {
        // 尝试 JSON 格式
        if let data = text.data(using: .utf8),
           let params = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return try params.compactMap { dict -> URLQueryItem? in
                guard let name = dict["name"] as? String, !name.isEmpty else { return nil }
                let value = dict["value"] as? String ?? ""
                return URLQueryItem(
                    name: try renderTemplate(name, variables: variables),
                    value: try renderTemplate(value, variables: variables)
                )
            }
        }

        // 兼容旧格式 key=value
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

    func parseKeyValueText(
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

    func renderTemplate(_ template: String, variables: [String: String]) throws -> String {
        do {
            return try templateRenderer.render(template, variables: variables)
        } catch let error as TemplateRendererError {
            throw AppRequestError.template(error)
        }
    }

    func split(renderedURL: String) throws -> (baseURL: URL, path: String, query: [String: String], queryItems: [URLQueryItem]) {
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

    func normalizedBody(_ bodyText: String) -> String? {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : bodyText
    }

    func applyAuth(
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

    func renderRequiredField(
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

    func removingAuthorization(from headers: [String: String]) -> [String: String] {
        var filtered = headers
        for key in filtered.keys where key.lowercased() == "authorization" {
            filtered.removeValue(forKey: key)
        }
        return filtered
    }

    func formatBody(_ data: Data) -> String {
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

    func formatHeaders(_ headers: [String: String]) -> String {
        if headers.isEmpty {
            return "无响应头。"
        }

        return headers
            .sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending })
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }

    func readableErrorMessage(from error: Error) -> String {
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

    // MARK: - 响应体变更处理

    func handleResponseBodyChanged(_ newBody: String) {
        guard let selectedRequestIndex else { return }
        requests[selectedRequestIndex].responseBody = newBody
        latestResponse = RequestResponseSnapshot(
            statusCode: requests[selectedRequestIndex].responseStatusCode,
            duration: requests[selectedRequestIndex].responseDuration,
            headersText: requests[selectedRequestIndex].responseHeadersText,
            bodyText: newBody,
            timestamp: Date()
        )
        projectStore.syncRequestToDatabase(requests[selectedRequestIndex], isNew: false)
    }

    // MARK: - DocServer 重启

    func restartDocServer(port: Int) {
        newDocServerPort = port
    }

    func handleDocServerPortChange(_ newPort: Int?) {
        guard let newPort else { return }
        docServer?.stop()
        guard let mysqlDatabase else { return }
        docServer = DocServer(port: newPort, database: mysqlDatabase)
        try? docServer?.start()
        newDocServerPort = nil
    }
}

// MARK: - 错误类型

enum RequestComposerError: LocalizedError {
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

// MARK: - 历史记录持久化

@MainActor
final class HistoryPersistence {
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
        guard let repository else { return }

        do {
            try repository.insertHistory(message: message, createdAt: createdAt)
        } catch {
            print("保存历史记录失败: \(error)")
        }
    }

    func loadItems() -> [RequestHistoryItem] {
        guard let repository else { return [] }

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

    func loadItems(search: String?) -> [RequestHistoryItem] {
        guard let repository else { return [] }

        do {
            let records = try repository.fetchHistory(search: search)
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
