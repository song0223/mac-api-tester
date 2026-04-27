import Foundation
import Testing
@testable import MacAPITester

@Suite("Database Migration Tests", .serialized)
struct DatabaseMigrationTests {

    private func setupMySQLTables(_ mysqlDb: MySQLDatabase) throws {
        try mysqlDb.execute("DROP TABLE IF EXISTS request_history")
        try mysqlDb.execute("DROP TABLE IF EXISTS request_documents")
        try mysqlDb.execute("DROP TABLE IF EXISTS projects")
    }

    private func createSQLiteSchema(_ sqliteDb: SQLiteDatabase) throws {
        try sqliteDb.execute("""
            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                created_at TEXT,
                updated_at TEXT
            )
        """)
        try sqliteDb.execute("""
            CREATE TABLE IF NOT EXISTS request_documents (
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL,
                name TEXT NOT NULL,
                api_status TEXT DEFAULT '接口状态',
                description TEXT,
                method TEXT NOT NULL DEFAULT 'GET',
                url_string TEXT NOT NULL,
                query_text TEXT,
                headers_text TEXT,
                body_text TEXT,
                variables_text TEXT,
                auth_type TEXT DEFAULT 'none',
                auth_config TEXT,
                created_at TEXT,
                updated_at TEXT
            )
        """)
        try sqliteDb.execute("""
            CREATE TABLE IF NOT EXISTS request_history (
                id TEXT PRIMARY KEY,
                request_id TEXT,
                method TEXT NOT NULL,
                url TEXT NOT NULL,
                status_code INTEGER,
                response_time_ms INTEGER,
                request_headers TEXT,
                request_body TEXT,
                response_headers TEXT,
                response_body TEXT,
                created_at TEXT
            )
        """)
    }

    @Test func createsTablesSuccessfully() throws {
        let mysqlDb = try MySQLDatabase()
        try setupMySQLTables(mysqlDb)

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb)
        try migration.migrate()

        let tables = try mysqlDb.query("SHOW TABLES")
        let tableNames = tables.compactMap { $0.values.first as? String }
        #expect(tableNames.contains("projects"))
        #expect(tableNames.contains("request_documents"))
        #expect(tableNames.contains("request_history"))

