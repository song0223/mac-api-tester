import Testing
@testable import MacAPITester

@Suite("MySQL Database Tests", .serialized)
struct MySQLDatabaseTests {
    @Test func connectsToMySQLServer() throws {
        let _ = try MySQLDatabase()
    }

    @Test func createsDatabaseIfNotExists() throws {
        let db = try MySQLDatabase()
        try db.execute("CREATE TABLE IF NOT EXISTS test_table (id INT PRIMARY KEY)")
        try db.execute("DROP TABLE test_table")
    }
}
