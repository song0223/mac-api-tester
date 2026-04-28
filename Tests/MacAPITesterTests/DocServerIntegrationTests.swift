import Foundation
import Testing
@testable import MacAPITester

@Suite("DocServer Integration Tests", .serialized)
struct DocServerIntegrationTests {

    private func setup(_ db: MySQLDatabase) throws {
        try db.execute("SET FOREIGN_KEY_CHECKS = 0")
        try db.execute("""
            CREATE TABLE IF NOT EXISTS projects (
                id VARCHAR(36) PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        """)
        try db.execute("""
            CREATE TABLE IF NOT EXISTS api_documents (
                id VARCHAR(36) PRIMARY KEY,
                project_id VARCHAR(36) NOT NULL,
                title VARCHAR(255) NOT NULL,
                html_content LONGTEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_project_id (project_id)
            )
        """)
        try db.execute("SET FOREIGN_KEY_CHECKS = 1")
    }

    private func cleanup(_ db: MySQLDatabase, projectID: String) throws {
        try db.execute("DELETE FROM api_documents WHERE project_id = '\(projectID)'")
        try db.execute("DELETE FROM projects WHERE id = '\(projectID)'")
    }

    @Test func testEndToEndDocumentGeneration() throws {
        let database = try MySQLDatabase()
        let projectID = UUID()
        try setup(database)
        try database.execute("INSERT IGNORE INTO projects (id, name) VALUES ('\(projectID.uuidString)', '测试项目')")

        let repository = try DocRepository(database: database)

        let project = RequestProject(id: projectID, name: "测试项目")
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
                variablesText: "token=abc123"
            )
        ]

        let model = DocGenerator.buildDocModel(project: project, requests: requests)
        let markdown = DocGenerator.renderMarkdown(model)
        let html = HTMLRenderer().render(markdown, title: project.name)

        try repository.saveDocument(
            id: project.id.uuidString,
            projectID: project.id.uuidString,
            title: project.name,
            html: html
        )

        let fetched = try repository.fetchDocument(projectID: project.id.uuidString)
        #expect(fetched != nil)
        #expect(fetched?.title == "测试项目")
        #expect(fetched?.htmlContent.contains("获取用户") == true)

        try cleanup(database, projectID: projectID.uuidString)
    }

    @Test func testEndToEndMultipleRequests() throws {
        let database = try MySQLDatabase()
        let projectID = UUID()
        try setup(database)
        try database.execute("INSERT IGNORE INTO projects (id, name) VALUES ('\(projectID.uuidString)', '多请求项目')")

        let repository = try DocRepository(database: database)

        let project = RequestProject(id: projectID, name: "多请求项目")
        let requests = [
            RequestDocument(
                id: UUID(),
                projectID: project.id,
                name: "获取用户列表",
                method: .get,
                urlString: "https://api.example.com/users",
                queryText: "page=1",
                headersText: "",
                bodyText: "",
                variablesText: ""
            ),
            RequestDocument(
                id: UUID(),
                projectID: project.id,
                name: "创建用户",
                method: .post,
                urlString: "https://api.example.com/users",
                queryText: "",
                headersText: "Content-Type: application/json",
                bodyText: "{\"name\": \"test\"}",
                variablesText: ""
            )
        ]

        let model = DocGenerator.buildDocModel(project: project, requests: requests)
        let markdown = DocGenerator.renderMarkdown(model)
        let html = HTMLRenderer().render(markdown, title: project.name)

        try repository.saveDocument(
            id: project.id.uuidString,
            projectID: project.id.uuidString,
            title: project.name,
            html: html
        )

        let fetched = try repository.fetchDocument(projectID: project.id.uuidString)
        #expect(fetched != nil)
        #expect(fetched?.title == "多请求项目")
        #expect(fetched?.htmlContent.contains("获取用户列表") == true)
        #expect(fetched?.htmlContent.contains("创建用户") == true)

        try cleanup(database, projectID: projectID.uuidString)
    }

    @Test func testEndToEndDocumentUpdate() throws {
        let database = try MySQLDatabase()
        let projectID = UUID()
        try setup(database)
        try database.execute("INSERT IGNORE INTO projects (id, name) VALUES ('\(projectID.uuidString)', '更新项目')")

        let repository = try DocRepository(database: database)

        let project = RequestProject(id: projectID, name: "更新项目")

        let modelV1 = DocGenerator.buildDocModel(project: project, requests: [])
        let htmlV1 = HTMLRenderer().render(DocGenerator.renderMarkdown(modelV1), title: project.name)

        try repository.saveDocument(
            id: project.id.uuidString,
            projectID: project.id.uuidString,
            title: project.name,
            html: htmlV1
        )

        let requestsV2 = [
            RequestDocument(
                id: UUID(),
                projectID: project.id,
                name: "新增接口",
                method: .post,
                urlString: "https://api.example.com/new",
                queryText: "",
                headersText: "",
                bodyText: "",
                variablesText: ""
            )
        ]
        let modelV2 = DocGenerator.buildDocModel(project: project, requests: requestsV2)
        let htmlV2 = HTMLRenderer().render(DocGenerator.renderMarkdown(modelV2), title: project.name)

        try repository.saveDocument(
            id: project.id.uuidString,
            projectID: project.id.uuidString,
            title: project.name,
            html: htmlV2
        )

        let fetched = try repository.fetchDocument(projectID: project.id.uuidString)
        #expect(fetched != nil)
        #expect(fetched?.htmlContent.contains("新增接口") == true)

        try cleanup(database, projectID: projectID.uuidString)
    }
}