        try setupMySQLTables(mysqlDb)
    }

    @Test func createsTablesWithCorrectSchema() throws {
        let mysqlDb = try MySQLDatabase()
        try setupMySQLTables(mysqlDb)

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb)
        try migration.migrate()

        let projectColumns = try mysqlDb.query("DESCRIBE projects")
        let projectColumnNames = projectColumns.compactMap { $0["Field"] as? String }
        #expect(projectColumnNames.contains("id"))
        #expect(projectColumnNames.contains("name"))
        #expect(projectColumnNames.contains("created_at"))
        #expect(projectColumnNames.contains("updated_at"))

        let requestColumns = try mysqlDb.query("DESCRIBE request_documents")
        let requestColumnNames = requestColumns.compactMap { $0["Field"] as? String }
        #expect(requestColumnNames.contains("id"))
        #expect(requestColumnNames.contains("project_id"))
        #expect(requestColumnNames.contains("name"))
        #expect(requestColumnNames.contains("method"))
        #expect(requestColumnNames.contains("url_string"))
        #expect(requestColumnNames.contains("api_status"))
        #expect(requestColumnNames.contains("description"))
        #expect(requestColumnNames.contains("auth_type"))
        #expect(requestColumnNames.contains("auth_config"))

        try setupMySQLTables(mysqlDb)
    }

    @Test func migrationIsIdempotent() throws {
        let mysqlDb = try MySQLDatabase()
        try setupMySQLTables(mysqlDb)

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb)
        try migration.migrate()
        try migration.migrate()

        let tables = try mysqlDb.query("SHOW TABLES")
        let tableNames = tables.compactMap { $0.values.first as? String }
        #expect(tableNames.contains("projects"))
        #expect(tableNames.contains("request_documents"))
        #expect(tableNames.contains("request_history"))

        try setupMySQLTables(mysqlDb)
    }

    @Test func migratesProjectData() throws {
        let mysqlDb = try MySQLDatabase()
        let sqliteDb = try SQLiteDatabase(inMemory: true)
        try setupMySQLTables(mysqlDb)
        try createSQLiteSchema(sqliteDb)

        try sqliteDb.execute("""
            INSERT INTO projects (id, name) VALUES
            ('proj-1', 'Test Project'),
            ('proj-2', '另一个项目')
        """)

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb, sqliteDatabase: sqliteDb)
        try migration.migrate()

        let rows = try mysqlDb.query("SELECT * FROM projects ORDER BY id")
        #expect(rows.count == 2)
        #expect(rows[0]["id"] as? String == "proj-1")
        #expect(rows[0]["name"] as? String == "Test Project")
        #expect(rows[1]["id"] as? String == "proj-2")
        #expect(rows[1]["name"] as? String == "另一个项目")

        try setupMySQLTables(mysqlDb)
    }

    @Test func migratesRequestDocumentDataWithAllColumns() throws {
        let mysqlDb = try MySQLDatabase()
        let sqliteDb = try SQLiteDatabase(inMemory: true)
        try setupMySQLTables(mysqlDb)
        try createSQLiteSchema(sqliteDb)

        try sqliteDb.execute("""
            INSERT INTO projects (id, name) VALUES ('proj-1', 'Test')
        """)
        try sqliteDb.execute("""
            INSERT INTO request_documents
            (id, project_id, name, api_status, description, method, url_string,
             query_text, headers_text, body_text, variables_text, auth_type, auth_config)
            VALUES
            ('req-1', 'proj-1', 'Get Users', '已完成', '获取用户列表', 'GET',
             'https://api.example.com/users', 'page=1', '{"Content-Type":"application/json"}',
             '', '', 'bearer', '{"token":"abc123"}')
        """)

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb, sqliteDatabase: sqliteDb)
        try migration.migrate()

        let rows = try mysqlDb.query("SELECT * FROM request_documents WHERE id = 'req-1'")
        #expect(rows.count == 1)
        let row = rows[0]
        #expect(row["name"] as? String == "Get Users")
        #expect(row["api_status"] as? String == "已完成")
        #expect(row["description"] as? String == "获取用户列表")
        #expect(row["method"] as? String == "GET")
        #expect(row["url_string"] as? String == "https://api.example.com/users")
        #expect(row["query_text"] as? String == "page=1")
        #expect(row["auth_type"] as? String == "bearer")
        let authConfig = row["auth_config"] as? String ?? ""
        #expect(authConfig.contains("\"token\""))
        #expect(authConfig.contains("\"abc123\""))

        try setupMySQLTables(mysqlDb)
    }

    @Test func migratesRequestHistoryDataWithAllColumns() throws {
        let mysqlDb = try MySQLDatabase()
        let sqliteDb = try SQLiteDatabase(inMemory: true)
        try setupMySQLTables(mysqlDb)
        try createSQLiteSchema(sqliteDb)

        try sqliteDb.execute("""
            INSERT INTO projects (id, name) VALUES ('proj-1', 'Test')
        """)
        try sqliteDb.execute("""
            INSERT INTO request_documents
            (id, project_id, name, method, url_string)
            VALUES ('req-1', 'proj-1', 'Test', 'GET', 'https://example.com')
        """)
        try sqliteDb.execute("""
            INSERT INTO request_history
            (id, request_id, method, url, status_code, response_time_ms,
             request_headers, request_body, response_headers, response_body, created_at)
            VALUES
            ('hist-1', 'req-1', 'GET', 'https://example.com/users', 200, 150,
             '{"Accept":"application/json"}', '{"page":1}',
             '{"Content-Type":"application/json"}', '{"users":[]}',
             '2025-01-15 10:30:00')
        """)

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb, sqliteDatabase: sqliteDb)
        try migration.migrate()

        let rows = try mysqlDb.query("SELECT * FROM request_history WHERE id = 'hist-1'")
        #expect(rows.count == 1)
        let row = rows[0]
        #expect(row["request_id"] as? String == "req-1")
        #expect(row["method"] as? String == "GET")
        #expect(row["url"] as? String == "https://example.com/users")

        let statusCode = (row["status_code"] as? String).flatMap(Int.init) ?? (row["status_code"] as? Int)
        #expect(statusCode == 200)

        let responseTime = (row["response_time_ms"] as? String).flatMap(Int.init) ?? (row["response_time_ms"] as? Int)
        #expect(responseTime == 150)

        let reqHeaders = row["request_headers"] as? String ?? ""
        #expect(reqHeaders.contains("\"Accept\""))
        #expect(reqHeaders.contains("\"application/json\""))

        #expect(row["request_body"] as? String == "{\"page\":1}")

        let respHeaders = row["response_headers"] as? String ?? ""
        #expect(respHeaders.contains("\"Content-Type\""))
        #expect(respHeaders.contains("\"application/json\""))

        #expect(row["response_body"] as? String == "{\"users\":[]}")
        #expect(row["created_at"] as? String == "2025-01-15 10:30:00")

        try setupMySQLTables(mysqlDb)
    }

    @Test func dataMigrationIsIdempotent() throws {
        let mysqlDb = try MySQLDatabase()
        let sqliteDb = try SQLiteDatabase(inMemory: true)
        try setupMySQLTables(mysqlDb)
        try createSQLiteSchema(sqliteDb)

        try sqliteDb.execute("INSERT INTO projects (id, name) VALUES ('proj-1', 'Test')")

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb, sqliteDatabase: sqliteDb)
        try migration.migrate()
        try migration.migrate()

        let rows = try mysqlDb.query("SELECT * FROM projects")
        #expect(rows.count == 1)
        #expect(rows[0]["id"] as? String == "proj-1")

        try setupMySQLTables(mysqlDb)
    }

    @Test func migratesEmptyTables() throws {
        let mysqlDb = try MySQLDatabase()
        let sqliteDb = try SQLiteDatabase(inMemory: true)
        try setupMySQLTables(mysqlDb)
        try createSQLiteSchema(sqliteDb)

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb, sqliteDatabase: sqliteDb)
        try migration.migrate()

        let projects = try mysqlDb.query("SELECT * FROM projects")
        let requests = try mysqlDb.query("SELECT * FROM request_documents")
        let history = try mysqlDb.query("SELECT * FROM request_history")
        #expect(projects.count == 0)
        #expect(requests.count == 0)
        #expect(history.count == 0)

        try setupMySQLTables(mysqlDb)
    }

    @Test func migratesSpecialCharacters() throws {
        let mysqlDb = try MySQLDatabase()
        let sqliteDb = try SQLiteDatabase(inMemory: true)
        try setupMySQLTables(mysqlDb)
        try createSQLiteSchema(sqliteDb)

        let specialName = "项目 with 中文 & special chars ~!@#$%^&*()"
        let escapedName = specialName.replacingOccurrences(of: "'", with: "''")
        try sqliteDb.execute("INSERT INTO projects (id, name) VALUES ('proj-1', '\(escapedName)')")

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb, sqliteDatabase: sqliteDb)
        try migration.migrate()

        let rows = try mysqlDb.query("SELECT * FROM projects WHERE id = 'proj-1'")
        #expect(rows.count == 1)
        #expect(rows[0]["name"] as? String == specialName)

        try setupMySQLTables(mysqlDb)
    }

    @Test func migratesNullValues() throws {
        let mysqlDb = try MySQLDatabase()
        let sqliteDb = try SQLiteDatabase(inMemory: true)
        try setupMySQLTables(mysqlDb)
        try createSQLiteSchema(sqliteDb)

        try sqliteDb.execute("""
            INSERT INTO projects (id, name) VALUES ('proj-1', 'Test')
        """)
        try sqliteDb.execute("""
            INSERT INTO request_documents
            (id, project_id, name, method, url_string, description, auth_config)
            VALUES ('req-1', 'proj-1', 'Test', 'GET', 'https://example.com', NULL, NULL)
        """)
        try sqliteDb.execute("""
            INSERT INTO request_history
            (id, request_id, method, url, status_code, response_time_ms,
             request_headers, request_body, response_headers, response_body, created_at)
            VALUES ('hist-1', 'req-1', 'GET', 'https://example.com', NULL, NULL,
                    NULL, NULL, NULL, NULL, NULL)
        """)

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb, sqliteDatabase: sqliteDb)
        try migration.migrate()

        let reqRows = try mysqlDb.query("SELECT * FROM request_documents WHERE id = 'req-1'")
        #expect(reqRows.count == 1)

        let histRows = try mysqlDb.query("SELECT * FROM request_history WHERE id = 'hist-1'")
        #expect(histRows.count == 1)

        try setupMySQLTables(mysqlDb)
    }

    @Test func rollsBackOnMigrationError() throws {
        let mysqlDb = try MySQLDatabase()
        try setupMySQLTables(mysqlDb)

        let badSqlite = try SQLiteDatabase(inMemory: true)
        try badSqlite.execute("CREATE TABLE projects (id TEXT PRIMARY KEY, name TEXT NOT NULL)")
        try badSqlite.execute("INSERT INTO projects (id, name) VALUES ('proj-1', 'Valid')")

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb, sqliteDatabase: badSqlite)
        #expect(throws: (any Error).self) {
            try migration.migrate()
        }

        let rows = try mysqlDb.query("SELECT * FROM projects")
        #expect(rows.count == 0)

        try setupMySQLTables(mysqlDb)
    }
}
