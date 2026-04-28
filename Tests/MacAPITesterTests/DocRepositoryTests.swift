import Testing
@testable import MacAPITester

@Suite("DocRepository Tests", .serialized)
struct DocRepositoryTests {

    private func setup(_ db: MySQLDatabase) throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS projects (
                id VARCHAR(36) PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        """)
        try db.execute("INSERT IGNORE INTO projects (id, name) VALUES ('test-project-1', 'Test Project')")
        try db.execute("INSERT IGNORE INTO projects (id, name) VALUES ('proj-1', 'Project 1')")
        try db.execute("""
            CREATE TABLE IF NOT EXISTS api_documents (
                id VARCHAR(36) PRIMARY KEY,
                project_id VARCHAR(36) NOT NULL,
                title VARCHAR(255) NOT NULL,
                html_content LONGTEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
                INDEX idx_project_id (project_id)
            )
        """)
        try db.execute("DELETE FROM api_documents WHERE project_id IN ('test-project-1', 'proj-1')")
    }

    private func cleanup(_ db: MySQLDatabase) throws {
        try db.execute("DELETE FROM api_documents WHERE project_id IN ('test-project-1', 'proj-1')")
        try db.execute("DELETE FROM projects WHERE id IN ('test-project-1', 'proj-1')")
    }

    @Test func testSaveAndFetchDocument() throws {
        let database = try MySQLDatabase()
        try setup(database)

        let repository = try DocRepository(database: database)

        let html = "<html><body>Test</body></html>"
        try repository.saveDocument(
            id: "test-doc-1",
            projectID: "test-project-1",
            title: "测试文档",
            html: html
        )

        let fetched = try repository.fetchDocument(projectID: "test-project-1")
        #expect(fetched != nil)
        #expect(fetched?.title == "测试文档")
        #expect(fetched?.htmlContent == html)

        try cleanup(database)
    }

    @Test func testFetchAllDocuments() throws {
        let database = try MySQLDatabase()
        try setup(database)

        let repository = try DocRepository(database: database)

        try repository.saveDocument(id: "doc-1", projectID: "proj-1", title: "Doc 1", html: "<html>1</html>")
        try repository.saveDocument(id: "doc-2", projectID: "proj-1", title: "Doc 2", html: "<html>2</html>")

        let all = try repository.fetchAllDocuments()
        #expect(all.count >= 2)

        try cleanup(database)
    }

    @Test func testDeleteDocument() throws {
        let database = try MySQLDatabase()
        try setup(database)

        let repository = try DocRepository(database: database)

        try repository.saveDocument(id: "doc-to-delete", projectID: "proj-1", title: "Delete Me", html: "<html></html>")
        try repository.deleteDocument(id: "doc-to-delete")

        let results = try database.query(
            "SELECT * FROM api_documents WHERE id = 'doc-to-delete'"
        )
        #expect(results.isEmpty)

        try cleanup(database)
    }

    @Test func testUpsertDocument() throws {
        let database = try MySQLDatabase()
        try setup(database)

        let repository = try DocRepository(database: database)

        try repository.saveDocument(id: "doc-upsert", projectID: "proj-1", title: "Original", html: "<html>old</html>")
        try repository.saveDocument(id: "doc-upsert", projectID: "proj-1", title: "Updated", html: "<html>new</html>")

        let results = try database.query(
            "SELECT title, html_content FROM api_documents WHERE id = 'doc-upsert'"
        )
        #expect(results.count == 1)
        #expect(results[0]["title"] as? String == "Updated")
        #expect(results[0]["html_content"] as? String == "<html>new</html>")

        try cleanup(database)
    }
}
