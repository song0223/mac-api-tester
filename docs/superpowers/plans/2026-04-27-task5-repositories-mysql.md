# Task 5: 更新Repositories支持MySQL 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建MySQLRepository基类，添加MySQLCollectionRepository，并使MySQLHistoryRepository继承自基类。

**Architecture:** 在Repositories.swift中添加MySQLRepository基类和MySQLCollectionRepository，同时修改现有MySQLHistoryRepository继承自新基类。需要更新DatabaseMigration以创建collections表。

**Tech Stack:** Swift 6, MySQL (CMySQL), Swift Testing

---

## File Structure

- Modify: `Sources/MacAPITester/Core/Storage/Repositories.swift` - 添加MySQLRepository基类和MySQLCollectionRepository
- Modify: `Sources/MacAPITester/Core/Database/DatabaseMigration.swift` - 添加collections表迁移
- Test: `Tests/MacAPITesterTests/MySQLDatabaseTests.swift` - 添加MySQL仓库测试

---

## Current State Analysis

1. `Repositories.swift` 已包含:
   - `CollectionRecord` (SQLite)
   - `MySQLHistoryRecord`
   - `HistoryRecord` (SQLite)
   - `CollectionRepository` (SQLite)
   - `HistoryRepository` (SQLite)
   - `MySQLHistoryRepository` (MySQL, 无基类)

2. `MySQLDatabase` 支持参数化查询，现有 `MySQLHistoryRepository` 使用参数化查询

3. `DatabaseMigration` 创建了 `request_history` 表，但没有 `collections` 表

---

### Task 1: 添加collections表到数据库迁移

**Files:**
- Modify: `Sources/MacAPITester/Core/Database/DatabaseMigration.swift:19-66`

- [ ] **Step 1: 在createTables()中添加collections表**

在 `createTables()` 方法的 `request_history` 表创建之前添加:

```swift
try mysqlDatabase.execute("""
    CREATE TABLE IF NOT EXISTS collections (
        id VARCHAR(36) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        payload TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
""")
```

- [ ] **Step 2: 运行测试验证迁移**

Run: `swift test --filter MySQLDatabaseTests`
Expected: 所有测试通过

- [ ] **Step 3: 提交更改**

```bash
git add Sources/MacAPITester/Core/Database/DatabaseMigration.swift
git commit -m "feat: 添加collections表到MySQL迁移"
```

---

### Task 2: 创建MySQLRepository基类和MySQLCollectionRepository

**Files:**
- Modify: `Sources/MacAPITester/Core/Storage/Repositories.swift`

- [ ] **Step 1: 添加MySQLCollectionRecord结构体**

在 `MySQLHistoryRecord` 结构体之后添加:

```swift
struct MySQLCollectionRecord: Equatable {
    let id: String
    let name: String
    let payload: String
}
```

- [ ] **Step 2: 添加MySQLRepository基类**

在 `MySQLCollectionRecord` 之后添加:

```swift
class MySQLRepository {
    let database: MySQLDatabase

    init(database: MySQLDatabase) throws {
        self.database = database
    }
}
```

- [ ] **Step 3: 添加MySQLCollectionRepository类**

在 `MySQLRepository` 基类之后添加:

```swift
final class MySQLCollectionRepository: MySQLRepository {
    override init(database: MySQLDatabase) throws {
        try super.init(database: database)
        try database.execute("""
        CREATE TABLE IF NOT EXISTS collections (
            id VARCHAR(36) PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            payload TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
        """)
    }

    func insertCollection(name: String, payload: String) throws -> String {
        let id = UUID().uuidString
        try database.execute(
            "INSERT INTO collections (id, name, payload) VALUES (?, ?, ?)",
            parameters: [.string(id), .string(name), .string(payload)]
        )
        return id
    }

    func fetchCollections() throws -> [MySQLCollectionRecord] {
        let rows = try database.query("SELECT id, name, payload FROM collections ORDER BY created_at ASC")
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
```

- [ ] **Step 4: 运行测试验证编译**

Run: `swift build`
Expected: 编译成功

- [ ] **Step 5: 提交更改**

