import Foundation
import Testing
@testable import MacAPITester

@Suite("DocGenerator Tests")
struct DocGeneratorTests {
    @Test func testBuildDocModel() {
        let project = RequestProject(id: UUID(), name: "测试项目")
        let requests = [
            RequestDocument(
                id: UUID(),
                projectID: project.id,
                name: "获取用户",
                method: .get,
                urlString: "https://api.example.com/users",
                queryText: "page=1",
                headersText: "Accept: application/json",
                bodyText: "",
                variablesText: ""
            )
        ]

        let model = DocGenerator.buildDocModel(project: project, requests: requests)

        #expect(model.projectName == "测试项目")
        #expect(model.sections.count == 1)
        #expect(model.sections.first?.name == "获取用户")
    }

    @Test func testRenderMarkdown() {
        let model = APIDocModel(
            projectID: "test-id",
            projectName: "测试项目",
            generatedAt: Date(),
            sections: [
                APIDocSection(
                    id: "section-1",
                    name: "获取用户",
                    method: "GET",
                    url: "https://api.example.com/users",
                    description: "获取用户列表",
                    authType: "None",
                    queryParams: [],
                    headers: [],
                    bodyParams: [],
                    requestBody: nil,
                    responseBody: nil,
                    variables: [:]
                )
            ]
        )

        let markdown = DocGenerator.renderMarkdown(model)

        #expect(markdown.contains("# API文档 - 测试项目"))
        #expect(markdown.contains("## 获取用户"))
        #expect(markdown.contains("GET"))
    }

    @Test func testBuildDocModelWithEmptyRequests() {
        let project = RequestProject(id: UUID(), name: "空项目")
        let model = DocGenerator.buildDocModel(project: project, requests: [])

        #expect(model.projectName == "空项目")
        #expect(model.sections.isEmpty)
    }

    @Test func testBuildDocModelParsesQueryParams() {
        let project = RequestProject(id: UUID(), name: "测试")
        let request = RequestDocument(
            id: UUID(),
            projectID: project.id,
            name: "搜索",
            method: .get,
            urlString: "https://api.example.com/search",
            queryText: "q=hello\npage=1",
            headersText: "",
            bodyText: "",
            variablesText: ""
        )

        let model = DocGenerator.buildDocModel(project: project, requests: [request])
        let params = model.sections[0].queryParams

        #expect(params.count == 2)
        #expect(params[0].name == "q")
        #expect(params[1].name == "page")
    }

    @Test func testBuildDocModelSkipsMalformedQueryLines() {
        let project = RequestProject(id: UUID(), name: "测试")
        let request = RequestDocument(
            id: UUID(),
            projectID: project.id,
            name: "请求",
            method: .get,
            urlString: "https://api.example.com/test",
            queryText: "valid=yes\nno_separator_here\nalso=ok",
            headersText: "",
            bodyText: "",
            variablesText: ""
        )

        let model = DocGenerator.buildDocModel(project: project, requests: [request])
        let params = model.sections[0].queryParams

        #expect(params.count == 2)
        #expect(params[0].name == "valid")
        #expect(params[1].name == "also")
    }

    @Test func testBuildDocModelSkipsBodyParsingForJSON() {
        let project = RequestProject(id: UUID(), name: "测试")
        let jsonBody = "{\"name\": \"test\", \"value\": 42}"
        let request = RequestDocument(
            id: UUID(),
            projectID: project.id,
            name: "创建用户",
            method: .post,
            urlString: "https://api.example.com/users",
            queryText: "",
            headersText: "",
            bodyText: jsonBody,
            variablesText: ""
        )

        let model = DocGenerator.buildDocModel(project: project, requests: [request])
        let section = model.sections[0]

        #expect(section.bodyParams.isEmpty)
        #expect(section.requestBody == jsonBody)
    }

    @Test func testBuildDocModelSkipsBodyParsingForJSONArray() {
        let project = RequestProject(id: UUID(), name: "测试")
        let jsonArray = "[{\"id\": 1}]"
        let request = RequestDocument(
            id: UUID(),
            projectID: project.id,
            name: "批量操作",
            method: .post,
            urlString: "https://api.example.com/batch",
            queryText: "",
            headersText: "",
            bodyText: jsonArray,
            variablesText: ""
        )

        let model = DocGenerator.buildDocModel(project: project, requests: [request])
        let section = model.sections[0]

        #expect(section.bodyParams.isEmpty)
        #expect(section.requestBody == jsonArray)
    }

