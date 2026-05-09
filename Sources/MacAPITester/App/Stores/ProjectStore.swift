import Foundation
import SwiftUI

@Observable
@MainActor
final class ProjectStore {
    var projects: [RequestProject] = []
    var selectedProjectID: RequestProject.ID?
    var requests: [RequestDocument] = []
    var openedRequestIDs: [RequestDocument.ID] = []
    var selectedRequestID: RequestDocument.ID?

    // 缓存的计算结果
    private(set) var openedRequests: [RequestDocument] = []
    private(set) var requestCountByProject: [RequestProject.ID: Int] = [:]

    var selectedRequestIndex: Int? {
        requests.firstIndex(where: { $0.id == selectedRequestID })
    }

    var selectedRequestBinding: Binding<RequestDocument>? {
        guard let selectedRequestIndex else { return nil }
        return Binding(
            get: { self.requests[selectedRequestIndex] },
            set: { self.requests[selectedRequestIndex] = $0 }
        )
    }

    // 数据库仓库
    var projectRepository: MySQLProjectRepository?
    var requestDocumentRepository: MySQLRequestDocumentRepository?

    init() {}

    // MARK: - 缓存更新

    func updateOpenedRequests() {
        openedRequests = openedRequestIDs.compactMap { id in
            requests.first(where: { $0.id == id })
        }
        .filter { request in
            guard let selectedProjectID else { return true }
            return request.projectID == selectedProjectID
        }
    }

    func updateRequestCountByProject() {
        requestCountByProject = requests.reduce(into: [RequestProject.ID: Int]()) { partial, request in
            partial[request.projectID, default: 0] += 1
        }
    }

    func refreshCaches() {
        updateOpenedRequests()
        updateRequestCountByProject()
    }

    // MARK: - 数据库同步

    func syncProjectToDatabase(_ project: RequestProject, isNew: Bool) {
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

    func syncProjectDeletion(_ id: RequestProject.ID) {
        guard let projectRepository else { return }

        do {
            try projectRepository.deleteProject(id: id.uuidString)
        } catch {
            print("从数据库删除项目失败: \(error)")
        }
    }

    func syncRequestToDatabase(_ request: RequestDocument, isNew: Bool) {
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

    func syncRequestDeletion(_ id: RequestDocument.ID) {
        guard let requestDocumentRepository else { return }

        do {
            try requestDocumentRepository.deleteRequestDocument(id: id.uuidString)
        } catch {
            print("从数据库删除请求失败: \(error)")
        }
    }

    // MARK: - 项目操作

    func addProject() {
        let project = RequestProject(name: "项目 \(projects.count + 1)")
        projects.append(project)
        selectedProjectID = project.id
        let seedRequest = RequestDocument.starter(named: "Request 1", projectID: project.id)
        requests.append(seedRequest)
        openRequestTabIfNeeded(seedRequest.id)
        selectedRequestID = seedRequest.id

        // 同步到数据库
        syncProjectToDatabase(project, isNew: true)
        syncRequestToDatabase(seedRequest, isNew: true)
        refreshCaches()
    }

    func renameProject(_ id: RequestProject.ID, _ newName: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = newName

        // 同步到数据库
        syncProjectToDatabase(projects[index], isNew: false)
    }

    func deleteProject(_ id: RequestProject.ID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == id }) else { return }

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
            }
        }

        // 从数据库删除
        syncProjectDeletion(id)
        for requestID in removingRequestIDs {
            syncRequestDeletion(requestID)
        }
        refreshCaches()
    }

    // MARK: - 请求操作

    func addRequest() {
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

        // 同步到数据库
        syncRequestToDatabase(request, isNew: true)
        refreshCaches()
    }

    func closeRequestTab(_ id: RequestDocument.ID) {
        guard let index = openedRequestIDs.firstIndex(of: id) else { return }

        openedRequestIDs.remove(at: index)

        if selectedRequestID == id {
            if let fallbackID = openedRequestIDs.last {
                selectedRequestID = fallbackID
            } else {
                selectedRequestID = nil
            }
        }
        updateOpenedRequests()
    }

    func deleteRequest(_ id: RequestDocument.ID) {
        guard let requestIndex = requests.firstIndex(where: { $0.id == id }) else { return }

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
            }
        }

        // 从数据库删除
        syncRequestDeletion(id)
        refreshCaches()
    }

    func openRequestTabIfNeeded(_ id: RequestDocument.ID) {
        guard requests.contains(where: { $0.id == id }) else { return }
        if !openedRequestIDs.contains(id) {
            openedRequestIDs.append(id)
            updateOpenedRequests()
        }
    }

    // MARK: - 选中变更处理

    func handleSelectedRequestChange(_ newValue: RequestDocument.ID?) {
        guard let newValue else { return }
        openRequestTabIfNeeded(newValue)
        if let ownerProjectID = requests.first(where: { $0.id == newValue })?.projectID {
            selectedProjectID = ownerProjectID
        }
    }

    func handleSelectedProjectChange(_ newValue: RequestProject.ID?) {
        guard let projectID = newValue else { return }

        // 清空标签页，只保留新项目的接口
        openedRequestIDs = openedRequestIDs.filter { id in
            requests.contains(where: { $0.id == id && $0.projectID == projectID })
        }

        // 如果当前选中的接口不属于新项目，切换到新项目的第一个接口
        if let selectedRequestID,
           requests.contains(where: { $0.id == selectedRequestID && $0.projectID == projectID }) {
            // 当前接口属于新项目，保持不变
        } else {
            let fallback = requests.first(where: { $0.projectID == projectID })
            self.selectedRequestID = fallback?.id
            if let fallback {
                openRequestTabIfNeeded(fallback.id)
            }
        }
        updateOpenedRequests()
    }

    // MARK: - cURL 导入

    func importCurlResult(_ result: CurlParseResult) {
        guard let selectedProjectID else { return }

        // 构建 headers 文本
        var headersText = ""
        for (key, value) in result.headers {
            headersText += "\(key): \(value)\n"
        }

        // 创建新的请求文档
        let newRequest = RequestDocument(
            projectID: selectedProjectID,
            name: "从 cURL 导入",
            method: result.method,
            urlString: result.url,
            headersText: headersText,
            bodyText: result.body ?? ""
        )

        // 添加到请求列表
        requests.append(newRequest)
        openedRequestIDs.append(newRequest.id)
        selectedRequestID = newRequest.id

        // 同步到数据库
        syncRequestToDatabase(newRequest, isNew: true)
        refreshCaches()
    }

    func copyAsCurl(_ document: RequestDocument) {
        let exporter = CurlExporter()
        let curl = exporter.export(document)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(curl, forType: .string)
    }
}