```bash
git add Sources/MacAPITester/Core/Storage/Repositories.swift
git commit -m "feat: 添加MySQLRepository基类和MySQLCollectionRepository"
```

---

### Task 3: 修改MySQLHistoryRepository继承自MySQLRepository

**Files:**
- Modify: `Sources/MacAPITester/Core/Storage/Repositories.swift:200-272`

- [ ] **Step 1: 修改MySQLHistoryRepository类声明**

将:
```swift
final class MySQLHistoryRepository {
    private let database: MySQLDatabase
```

改为:
```swift
final class MySQLHistoryRepository: MySQLRepository {
```

- [ ] **Step 2: 修改init方法**

将:
```swift
init(database: MySQLDatabase) throws {
    self.database = database
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
```

改为:
```swift
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
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test`
Expected: 所有测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/Storage/Repositories.swift
git commit -m "refactor: MySQLHistoryRepository继承自MySQLRepository基类"
```

---

### Task 4: 添加MySQLCollectionRepository测试

**Files:**
- Modify: `Tests/MacAPITesterTests/MySQLDatabaseTests.swift`

- [ ] **Step 1: 添加MySQLCollectionRepository测试**

在文件末尾的 `}` 之前添加:

```swift
@Test func mysqlCollectionRepositoryInsertAndFetch() throws {
    let db = try MySQLDatabase()
    let repo = try MySQLCollectionRepository(database: db)
    
    let id = try repo.insertCollection(name: "Test Collection", payload: #"{"key":"value"}"#)
    #expect(!id.isEmpty)
    
    let collections = try repo.fetchCollections()
    #expect(collections.count >= 1)
    #expect(collections.last?.name == "Test Collection")
    #expect(collections.last?.payload == #"{"key":"value"}"#)
    
    try db.execute("DELETE FROM collections WHERE id = ?", parameters: [.string(id)])
}

@Test func mysqlCollectionRepositoryUpdate() throws {
    let db = try MySQLDatabase()
    let repo = try MySQLCollectionRepository(database: db)
    
    let id = try repo.insertCollection(name: "Original", payload: "{}")
    try repo.updateCollection(id: id, name: "Updated", payload: #"{"updated":true}"#)
    
    let collections = try repo.fetchCollections()
    let updated = collections.first { $0.id == id }
    #expect(updated?.name == "Updated")
    #expect(updated?.payload == #"{"updated":true}"#)
    
    try db.execute("DELETE FROM collections WHERE id = ?", parameters: [.string(id)])
}

@Test func mysqlCollectionRepositoryDelete() throws {
    let db = try MySQLDatabase()
    let repo = try MySQLCollectionRepository(database: db)
    
    let id = try repo.insertCollection(name: "To Delete", payload: "{}")
    try repo.deleteCollection(id: id)
    
    let collections = try repo.fetchCollections()
    #expect(collections.first { $0.id == id } == nil)
}
```

- [ ] **Step 2: 运行测试**

Run: `swift test --filter MySQLDatabaseTests`
Expected: 所有测试通过

- [ ] **Step 3: 提交更改**

```bash
git add Tests/MacAPITesterTests/MySQLDatabaseTests.swift
git commit -m "test: 添加MySQLCollectionRepository测试"
```

---

### Task 5: 最终验证和清理

- [ ] **Step 1: 运行所有测试**

Run: `swift test`
Expected: 所有测试通过

- [ ] **Step 2: 检查代码风格**

确认:
- 使用参数化查询而非字符串插值
- 遵循现有命名约定
- 没有引入不必要的注释

- [ ] **Step 3: 最终提交（如有需要）**

```bash
git status
```

如果有未提交的更改，提交它们。

---

## Self-Review Checklist

- [ ] MySQLRepository基类已创建
- [ ] MySQLCollectionRepository已创建，支持CRUD操作
- [ ] MySQLHistoryRepository已修改继承自MySQLRepository
- [ ] collections表已添加到数据库迁移
- [ ] 所有新代码使用参数化查询（安全）
- [ ] 测试覆盖所有新功能
- [ ] 所有现有测试仍然通过
