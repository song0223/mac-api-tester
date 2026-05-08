import Foundation
import CMySQL

/// 线程安全的MySQL数据库封装类，提供连接管理、查询执行和事务支持。
///
/// 使用NSLock保护所有对底层MYSQL连接的访问，确保多线程环境下的安全性。
final class MySQLDatabase: @unchecked Sendable {
    private let host: String
    private let port: UInt32
    private let username: String
    private let password: String
    private let database: String
    private var connection: UnsafeMutablePointer<MYSQL>?
    private let lock = NSLock()

    /// 初始化MySQL数据库连接
    /// - Parameters:
    ///   - host: MySQL服务器地址，默认为"47.100.236.45"
    ///   - port: MySQL服务器端口，默认为3306
    ///   - username: 数据库用户名，默认为"root"
    ///   - password: 数据库密码，默认为"Netime@2023"
    ///   - database: 数据库名称，默认为"mac_api_tester"
    /// - Throws: `MySQLError.connectionFailed` 如果连接失败
    init(
        host: String = "47.100.236.45",
        port: UInt32 = 3306,
        username: String = "root",
        password: String = "Netime@2023",
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

        var timeout: UInt32 = 10
        mysql_options(conn, MYSQL_OPT_CONNECT_TIMEOUT, &timeout)

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
        mysql_set_character_set(conn, "utf8mb4")
    }

    private func disconnect() {
        lock.lock()
        if let connection {
            mysql_close(connection)
        }
        connection = nil
        lock.unlock()
    }

    private func createDatabaseIfNotExists() throws {
        try execute("CREATE DATABASE IF NOT EXISTS `\(database)`")
        try execute("USE `\(database)`")
    }

    /// 执行SQL语句（INSERT、UPDATE、DELETE等）
    /// - Parameter sql: 要执行的SQL语句
    /// - Returns: 受影响的行数
    /// - Throws: `MySQLError.connectionFailed` 如果连接未建立
    /// - Throws: `MySQLError.queryFailed` 如果执行失败
    @discardableResult
    func execute(_ sql: String) throws -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

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

    /// 执行参数化SQL语句，使用转义防止SQL注入
    /// - Parameters:
    ///   - sql: 带占位符(?)的SQL语句
    ///   - parameters: 参数值数组
    /// - Returns: 受影响的行数
    /// - Throws: `MySQLError.queryFailed` 如果执行失败
    @discardableResult
    func execute(_ sql: String, parameters: [MySQLValue]) throws -> UInt64 {
        let expanded = try expandParameters(sql, parameters: parameters)
        return try execute(expanded)
    }

    /// 执行参数化查询SQL语句，使用转义防止SQL注入
    /// - Parameters:
    ///   - sql: 带占位符(?)的查询SQL语句
    ///   - parameters: 参数值数组
    /// - Returns: 结果数组，每个元素为字典（列名: 值）
    /// - Throws: `MySQLError.queryFailed` 如果查询失败
    func query(_ sql: String, parameters: [MySQLValue]) throws -> [[String: Any]] {
        let expanded = try expandParameters(sql, parameters: parameters)
        return try query(expanded)
    }

    private func expandParameters(_ sql: String, parameters: [MySQLValue]) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        guard let connection else {
            throw MySQLError.connectionFailed("数据库连接未建立")
        }

        var result = ""
        var paramIndex = 0
        var i = sql.startIndex

        while i < sql.endIndex {
            if sql[i] == "?" {
                guard paramIndex < parameters.count else {
                    throw MySQLError.queryFailed("参数数量不匹配：SQL中有更多占位符")
                }
                let value = parameters[paramIndex]
                switch value {
                case .string(let str):
                    let escaped = str.withCString { ptr in
                        let byteLength = str.utf8.count
                        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: byteLength * 2 + 1)
                        mysql_real_escape_string(connection, buffer, ptr, UInt(byteLength))
                        let escapedStr = String(cString: buffer)
                        buffer.deallocate()
                        return escapedStr
                    }
                    result += "'\(escaped)'"
                case .int(let value):
                    result += "\(value)"
                case .int32(let value):
                    result += "\(value)"
                case .double(let value):
                    result += "\(value)"
                case .data(let data):
                    result += "X'\(data.map { String(format: "%02x", $0) }.joined())'"
                case .null:
                    result += "NULL"
                }
                paramIndex += 1
                i = sql.index(after: i)
            } else {
                result.append(sql[i])
                i = sql.index(after: i)
            }
        }

        guard paramIndex == parameters.count else {
            throw MySQLError.queryFailed("参数数量不匹配：期望\(paramIndex)个，实际\(parameters.count)个")
        }

        return result
    }

    /// 执行查询SQL语句，返回结果集
    /// - Parameter sql: 要执行的查询SQL语句
    /// - Returns: 结果数组，每个元素为字典（列名: 值）
    /// - Throws: `MySQLError.connectionFailed` 如果连接未建立
    /// - Throws: `MySQLError.queryFailed` 如果查询失败
    func query(_ sql: String) throws -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }

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

        guard let fields = mysql_fetch_fields(resultset) else {
            throw MySQLError.queryFailed("无法获取字段信息")
        }

        var columnNames: [String] = []
        for i in 0..<numFields {
            let field = fields[Int(i)]
            columnNames.append(String(cString: field.name))
        }

        while let row = mysql_fetch_row(resultset) {
            guard let lengths = mysql_fetch_lengths(resultset) else {
                throw MySQLError.queryFailed("无法获取行数据长度")
            }
            var dictionary: [String: Any] = [:]

            for i in 0..<numFields {
                let columnName = columnNames[Int(i)]
                if let value = row[Int(i)] {
                    let length = Int(lengths[Int(i)])
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

    /// 获取最后插入的自增ID
    /// - Returns: 最后插入的自增ID，如果连接未建立则返回0
    func lastInsertID() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        guard let connection else { return 0 }
        return mysql_insert_id(connection)
    }

    /// 开始事务
    /// - Throws: `MySQLError.queryFailed` 如果执行失败
    func beginTransaction() throws {
        try execute("START TRANSACTION")
    }

    /// 提交事务
    /// - Throws: `MySQLError.queryFailed` 如果执行失败
    func commit() throws {
        try execute("COMMIT")
    }

    /// 回滚事务
    /// - Throws: `MySQLError.queryFailed` 如果执行失败
    func rollback() throws {
        try execute("ROLLBACK")
    }
}

/// MySQL参数值类型，用于参数化查询
enum MySQLValue {
    case string(String)
    case int(Int)
    case int32(Int32)
    case double(Double)
    case data(Data)
    case null

    /// 将值转换为SQL字符串表示
    var rawString: String {
        switch self {
        case .string(let value):
            return "'\(value.replacingOccurrences(of: "'", with: "\\'"))'"
        case .int(let value):
            return "\(value)"
        case .int32(let value):
            return "\(value)"
        case .double(let value):
            return "\(value)"
        case .data(let value):
            return "X'\(value.map { String(format: "%02x", $0) }.joined())'"
        case .null:
            return "NULL"
        }
    }
}

/// MySQL数据库错误类型
enum MySQLError: Error, Equatable {
    case connectionFailed(String)
    case queryFailed(String)
    case migrationFailed(String)
}
