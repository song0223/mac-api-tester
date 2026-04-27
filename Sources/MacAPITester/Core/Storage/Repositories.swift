import Foundation
import SQLite3

struct CollectionRecord: Equatable {
    let id: Int64
    let name: String
    let payload: String
}

struct MySQLHistoryRecord: Equatable {
    let id: String
    let message: String
    let createdAt: Date
}

struct HistoryRecord: Equatable {
    let id: Int64
    let message: String
    let createdAt: Date
}

final class CollectionRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) throws {
        self.database = database
        try database.execute("""
        CREATE TABLE IF NOT EXISTS collections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            payload TEXT NOT NULL
        );
        """)
    }

    func insertCollection(name: String, payload: String) throws -> Int64 {
        let statement = try database.prepare("INSERT INTO collections (name, payload) VALUES (?, ?);")
        defer { database.finalize(statement) }

        try database.bindText(statement, index: 1, value: name)
        try database.bindText(statement, index: 2, value: payload)
        guard database.step(statement) == SQLITE_DONE else {
            throw SQLiteError.executionFailed(database.errorMessage())
        }
        return database.lastInsertRowID()
    }

    func fetchCollections() throws -> [CollectionRecord] {
        let statement = try database.prepare("SELECT id, name, payload FROM collections ORDER BY id ASC;")
        defer { database.finalize(statement) }

        var records: [CollectionRecord] = []
        while true {
            let result = database.step(statement)
            if result == SQLITE_ROW {
                records.append(
                    CollectionRecord(
                        id: database.columnInt64(statement, index: 0),
                        name: database.columnString(statement, index: 1),
                        payload: database.columnString(statement, index: 2)
                    )
                )
            } else if result == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.executionFailed(database.errorMessage())
            }
        }
        return records
    }
}

final class HistoryRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) throws {
        self.database = database
        try database.execute("""
        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT ''
        );
        """)
        try? database.execute("ALTER TABLE history ADD COLUMN created_at TEXT NOT NULL DEFAULT '';")
        try backfillLegacyHistoryTimestamps()
    }

    func insertHistory(message: String) throws {
        try insertHistory(message: message, createdAt: Date())
    }

    func insertHistory(message: String, createdAt: Date) throws {
        let statement = try database.prepare("INSERT INTO history (message, created_at) VALUES (?, ?);")
        defer { database.finalize(statement) }

        try database.bindText(statement, index: 1, value: message)
        try database.bindText(statement, index: 2, value: Self.serialize(createdAt))
        guard database.step(statement) == SQLITE_DONE else {
            throw SQLiteError.executionFailed(database.errorMessage())
        }

        try database.execute("""
        DELETE FROM history
        WHERE id NOT IN (
            SELECT id FROM history ORDER BY id DESC LIMIT 300
        );
        """)
    }

    func fetchHistory() throws -> [HistoryRecord] {
        let statement = try database.prepare("""
        SELECT id, message, created_at
        FROM history
        ORDER BY id ASC;
        """)
        defer { database.finalize(statement) }

        var records: [HistoryRecord] = []
        while true {
            let result = database.step(statement)
            if result == SQLITE_ROW {
                let id = database.columnInt64(statement, index: 0)
                let createdAtString = database.columnString(statement, index: 2)
                records.append(
                    HistoryRecord(
                        id: id,
                        message: database.columnString(statement, index: 1),
                        createdAt: Self.deserialize(createdAtString) ?? Self.fallbackDate(for: id)
                    )
                )
            } else if result == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.executionFailed(database.errorMessage())
            }
        }
        return records
    }

    private static func serialize(_ date: Date) -> String {
        String(date.timeIntervalSince1970)
    }

    private static func deserialize(_ value: String) -> Date? {
        guard let timeInterval = TimeInterval(value) else {
            return nil
        }
        return Date(timeIntervalSince1970: timeInterval)
    }

    private static func fallbackDate(for id: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(id))
    }

    private func backfillLegacyHistoryTimestamps() throws {
        let selectStatement = try database.prepare("""
        SELECT id
        FROM history
        WHERE created_at = '' OR created_at IS NULL
        ORDER BY id ASC;
        """)
        defer { database.finalize(selectStatement) }

        var legacyIDs: [Int64] = []
        while true {
            let result = database.step(selectStatement)
            if result == SQLITE_ROW {
                legacyIDs.append(database.columnInt64(selectStatement, index: 0))
            } else if result == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.executionFailed(database.errorMessage())
            }
        }

        guard !legacyIDs.isEmpty else {
            return
        }

        let updateStatement = try database.prepare("UPDATE history SET created_at = ? WHERE id = ?;")
        defer { database.finalize(updateStatement) }

        let baseTime = Date().timeIntervalSince1970
        for (offset, id) in legacyIDs.enumerated() {
            let createdAt = Self.serialize(Date(timeIntervalSince1970: baseTime + (Double(offset) * 0.001)))

            sqlite3_reset(updateStatement)
            sqlite3_clear_bindings(updateStatement)
            try database.bindText(updateStatement, index: 1, value: createdAt)
            try database.bindText(updateStatement, index: 2, value: String(id))

            guard database.step(updateStatement) == SQLITE_DONE else {
                throw SQLiteError.executionFailed(database.errorMessage())
            }
        }
    }
}

