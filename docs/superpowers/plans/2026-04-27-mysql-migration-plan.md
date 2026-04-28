# MySQL数据库迁移实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有SQLite数据库转换为MySQL数据库（127.0.0.1，root，无密码），保持轻量级封装

**Architecture:** 使用MySQL C客户端库（libmysqlclient）实现与SQLiteDatabase相同的接口，支持连接池和事务管理

**Tech Stack:** Swift, MySQL C API, libmysqlclient

---

## 文件结构

### 新增文件
- `Sources/MacAPITester/Core/Database/MySQLDatabase.swift` - MySQL连接和操作
- `Sources/MacAPITester/Core/Database/MySQLRepository.swift` - MySQL数据仓库
- `Sources/MacAPITester/Core/Database/DatabaseMigration.swift` - 数据库迁移工具
- `Tests/MacAPITesterTests/MySQLDatabaseTests.swift` - MySQL数据库测试

### 修改文件
- `Package.swift` - 添加MySQL客户端库依赖
- `Sources/MacAPITester/App/AppContainer.swift` - 更新数据库初始化
- `Sources/MacAPITester/Core/Storage/Repositories.swift` - 更新仓库实现

---

## 任务分解

### Task 1: 添加MySQL客户端库依赖

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: 更新Package.swift添加MySQL依赖**

```swift
// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacAPITester",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "MacAPITester",
            targets: ["MacAPITester"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "MacAPITester",
            path: "Sources/MacAPITester",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedLibrary("mysqlclient"),
            ]
        ),
        .testTarget(
            name: "MacAPITesterTests",
            dependencies: ["MacAPITester"],
            path: "Tests/MacAPITesterTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 2: 验证依赖添加成功**

Run: `swift package resolve`
Expected: 成功解析MySQL客户端库依赖

- [ ] **Step 3: 提交更改**

```bash
git add Package.swift
git commit -m "build: 添加MySQL客户端库依赖"
```

### Task 2: 创建MySQLDatabase类

**Files:**
- Create: `Sources/MacAPITester/Core/Database/MySQLDatabase.swift`

- [ ] **Step 1: 创建MySQLDatabase类**

```swift
import Foundation
import MySQL

