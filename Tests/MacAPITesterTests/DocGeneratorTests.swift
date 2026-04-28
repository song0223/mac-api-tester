import Foundation
import Testing
@testable import MacAPITester

@Suite("DocGenerator Tests")
struct DocGeneratorTests {
    @Test func testBuildDocModel() {
        let generator = DocGenerator()

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

        let model = generator.buildDocModel(project: project, requests: requests)

        #expect(model.projectName == "测试项目")
        #expect(model.sections.count == 1)
        #expect(model.sections.first?.name == "获取用户")
    }

    @Test func testRenderMarkdown() {
        let generator = DocGenerator()

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

        let markdown = generator.renderMarkdown(model)

        #expect(markdown.contains("# API文档 - 测试项目"))
        #expect(markdown.contains("## 获取用户"))
        #expect(markdown.contains("GET"))
    }
}
