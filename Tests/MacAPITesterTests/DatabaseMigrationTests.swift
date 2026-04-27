import Foundation
import Testing
@testable import MacAPITester

@Suite("Database Migration Tests", .serialized)
struct DatabaseMigrationTests {
    @Test func createsTablesSuccessfully() throws {
        let mysqlDb = try MySQLDatabase()
        try mysqlDb.execute("DROP TABLE IF EXISTS request_history")
        try mysqlDb.execute("DROP TABLE IF EXISTS request_documents")
        try mysqlDb.execute("DROP TABLE IF EXISTS projects")

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb)
        try migration.migrate()

        let tables = try mysqlDb.query("SHOW TABLES")
        let tableNames = tables.compactMap { $0.values.first as? String }
        #expect(tableNames.contains("projects"))
        #expect(tableNames.contains("request_documents"))
        #expect(tableNames.contains("request_history"))

        try mysqlDb.execute("DROP TABLE IF EXISTS request_history")
        try mysqlDb.execute("DROP TABLE IF EXISTS request_documents")
        try mysqlDb.execute("DROP TABLE IF EXISTS projects")
    }

    @Test func createsTablesWithCorrectSchema() throws {
        let mysqlDb = try MySQLDatabase()
        try mysqlDb.execute("DROP TABLE IF EXISTS request_history")
        try mysqlDb.execute("DROP TABLE IF EXISTS request_documents")
        try mysqlDb.execute("DROP TABLE IF EXISTS projects")

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

        try mysqlDb.execute("DROP TABLE IF EXISTS request_history")
        try mysqlDb.execute("DROP TABLE IF EXISTS request_documents")
        try mysqlDb.execute("DROP TABLE IF EXISTS projects")
    }

    @Test func migrationIsIdempotent() throws {
        let mysqlDb = try MySQLDatabase()
        try mysqlDb.execute("DROP TABLE IF EXISTS request_history")
        try mysqlDb.execute("DROP TABLE IF EXISTS request_documents")
        try mysqlDb.execute("DROP TABLE IF EXISTS projects")

        let migration = DatabaseMigration(mysqlDatabase: mysqlDb)
        try migration.migrate()
        try migration.migrate()

        let tables = try mysqlDb.query("SHOW TABLES")
        let tableNames = tables.compactMap { $0.values.first as? String }
        #expect(tableNames.contains("projects"))
        #expect(tableNames.contains("request_documents"))
        #expect(tableNames.contains("request_history"))

        try mysqlDb.execute("DROP TABLE IF EXISTS request_history")
        try mysqlDb.execute("DROP TABLE IF EXISTS request_documents")
        try mysqlDb.execute("DROP TABLE IF EXISTS projects")
    }
}