struct MySQLCollectionRecord: Equatable {
    let id: String
    let name: String
    let payload: String
}

class MySQLRepository {
    let database: MySQLDatabase

    init(database: MySQLDatabase) throws {
        self.database = database
    }
}

final class MySQLCollectionRepository: MySQLRepository {
    override init(database: MySQLDatabase) throws {
        try super.init(database: database)
        try database.execute("""
        CREATE TABLE IF NOT EXISTS collections (
            id VARCHAR(36) PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            payload TEXT NOT NULL
        )
        """)
    }

    func createCollection(name: String, payload: String) throws -> String {
        let id = UUID().uuidString
        try database.execute(
            "INSERT INTO collections (id, name, payload) VALUES (?, ?, ?)",
            parameters: [.string(id), .string(name), .string(payload)]
        )
        return id
    }

    func fetchCollections() throws -> [MySQLCollectionRecord] {
        let rows = try database.query("SELECT id, name, payload FROM collections ORDER BY name ASC")
        return rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let name = row["name"] as? String,
                  let payload = row["payload"] as? String else {
                return nil
            }
            return MySQLCollectionRecord(id: id, name: name, payload: payload)
        }
    }

    func updateCollection(id: String, name: String, payload: String) throws {
        try database.execute(
            "UPDATE collections SET name = ?, payload = ? WHERE id = ?",
            parameters: [.string(name), .string(payload), .string(id)]
        )
    }

    func deleteCollection(id: String) throws {
        try database.execute(
            "DELETE FROM collections WHERE id = ?",
            parameters: [.string(id)]
        )
    }
}

final class MySQLHistoryRepository: MySQLRepository {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    override init(database: MySQLDatabase) throws {
        try super.init(database: database)
        try database.execute("""
        CREATE TABLE IF NOT EXISTS request_history (
            id VARCHAR(36) PRIMARY KEY,
            request_id VARCHAR(36),
            method VARCHAR(10) NOT NULL DEFAULT '',
            url TEXT,
            status_code INT,
            response_time_ms INT,
            request_headers JSON,
            request_body TEXT,
            response_headers JSON,
            response_body TEXT,
            message TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)
        
        // Add message column if it doesn't exist (for existing tables)
        do {
            try database.execute("ALTER TABLE request_history ADD COLUMN message TEXT NOT NULL")
        } catch {
            // Column already exists, ignore error
        }
    }

    func insertHistory(message: String, createdAt: Date) throws {
        let id = UUID().uuidString
        let timestamp = createdAt.timeIntervalSince1970
        try database.execute(
            "INSERT INTO request_history (id, message, created_at) VALUES (?, ?, FROM_UNIXTIME(?))",
            parameters: [.string(id), .string(message), .double(timestamp)]
        )

        try database.execute("""
        DELETE FROM request_history
        WHERE id NOT IN (
            SELECT id FROM (
                SELECT id FROM request_history ORDER BY created_at DESC LIMIT 300
            ) AS recent
        )
        """)
    }

    func fetchHistory() throws -> [MySQLHistoryRecord] {
        let rows = try database.query("SELECT id, message, created_at FROM request_history ORDER BY created_at ASC")
        return rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let message = row["message"] as? String else {
                return nil
            }

            let createdAt: Date
            if let dateString = row["created_at"] as? String {
                createdAt = Self.dateFormatter.date(from: dateString) ?? Date()
            } else {
                createdAt = Date()
            }

            return MySQLHistoryRecord(id: id, message: message, createdAt: createdAt)
        }
    }
}
