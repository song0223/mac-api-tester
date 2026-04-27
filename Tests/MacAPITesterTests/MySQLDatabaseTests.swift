import Foundation
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

    @Test func executeReturnsAffectedRows() throws {
        let db = try MySQLDatabase()
        try db.execute("DROP TABLE IF EXISTS test_affected_rows")
        try db.execute("CREATE TABLE test_affected_rows (id INT PRIMARY KEY, name VARCHAR(50))")

        let inserted = try db.execute("INSERT INTO test_affected_rows VALUES (1, 'test')")
        #expect(inserted == 1)

        let updated = try db.execute("UPDATE test_affected_rows SET name = 'updated' WHERE id = 1")
        #expect(updated == 1)

        let deleted = try db.execute("DELETE FROM test_affected_rows WHERE id = 1")
        #expect(deleted == 1)

        try db.execute("DROP TABLE test_affected_rows")
    }

    @Test func queryReturnsResults() throws {
        let db = try MySQLDatabase()
        try db.execute("DROP TABLE IF EXISTS test_query")
        try db.execute("CREATE TABLE test_query (id INT PRIMARY KEY, name VARCHAR(50))")
        try db.execute("INSERT INTO test_query VALUES (1, 'Alice')")
        try db.execute("INSERT INTO test_query VALUES (2, 'Bob')")

        let results = try db.query("SELECT * FROM test_query ORDER BY id")
        #expect(results.count == 2)
        #expect(results[0]["name"] as? String == "Alice")
        #expect(results[1]["name"] as? String == "Bob")

        try db.execute("DROP TABLE test_query")
    }

    @Test func queryReturnsEmptyForNoResults() throws {
        let db = try MySQLDatabase()
        try db.execute("DROP TABLE IF EXISTS test_empty")
        try db.execute("CREATE TABLE test_empty (id INT PRIMARY KEY)")

        let results = try db.query("SELECT * FROM test_empty")
        #expect(results.isEmpty)

        try db.execute("DROP TABLE test_empty")
    }

    @Test func queryHandlesNullValues() throws {
        let db = try MySQLDatabase()
        try db.execute("DROP TABLE IF EXISTS test_null")
        try db.execute("CREATE TABLE test_null (id INT PRIMARY KEY, value VARCHAR(50))")
        try db.execute("INSERT INTO test_null VALUES (1, NULL)")

        let results = try db.query("SELECT * FROM test_null")
        #expect(results.count == 1)
        #expect(results[0]["value"] is NSNull)

        try db.execute("DROP TABLE test_null")
    }

    @Test func lastInsertIDReturnsCorrectValue() throws {
        let db = try MySQLDatabase()
        try db.execute("DROP TABLE IF EXISTS test_auto_increment")
        try db.execute("CREATE TABLE test_auto_increment (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50))")

        try db.execute("INSERT INTO test_auto_increment (name) VALUES ('first')")
        let firstID = db.lastInsertID()
        #expect(firstID == 1)

        try db.execute("INSERT INTO test_auto_increment (name) VALUES ('second')")
        let secondID = db.lastInsertID()
        #expect(secondID == 2)

        try db.execute("DROP TABLE test_auto_increment")
    }

    @Test func transactionCommitPersistsChanges() throws {
        let db = try MySQLDatabase()
        try db.execute("DROP TABLE IF EXISTS test_transaction")
        try db.execute("CREATE TABLE test_transaction (id INT PRIMARY KEY, name VARCHAR(50))")

        try db.beginTransaction()
        try db.execute("INSERT INTO test_transaction VALUES (1, 'committed')")
        try db.commit()

        let results = try db.query("SELECT * FROM test_transaction WHERE id = 1")
        #expect(results.count == 1)
        #expect(results[0]["name"] as? String == "committed")

        try db.execute("DROP TABLE test_transaction")
    }

    @Test func transactionRollbackDiscardsChanges() throws {
        let db = try MySQLDatabase()
        try db.execute("DROP TABLE IF EXISTS test_rollback")
        try db.execute("CREATE TABLE test_rollback (id INT PRIMARY KEY, name VARCHAR(50))")

        try db.beginTransaction()
        try db.execute("INSERT INTO test_rollback VALUES (1, 'rolled_back')")
        try db.rollback()

        let results = try db.query("SELECT * FROM test_rollback WHERE id = 1")
        #expect(results.isEmpty)

        try db.execute("DROP TABLE test_rollback")
    }

    @Test func queryThrowsOnInvalidSQL() throws {
        let db = try MySQLDatabase()
        #expect(throws: MySQLError.self) {
            try db.query("INVALID SQL STATEMENT")
        }
    }

    @Test func executeThrowsOnInvalidSQL() throws {
        let db = try MySQLDatabase()
        #expect(throws: MySQLError.self) {
            try db.execute("INVALID SQL STATEMENT")
        }
    }

    @Test func threadSafetyConcurrentAccess() throws {
        let db = try MySQLDatabase()
        try db.execute("DROP TABLE IF EXISTS test_concurrent")
        try db.execute("CREATE TABLE test_concurrent (id INT PRIMARY KEY, value INT)")

        let iterations = 100
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for i in 0..<iterations {
            group.enter()
            queue.async {
                do {
                    try db.execute("INSERT INTO test_concurrent VALUES (\(i), \(i * 10))")
                } catch {
                    Issue.record("Failed to insert: \(error)")
                }
                group.leave()
            }
        }

        group.wait()

        let results = try db.query("SELECT COUNT(*) as cnt FROM test_concurrent")
        let count = results[0]["cnt"] as? String
        #expect(count == "\(iterations)")

        try db.execute("DROP TABLE test_concurrent")
    }

    @Test func parameterizedExecutePreventsInjection() throws {
        let db = try MySQLDatabase()
        try db.execute("DROP TABLE IF EXISTS test_parameterized")
        try db.execute("CREATE TABLE test_parameterized (id INT PRIMARY KEY, name VARCHAR(50))")

        let maliciousInput = "test'); DROP TABLE test_parameterized; --"
        try db.execute(
            "INSERT INTO test_parameterized VALUES (?, ?)",
            parameters: [.int(1), .string(maliciousInput)]
        )

        let results = try db.query("SELECT name FROM test_parameterized WHERE id = 1")
        #expect(results.count == 1)
        #expect(results[0]["name"] as? String == maliciousInput)

        try db.execute("DROP TABLE test_parameterized")
    }
}