    @Test func testBuildDocModelParsesFormBody() {
        let project = RequestProject(id: UUID(), name: "测试")
        let request = RequestDocument(
            id: UUID(),
            projectID: project.id,
            name: "表单提交",
            method: .post,
            urlString: "https://api.example.com/form",
            queryText: "",
            headersText: "",
            bodyText: "username=admin\npassword=secret",
            variablesText: ""
        )

        let model = DocGenerator.buildDocModel(project: project, requests: [request])
        let params = model.sections[0].bodyParams

        #expect(params.count == 2)
        #expect(params[0].name == "username")
        #expect(params[1].name == "password")
    }

    @Test func testBuildDocModelParsesVariables() {
        let project = RequestProject(id: UUID(), name: "测试")
        let request = RequestDocument(
            id: UUID(),
            projectID: project.id,
            name: "请求",
            method: .get,
            urlString: "https://api.example.com/users",
            queryText: "",
            headersText: "",
            bodyText: "",
            variablesText: "BASE_URL=https://api.example.com\nTOKEN=abc123"
        )

        let model = DocGenerator.buildDocModel(project: project, requests: [request])
        let variables = model.sections[0].variables

        #expect(variables["BASE_URL"] == "https://api.example.com")
        #expect(variables["TOKEN"] == "abc123")
    }

    @Test func testBuildDocModelEmptyFields() {
        let project = RequestProject(id: UUID(), name: "测试")
        let request = RequestDocument(
            id: UUID(),
            projectID: project.id,
            name: "空请求",
            method: .get,
            urlString: "https://api.example.com/empty",
            queryText: "",
            headersText: "",
            bodyText: "",
            variablesText: ""
        )

        let model = DocGenerator.buildDocModel(project: project, requests: [request])
        let section = model.sections[0]

        #expect(section.queryParams.isEmpty)
        #expect(section.headers.isEmpty)
        #expect(section.bodyParams.isEmpty)
        #expect(section.requestBody == nil)
        #expect(section.variables.isEmpty)
    }

    @Test func testRenderMarkdownContainsAllSections() {
        let model = APIDocModel(
            projectID: "id",
            projectName: "项目",
            generatedAt: Date(),
            sections: [
                APIDocSection(
                    id: "s1",
                    name: "第一个",
                    method: "GET",
                    url: "/a",
                    description: "",
                    authType: "None",
                    queryParams: [],
                    headers: [],
                    bodyParams: [],
                    requestBody: nil,
                    responseBody: nil,
                    variables: [:]
                ),
                APIDocSection(
                    id: "s2",
                    name: "第二个",
                    method: "POST",
                    url: "/b",
                    description: "",
                    authType: "Bearer",
                    queryParams: [],
                    headers: [],
                    bodyParams: [],
                    requestBody: nil,
                    responseBody: nil,
                    variables: [:]
                )
            ]
        )

        let markdown = DocGenerator.renderMarkdown(model)

        #expect(markdown.contains("## 第一个"))
        #expect(markdown.contains("## 第二个"))
        #expect(markdown.contains("GET"))
        #expect(markdown.contains("POST"))
    }

    @Test func testRenderMarkdownIncludesRequestBody() {
        let model = APIDocModel(
            projectID: "id",
            projectName: "项目",
            generatedAt: Date(),
            sections: [
                APIDocSection(
                    id: "s1",
                    name: "POST请求",
                    method: "POST",
                    url: "/api",
                    description: "",
                    authType: "None",
                    queryParams: [],
                    headers: [],
                    bodyParams: [],
                    requestBody: "{\"key\": \"value\"}",
                    responseBody: nil,
                    variables: [:]
                )
            ]
        )

        let markdown = DocGenerator.renderMarkdown(model)

        #expect(markdown.contains("### 请求示例"))
        #expect(markdown.contains("{\"key\": \"value\"}"))
    }

    @Test func testBuildDocModelParsesHeaders() {
        let project = RequestProject(id: UUID(), name: "测试")
        let request = RequestDocument(
            id: UUID(),
            projectID: project.id,
            name: "带Header",
            method: .get,
            urlString: "https://api.example.com/data",
            queryText: "",
            headersText: "Accept: application/json\nAuthorization: Bearer token",
            bodyText: "",
            variablesText: ""
        )

        let model = DocGenerator.buildDocModel(project: project, requests: [request])
        let headers = model.sections[0].headers

        #expect(headers.count == 2)
        #expect(headers[0].name == "Accept")
        #expect(headers[1].name == "Authorization")
    }
}
