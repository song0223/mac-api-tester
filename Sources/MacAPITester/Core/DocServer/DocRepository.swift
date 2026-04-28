import Foundation

final class DocRepository: MySQLRepository {

    override init(database: MySQLDatabase) throws {
        try super.init(database: database)
        try createTable()
    }

    private func createTable() throws {
        try database.execute("""
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
    }

    func saveDocument(id: String, projectID: String, title: String, html: String) throws {
        try database.execute(
            """
            INSERT INTO api_documents (id, project_id, title, html_content)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE title = ?, html_content = ?, updated_at = CURRENT_TIMESTAMP
            """,
            parameters: [
                .string(id),
                .string(projectID),
                .string(title),
                .string(html),
                .string(title),
                .string(html),
            ]
        )
    }

    func fetchDocument(projectID: String) throws -> (id: String, title: String, html: String)? {
        let results = try database.query(
            "SELECT id, title, html_content FROM api_documents WHERE project_id = ? ORDER BY updated_at DESC LIMIT 1",
            parameters: [.string(projectID)]
        )

        guard let row = results.first,
              let id = row["id"] as? String,
              let title = row["title"] as? String,
              let html = row["html_content"] as? String else {
            return nil
        }

        return (id: id, title: title, html: html)
    }

    func fetchAllDocuments() throws -> [(id: String, projectID: String, title: String)] {
        let results = try database.query("SELECT id, project_id, title FROM api_documents ORDER BY updated_at DESC")

        return results.compactMap { row in
            guard let id = row["id"] as? String,
                  let projectID = row["project_id"] as? String,
                  let title = row["title"] as? String else {
                return nil
            }
            return (id: id, projectID: projectID, title: title)
        }
    }

    func deleteDocument(id: String) throws {
        try database.execute(
            "DELETE FROM api_documents WHERE id = ?",
            parameters: [.string(id)]
        )
    }
}
