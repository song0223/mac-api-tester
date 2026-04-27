import Foundation
import SQLite3

final class SQLiteDatabase {
    private let handle: OpaquePointer

    init(inMemory: Bool = false) throws {
        let path = inMemory ? ":memory:" : SQLiteDatabase.defaultPath()
        var db: OpaquePointer?
        let result = sqlite3_open(path, &db)
        guard result == SQLITE_OK, let db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error"
            if let db {
                sqlite3_close(db)
            }
            throw SQLiteError.openFailed(message)
        }

        handle = db
        try execute("PRAGMA foreign_keys = ON;")
    }

    deinit {
        sqlite3_close(handle)
    }

    func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(handle))
            sqlite3_free(errorMessage)
            throw SQLiteError.executionFailed(message)
        }
    }

    func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            if let statement {
                sqlite3_finalize(statement)
            }
            throw SQLiteError.executionFailed(String(cString: sqlite3_errmsg(handle)))
        }
        return statement
    }

    func columnString(_ statement: OpaquePointer, index: Int32) -> String {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return ""
        }

        guard let text = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: text)
    }

    func columnInt64(_ statement: OpaquePointer, index: Int32) -> Int64 {
        sqlite3_column_int64(statement, index)
    }

    func bindText(_ statement: OpaquePointer, index: Int32, value: String) throws {
        let result = value.withCString { sqlite3_bind_text(statement, index, $0, -1, SQLITE_TRANSIENT) }
        guard result == SQLITE_OK else {
            throw SQLiteError.executionFailed(String(cString: sqlite3_errmsg(handle)))
        }
    }

    func step(_ statement: OpaquePointer) -> Int32 {
        sqlite3_step(statement)
    }

    func finalize(_ statement: OpaquePointer) {
        sqlite3_finalize(statement)
    }

    func lastInsertRowID() -> Int64 {
        sqlite3_last_insert_rowid(handle)
    }

    func errorMessage() -> String {
        String(cString: sqlite3_errmsg(handle))
    }

    func query(_ sql: String) throws -> [[String: Any]] {
        let statement = try prepare(sql)
        defer { finalize(statement) }

        var results: [[String: Any]] = []
        let columnCount = sqlite3_column_count(statement)
        var columnNames: [String] = []
        for i in 0..<columnCount {
            if let name = sqlite3_column_name(statement, i) {
                columnNames.append(String(cString: name))
            } else {
                columnNames.append("column_\(i)")
            }
        }

        while step(statement) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<columnCount {
                let columnName = columnNames[Int(i)]
                let type = sqlite3_column_type(statement, i)
                switch type {
                case SQLITE_INTEGER:
                    row[columnName] = sqlite3_column_int64(statement, i)
                case SQLITE_FLOAT:
                    row[columnName] = sqlite3_column_double(statement, i)
                case SQLITE_TEXT:
                    row[columnName] = columnString(statement, index: i)
                case SQLITE_BLOB:
                    if let blob = sqlite3_column_blob(statement, i) {
                        let size = sqlite3_column_bytes(statement, i)
                        row[columnName] = Data(bytes: blob, count: Int(size))
                    }
                case SQLITE_NULL:
                    row[columnName] = NSNull()
                default:
                    row[columnName] = NSNull()
                }
            }
            results.append(row)
        }

        return results
    }

    private static func defaultPath() -> String {
        NSTemporaryDirectory().appending("mac-api-tester.sqlite")
    }
}

enum SQLiteError: Error, Equatable {
    case openFailed(String)
    case executionFailed(String)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
