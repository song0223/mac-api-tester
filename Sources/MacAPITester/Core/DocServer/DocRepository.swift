import Foundation

struct MySQLDocRecord: Equatable {
    let id: String
    let projectID: String
    let title: String
    let htmlContent: String
}

final class DocRepository: MySQLRepository {

    override init(database: MySQLDatabase) throws {
        try super.init(database: database)
        // 表已在 DatabaseMigration 中创建
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

    func fetchDocument(projectID: String) throws -> MySQLDocRecord? {
        let results = try database.query(
            "SELECT id, project_id, title, html_content FROM api_documents WHERE project_id = ? ORDER BY updated_at DESC LIMIT 1",
            parameters: [.string(projectID)]
        )

        guard let row = results.first,
              let id = row["id"] as? String,
              let projectID = row["project_id"] as? String,
              let title = row["title"] as? String,
              let htmlContent = row["html_content"] as? String else {
            return nil
        }

        return MySQLDocRecord(id: id, projectID: projectID, title: title, htmlContent: htmlContent)
    }

    func fetchDocuments(projectID: String) throws -> [MySQLDocRecord] {
        let results = try database.query(
            "SELECT id, project_id, title, html_content FROM api_documents WHERE project_id = ? ORDER BY updated_at DESC",
            parameters: [.string(projectID)]
        )

        return results.compactMap { row in
            guard let id = row["id"] as? String,
                  let projectID = row["project_id"] as? String,
                  let title = row["title"] as? String,
                  let htmlContent = row["html_content"] as? String else {
                return nil
            }
            return MySQLDocRecord(id: id, projectID: projectID, title: title, htmlContent: htmlContent)
        }
    }

    func fetchAllDocuments() throws -> [MySQLDocRecord] {
        let results = try database.query("SELECT id, project_id, title, html_content FROM api_documents ORDER BY updated_at DESC")

        return results.compactMap { row in
            guard let id = row["id"] as? String,
                  let projectID = row["project_id"] as? String,
                  let title = row["title"] as? String,
                  let htmlContent = row["html_content"] as? String else {
                return nil
            }
            return MySQLDocRecord(id: id, projectID: projectID, title: title, htmlContent: htmlContent)
        }
    }

    func deleteDocument(id: String) throws {
        try database.execute(
            "DELETE FROM api_documents WHERE id = ?",
            parameters: [.string(id)]
        )
    }
}
