import Foundation

final class DatabaseMigration {
    private let mysqlDatabase: MySQLDatabase
    private let sqliteDatabase: SQLiteDatabase?

    init(mysqlDatabase: MySQLDatabase, sqliteDatabase: SQLiteDatabase? = nil) {
        self.mysqlDatabase = mysqlDatabase
        self.sqliteDatabase = sqliteDatabase
    }

    func migrate() throws {
        try createTables()
        if let sqliteDatabase {
            try migrateDataFromSQLite(sqliteDatabase)
        }
    }

    private func createTables() throws {
        try mysqlDatabase.execute("""
            CREATE TABLE IF NOT EXISTS projects (
                id VARCHAR(36) PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        """)

        try mysqlDatabase.execute("""
            CREATE TABLE IF NOT EXISTS request_documents (
                id VARCHAR(36) PRIMARY KEY,
                project_id VARCHAR(36) NOT NULL,
                name VARCHAR(255) NOT NULL,
                api_status VARCHAR(50) DEFAULT '接口状态',
                description TEXT,
                method VARCHAR(10) NOT NULL DEFAULT 'GET',
                url_string TEXT NOT NULL,
                query_text TEXT,
                headers_text TEXT,
                body_text TEXT,
                variables_text TEXT,
                auth_type VARCHAR(20) DEFAULT 'none',
                auth_config JSON,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
            )
        """)

        try mysqlDatabase.execute("""
            CREATE TABLE IF NOT EXISTS request_history (
                id VARCHAR(36) PRIMARY KEY,
                request_id VARCHAR(36),
                method VARCHAR(10) NOT NULL,
                url TEXT NOT NULL,
                status_code INT,
                response_time_ms INT,
                request_headers JSON,
                request_body TEXT,
                response_headers JSON,
                response_body TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (request_id) REFERENCES request_documents(id) ON DELETE SET NULL
            )
        """)
    }

    private func migrateDataFromSQLite(_ sqliteDatabase: SQLiteDatabase) throws {
        let projects = try sqliteDatabase.query("SELECT * FROM projects")
        for project in projects {
            let id = project["id"] as? String ?? ""
            let name = project["name"] as? String ?? ""
            try mysqlDatabase.execute(
                "INSERT INTO projects (id, name) VALUES (?, ?)",
                parameters: [.string(id), .string(name)]
            )
        }

        let requests = try sqliteDatabase.query("SELECT * FROM request_documents")
        for request in requests {
            let id = request["id"] as? String ?? ""
            let projectId = request["project_id"] as? String ?? ""
            let name = request["name"] as? String ?? ""
            let method = request["method"] as? String ?? "GET"
            let urlString = request["url_string"] as? String ?? ""
            let queryText = request["query_text"] as? String ?? ""
            let headersText = request["headers_text"] as? String ?? ""
            let bodyText = request["body_text"] as? String ?? ""
            let variablesText = request["variables_text"] as? String ?? ""
            try mysqlDatabase.execute(
                """
                INSERT INTO request_documents (id, project_id, name, method, url_string, query_text, headers_text, body_text, variables_text)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                parameters: [.string(id), .string(projectId), .string(name), .string(method), .string(urlString), .string(queryText), .string(headersText), .string(bodyText), .string(variablesText)]
            )
        }

        let history = try sqliteDatabase.query("SELECT * FROM request_history")
        for record in history {
            let id = record["id"] as? String ?? ""
            let requestId = record["request_id"] as? String ?? ""
            let method = record["method"] as? String ?? ""
            let url = record["url"] as? String ?? ""
            let statusCode = record["status_code"] as? Int ?? 0
            let responseTimeMs = record["response_time_ms"] as? Int ?? 0
            let createdAt = record["created_at"] as? String ?? ""
            try mysqlDatabase.execute(
                """
                INSERT INTO request_history (id, request_id, method, url, status_code, response_time_ms, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                parameters: [.string(id), .string(requestId), .string(method), .string(url), .int(statusCode), .int(responseTimeMs), .string(createdAt)]
            )
        }
    }
}