final class MySQLDatabase {
    private let host: String
    private let port: UInt32
    private let username: String
    private let password: String
    private let database: String
    private var connection: MySQL.Connection?
    
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
        let conn = try MySQL.Connection(
            host: host,
            port: port,
            user: username,
            password: password,
            database: database
        )
        self.connection = conn
    }
    
    private func disconnect() {
        connection?.close()
        connection = nil
    }
    
    private func createDatabaseIfNotExists() throws {
        try execute("CREATE DATABASE IF NOT EXISTS \(database)")
        try execute("USE \(database)")
    }
    
    func execute(_ sql: String) throws {
        guard let connection else {
            throw MySQLError.connectionFailed("数据库连接未建立")
        }
        
        try connection.execute(sql)
    }
    
    func query(_ sql: String) throws -> [[String: Any]] {
        guard let connection else {
            throw MySQLError.connectionFailed("数据库连接未建立")
        }
        
        let results = try connection.query(sql)
        return results
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
```

- [ ] **Step 2: 编写MySQLDatabase测试**

```swift
import Testing
@testable import MacAPITester

@Suite("MySQL Database Tests")
struct MySQLDatabaseTests {
    @Test func connectsToMySQLServer() throws {
        let db = try MySQLDatabase()
        #expect(db != nil)
    }
    
    @Test func createsDatabaseIfNotExists() throws {
        let db = try MySQLDatabase()
        try db.execute("CREATE TABLE IF NOT EXISTS test_table (id INT PRIMARY KEY)")
        try db.execute("DROP TABLE test_table")
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test --filter MySQLDatabaseTests`
Expected: 测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/Database/MySQLDatabase.swift
git add Tests/MacAPITesterTests/MySQLDatabaseTests.swift
git commit -m "feat: 添加MySQLDatabase类"
```

### Task 3: 创建数据库迁移工具

**Files:**
- Create: `Sources/MacAPITester/Core/Database/DatabaseMigration.swift`

- [ ] **Step 1: 创建DatabaseMigration类**

```swift
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
        // 创建项目表
        try mysqlDatabase.execute("""
            CREATE TABLE IF NOT EXISTS projects (
                id VARCHAR(36) PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        """)
        
        // 创建请求文档表
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
        
        // 创建请求历史表
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
        // 迁移项目数据
        let projects = try sqliteDatabase.query("SELECT * FROM projects")
        for project in projects {
            try mysqlDatabase.execute("""
                INSERT INTO projects (id, name) VALUES ('\(project["id"] as? String ?? "")', '\(project["name"] as? String ?? "")')
            """)
        }
        
        // 迁移请求文档数据
        let requests = try sqliteDatabase.query("SELECT * FROM request_documents")
        for request in requests {
            try mysqlDatabase.execute("""
                INSERT INTO request_documents (id, project_id, name, method, url_string, query_text, headers_text, body_text, variables_text) 
                VALUES ('\(request["id"] as? String ?? "")', '\(request["project_id"] as? String ?? "")', '\(request["name"] as? String ?? "")', '\(request["method"] as? String ?? "GET")', '\(request["url_string"] as? String ?? "")', '\(request["query_text"] as? String ?? "")', '\(request["headers_text"] as? String ?? "")', '\(request["body_text"] as? String ?? "")', '\(request["variables_text"] as? String ?? "")')
            """)
        }
        
        // 迁移历史记录数据
        let history = try sqliteDatabase.query("SELECT * FROM request_history")
        for record in history {
            try mysqlDatabase.execute("""
                INSERT INTO request_history (id, request_id, method, url, status_code, response_time_ms, created_at) 
                VALUES ('\(record["id"] as? String ?? "")', '\(record["request_id"] as? String ?? "")', '\(record["method"] as? String ?? "")', '\(record["url"] as? String ?? "")', \(record["status_code"] as? Int ?? 0), \(record["response_time_ms"] as? Int ?? 0), '\(record["created_at"] as? String ?? "")')
            """)
        }
    }
}
```

- [ ] **Step 2: 编写迁移测试**

```swift
import Testing
@testable import MacAPITester

@Suite("Database Migration Tests")
struct DatabaseMigrationTests {
    @Test func createsTablesSuccessfully() throws {
        let mysqlDb = try MySQLDatabase()
        let migration = DatabaseMigration(mysqlDatabase: mysqlDb)
        try migration.migrate()
        
        // 验证表已创建
        let tables = try mysqlDb.query("SHOW TABLES")
        #expect(tables.count >= 3)
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test --filter DatabaseMigrationTests`
Expected: 测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/Database/DatabaseMigration.swift
git add Tests/MacAPITesterTests/DatabaseMigrationTests.swift
git commit -m "feat: 添加数据库迁移工具"
```

### Task 4: 更新AppContainer使用MySQL

**Files:**
- Modify: `Sources/MacAPITester/App/AppContainer.swift`

- [ ] **Step 1: 更新AppContainer初始化**

```swift
import AppKit
import Foundation
import SwiftUI

struct AppContainer: View {
    @State private var projects: [RequestProject]
    @State private var selectedProjectID: RequestProject.ID?
    @State private var requests: [RequestDocument]
    @State private var openedRequestIDs: [RequestDocument.ID]
    @State private var selectedRequestID: RequestDocument.ID?
    @State private var latestResponse: RequestResponseSnapshot?
    @State private var historyItems: [RequestHistoryItem] = []
    @State private var errorMessage: String?
    @State private var isSending = false
    @State private var hasLoadedHistory = false
    @State private var statusMessage: String?
    private let workspaceBackground = Color(red: 249 / 255, green: 249 / 255, blue: 249 / 255)

    private let templateRenderer = TemplateRenderer()
    private let httpClient = HTTPClient()
    private let historyPersistence: HistoryPersistence

    init() {
        let initialProject = RequestProject(name: "默认项目")
        let initialRequest = RequestDocument.starter(projectID: initialProject.id)
        _projects = State(initialValue: [initialProject])
        _selectedProjectID = State(initialValue: initialProject.id)
        _requests = State(initialValue: [initialRequest])
        _openedRequestIDs = State(initialValue: [initialRequest.id])
        _selectedRequestID = State(initialValue: initialRequest.id)
        
        // 初始化MySQL数据库
        do {
            let mysqlDatabase = try MySQLDatabase()
            let migration = DatabaseMigration(mysqlDatabase: mysqlDatabase)
            try migration.migrate()
            self.historyPersistence = HistoryPersistence(database: mysqlDatabase)
        } catch {
            print("MySQL初始化失败，使用内存存储: \(error)")
            self.historyPersistence = HistoryPersistence.inMemory
        }
    }
    
    // ... 其余代码保持不变
}
```

- [ ] **Step 2: 更新HistoryPersistence类**

```swift
@MainActor
private final class HistoryPersistence {
    static let shared = HistoryPersistence.inMemory
    
    private let database: MySQLDatabase?
    private let repository: HistoryRepository?
    
    init(database: MySQLDatabase) {
        self.database = database
        self.repository = try? HistoryRepository(database: database)
    }
    
    static var inMemory: HistoryPersistence {
        HistoryPersistence(database: nil)
    }
    
    private init(database: MySQLDatabase?) {
        self.database = database
        self.repository = database.flatMap { try? HistoryRepository(database: $0) }
    }
    
    func save(message: String, createdAt: Date) {
        guard let repository else {
            return
        }
        
        try? repository.insertHistory(message: message, createdAt: createdAt)
    }
    
    func loadItems() -> [RequestHistoryItem] {
        guard let repository,
              let records = try? repository.fetchHistory() else {
            return []
        }
        
        return records
            .reversed()
            .map { record in
                RequestHistoryItem(
                    timestamp: record.createdAt,
                    message: record.message
                )
            }
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test`
Expected: 所有测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/App/AppContainer.swift
git commit -m "feat: 更新AppContainer使用MySQL数据库"
```

### Task 5: 更新Repositories支持MySQL

**Files:**
- Modify: `Sources/MacAPITester/Core/Storage/Repositories.swift`

- [ ] **Step 1: 创建MySQLRepository基类**

```swift
import Foundation

class MySQLRepository {
    let database: MySQLDatabase
    
    init(database: MySQLDatabase) throws {
        self.database = database
    }
}
```

- [ ] **Step 2: 更新CollectionRepository支持MySQL**

```swift
class MySQLCollectionRepository: MySQLRepository {
    func createCollection(name: String, payload: String) throws -> String {
        let id = UUID().uuidString
        try database.execute("""
            INSERT INTO collections (id, name, payload) VALUES ('\(id)', '\(name)', '\(payload)')
        """)
        return id
    }
    
    func fetchCollections() throws -> [(id: String, name: String, payload: String)] {
        let results = try database.query("SELECT id, name, payload FROM collections")
        return results.map { row in
            (
                id: row["id"] as? String ?? "",
                name: row["name"] as? String ?? "",
                payload: row["payload"] as? String ?? ""
            )
        }
    }
    
    func updateCollection(id: String, name: String, payload: String) throws {
        try database.execute("""
            UPDATE collections SET name = '\(name)', payload = '\(payload)' WHERE id = '\(id)'
        """)
    }
    
    func deleteCollection(id: String) throws {
        try database.execute("DELETE FROM collections WHERE id = '\(id)'")
    }
}
```

- [ ] **Step 3: 更新HistoryRepository支持MySQL**

```swift
class MySQLHistoryRepository: MySQLRepository {
    func insertHistory(message: String, createdAt: Date) throws {
        let id = UUID().uuidString
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: createdAt)
        
        try database.execute("""
            INSERT INTO request_history (id, message, created_at) VALUES ('\(id)', '\(message)', '\(dateString)')
        """)
    }
    
    func fetchHistory() throws -> [(message: String, createdAt: Date)] {
        let results = try database.query("SELECT message, created_at FROM request_history ORDER BY created_at DESC LIMIT 300")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return results.map { row in
            (
                message: row["message"] as? String ?? "",
                createdAt: dateFormatter.date(from: row["created_at"] as? String ?? "") ?? Date()
            )
        }
    }
}
```

- [ ] **Step 4: 运行测试验证**

Run: `swift test`
Expected: 所有测试通过

- [ ] **Step 5: 提交更改**

```bash
git add Sources/MacAPITester/Core/Storage/Repositories.swift
git commit -m "feat: 更新Repositories支持MySQL数据库"
```

---

## 验证清单

- [ ] MySQL数据库连接成功
- [ ] 数据库表创建成功
- [ ] 数据迁移成功（如果从SQLite迁移）
- [ ] 所有现有功能正常工作
- [ ] 所有测试通过
- [ ] 性能测试通过

---

## 回滚计划

如果MySQL迁移失败，可以回滚到SQLite：

1. 恢复`Package.swift`中的SQLite依赖
2. 恢复`AppContainer.swift`中的SQLite初始化
3. 恢复`Repositories.swift`中的SQLite实现
4. 重新构建和测试
