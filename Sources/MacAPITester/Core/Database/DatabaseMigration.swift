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
        try mysqlDatabase.beginTransaction()
        do {
            try migrateProjects(sqliteDatabase)
            try migrateRequestDocuments(sqliteDatabase)
            try migrateRequestHistory(sqliteDatabase)
            try mysqlDatabase.commit()
        } catch {
            try? mysqlDatabase.rollback()
            throw error
        }
    }

    private func migrateProjects(_ sqliteDatabase: SQLiteDatabase) throws {
        let rows = try sqliteDatabase.query("SELECT * FROM projects")
        let columns = ["id", "name"]
        var batch: [[MySQLValue]] = []
        for row in rows {
            let params: [MySQLValue] = [
                .string(row["id"] as? String ?? ""),
                .string(row["name"] as? String ?? ""),
            ]
            batch.append(params)
        }
        try insertBatch(table: "projects", columns: columns, batch: batch)
    }

    private func migrateRequestDocuments(_ sqliteDatabase: SQLiteDatabase) throws {
        let rows = try sqliteDatabase.query("SELECT * FROM request_documents")
        let columns = [
            "id", "project_id", "name", "api_status", "description",
            "method", "url_string", "query_text", "headers_text",
            "body_text", "variables_text", "auth_type", "auth_config",
        ]
        var batch: [[MySQLValue]] = []
        for row in rows {
            let params: [MySQLValue] = [
                .string(row["id"] as? String ?? ""),
                .string(row["project_id"] as? String ?? ""),
                .string(row["name"] as? String ?? ""),
                .string(row["api_status"] as? String ?? "接口状态"),
                nullableString(row["description"]),
                .string(row["method"] as? String ?? "GET"),
                .string(row["url_string"] as? String ?? ""),
                .string(row["query_text"] as? String ?? ""),
                .string(row["headers_text"] as? String ?? ""),
                .string(row["body_text"] as? String ?? ""),
                .string(row["variables_text"] as? String ?? ""),
                .string(row["auth_type"] as? String ?? "none"),
                nullableString(row["auth_config"]),
            ]
            batch.append(params)
        }
        try insertBatch(table: "request_documents", columns: columns, batch: batch)
    }

    private func migrateRequestHistory(_ sqliteDatabase: SQLiteDatabase) throws {
        let rows = try sqliteDatabase.query("SELECT * FROM request_history")
        let columns = [
            "id", "request_id", "method", "url", "status_code",
            "response_time_ms", "request_headers", "request_body",
            "response_headers", "response_body", "created_at",
        ]
        var batch: [[MySQLValue]] = []
        for row in rows {
            let params: [MySQLValue] = [
                .string(row["id"] as? String ?? ""),
                nullableString(row["request_id"]),
                .string(row["method"] as? String ?? ""),
                .string(row["url"] as? String ?? ""),
                nullableInt(row["status_code"]),
                nullableInt(row["response_time_ms"]),
                nullableString(row["request_headers"]),
                nullableString(row["request_body"]),
                nullableString(row["response_headers"]),
                nullableString(row["response_body"]),
                nullableString(row["created_at"]),
            ]
            batch.append(params)
        }
        try insertBatch(table: "request_history", columns: columns, batch: batch)
    }

    private func nullableString(_ value: Any?) -> MySQLValue {
        if let val = value as? String { return .string(val) }
        if value is NSNull { return .null }
        if value == nil { return .null }
        return .string(String(describing: value!))
    }

    private func nullableInt(_ value: Any?) -> MySQLValue {
        if let val = value as? Int { return .int(val) }
        if let val = value as? Int64 { return .int(Int(val)) }
        return .null
    }

    private static let batchSize = 500

    private func insertBatch(table: String, columns: [String], batch: [[MySQLValue]]) throws {
        let columnList = columns.joined(separator: ", ")
        for chunkStart in stride(from: 0, to: batch.count, by: Self.batchSize) {
            let chunkEnd = min(chunkStart + Self.batchSize, batch.count)
            let chunk = Array(batch[chunkStart..<chunkEnd])

            var valueClauses: [String] = []
            var params: [MySQLValue] = []
            for row in chunk {
                let placeholders = Array(repeating: "?", count: columns.count).joined(separator: ", ")
                valueClauses.append("(\(placeholders))")
                params.append(contentsOf: row)
            }

            let sql = """
                INSERT IGNORE INTO \(table) (\(columnList))
                VALUES \(valueClauses.joined(separator: ", "))
                """
            try mysqlDatabase.execute(sql, parameters: params)
        }
    }
}
