import Foundation
import Testing
@testable import MacAPITester

@Suite("Storage Tests")
struct StorageTests {
    @Test func insertsAndQueriesCollection() throws {
        let database = try SQLiteDatabase(inMemory: true)
        let repository = try CollectionRepository(database: database)

        let firstID = try repository.insertCollection(name: "Core APIs", payload: #"{"count":1}"#)
        let secondID = try repository.insertCollection(name: "Auth APIs", payload: #"{"count":2}"#)

        let collections = try repository.fetchCollections()

        #expect(collections.map(\.id) == [firstID, secondID])
        #expect(collections.map(\.name) == ["Core APIs", "Auth APIs"])
        #expect(collections.map(\.payload) == [#"{"count":1}"#, #"{"count":2}"#])
    }

    @Test func historyKeepsMostRecent300Records() throws {
        let database = try SQLiteDatabase(inMemory: true)
        let repository = try HistoryRepository(database: database)

        for index in 1...301 {
            try repository.insertHistory(
                message: "entry-\(index)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        let history = try repository.fetchHistory()

        #expect(history.count == 300)
        #expect(history.first?.message == "entry-2")
        #expect(history.last?.message == "entry-301")
        #expect(history.first?.createdAt == Date(timeIntervalSince1970: 2))
        #expect(history.last?.createdAt == Date(timeIntervalSince1970: 301))
    }

    @Test func historyPersistsExplicitTimestamps() throws {
        let database = try SQLiteDatabase(inMemory: true)
        let repository = try HistoryRepository(database: database)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_123)

        try repository.insertHistory(message: "entry", createdAt: createdAt)

        let history = try repository.fetchHistory()

        #expect(history.count == 1)
        #expect(history.first?.message == "entry")
        #expect(history.first?.createdAt == createdAt)
    }

    @Test func historyMigrationBackfillsLegacyRowsWithoutDroppingThem() throws {
        let database = try SQLiteDatabase(inMemory: true)
        try database.execute("""
        CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message TEXT NOT NULL
        );
        """)
        try database.execute("INSERT INTO history (message) VALUES ('legacy-1');")
        try database.execute("INSERT INTO history (message) VALUES ('legacy-2');")

        let repository = try HistoryRepository(database: database)
        let history = try repository.fetchHistory()

        #expect(history.map(\.message) == ["legacy-1", "legacy-2"])
        #expect(history[0].createdAt <= history[1].createdAt)
    }

    @Test func columnStringReturnsEmptyStringForNullValues() throws {
        let database = try SQLiteDatabase(inMemory: true)
        try database.execute("CREATE TABLE nullable_values (value TEXT);")
        try database.execute("INSERT INTO nullable_values (value) VALUES (NULL);")

        let statement = try database.prepare("SELECT value FROM nullable_values LIMIT 1;")
        defer { database.finalize(statement) }

        _ = database.step(statement)

        #expect(database.columnString(statement, index: 0).isEmpty)
    }
}
