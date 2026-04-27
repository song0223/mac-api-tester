import Foundation
import CMySQL

final class MySQLDatabase {
    private let host: String
    private let port: UInt32
    private let username: String
    private let password: String
    private let database: String
    private var connection: UnsafeMutablePointer<MYSQL>?

    init(
        host: String = "127.0.0.1",
        port: UInt32 = 3306,
        username: String = "root",
        password: String = "",
        database: String = "mac_api_tester"
    ) throws {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database

        try connect()
        try createDatabaseIfNotExists()
    }

    deinit {
        disconnect()
    }

    private func connect() throws {
        guard let conn = mysql_init(nil) else {
            throw MySQLError.connectionFailed("无法初始化MySQL连接")
        }

        let result = mysql_real_connect(
            conn,
            host,
            username,
            password,
            nil,
            port,
            nil,
            0
        )

        guard result != nil else {
            let errorMessage = String(cString: mysql_error(conn))
            mysql_close(conn)
            throw MySQLError.connectionFailed(errorMessage)
        }

        self.connection = conn
    }

    private func disconnect() {
        if let connection {
            mysql_close(connection)
        }
        connection = nil
    }

    private func createDatabaseIfNotExists() throws {
        try execute("CREATE DATABASE IF NOT EXISTS `\(database)`")
        try execute("USE `\(database)`")
    }

    @discardableResult
    func execute(_ sql: String) throws -> UInt64 {
        guard let connection else {
            throw MySQLError.connectionFailed("数据库连接未建立")
        }

        let result = mysql_query(connection, sql)
        guard result == 0 else {
            let errorMessage = String(cString: mysql_error(connection))
            throw MySQLError.queryFailed(errorMessage)
        }

        return mysql_affected_rows(connection)
    }

    func query(_ sql: String) throws -> [[String: Any]] {
        guard let connection else {
            throw MySQLError.connectionFailed("数据库连接未建立")
        }

        let result = mysql_query(connection, sql)
        guard result == 0 else {
            let errorMessage = String(cString: mysql_error(connection))
            throw MySQLError.queryFailed(errorMessage)
        }

        guard let resultset = mysql_store_result(connection) else {
            let errorMessage = String(cString: mysql_error(connection))
            if !errorMessage.isEmpty {
                throw MySQLError.queryFailed(errorMessage)
            }
            return []
        }
        defer { mysql_free_result(resultset) }

        var rows: [[String: Any]] = []
        let numFields = mysql_num_fields(resultset)
        let fields = mysql_fetch_fields(resultset)

        var columnNames: [String] = []
        for i in 0..<numFields {
            let field = fields![Int(i)]
            columnNames.append(String(cString: field.name))
        }

        while let row = mysql_fetch_row(resultset) {
            let lengths = mysql_fetch_lengths(resultset)
            var dictionary: [String: Any] = [:]

            for i in 0..<numFields {
                let columnName = columnNames[Int(i)]
                if let value = row[Int(i)] {
                    let length = Int(lengths![Int(i)])
                    let data = Data(bytes: value, count: length)
                    if let string = String(data: data, encoding: .utf8) {
                        dictionary[columnName] = string
                    } else {
                        dictionary[columnName] = data
                    }
                } else {
                    dictionary[columnName] = NSNull()
                }
            }

            rows.append(dictionary)
        }

        return rows
    }

    func lastInsertID() -> UInt64 {
        guard let connection else { return 0 }
        return mysql_insert_id(connection)
    }

    func beginTransaction() throws {
        try execute("START TRANSACTION")
    }

    func commit() throws {
        try execute("COMMIT")
    }

    func rollback() throws {
        try execute("ROLLBACK")
    }
}

enum MySQLError: Error, Equatable {
    case connectionFailed(String)
    case queryFailed(String)
    case migrationFailed(String)
}
