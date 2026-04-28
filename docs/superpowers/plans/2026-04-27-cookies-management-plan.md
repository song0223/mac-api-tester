# Cookies管理功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现高级Cookies管理功能，支持自动提取、存储、导入导出和与浏览器同步

**Architecture:** 创建独立的Cookies模块，包含CookieManager和CookieStorage，支持混合存储（数据库+文件）

**Tech Swift, Foundation, SwiftUI

---

## 文件结构

### 新增文件
- `Sources/MacAPITester/Core/Cookies/CookieManager.swift` - Cookies管理器
- `Sources/MacAPITester/Core/Cookies/CookieStorage.swift` - Cookies存储
- `Sources/MacAPITester/Core/Cookies/CookieModels.swift` - Cookies数据模型
- `Sources/MacAPITester/Features/CookiesEditor/CookiesEditorView.swift` - Cookies编辑器UI
- `Tests/MacAPITesterTests/CookieManagerTests.swift` - Cookies管理器测试

### 修改文件
- `Sources/MacAPITester/App/AppContainer.swift` - 集成Cookies管理
- `Sources/MacAPITester/Core/Networking/HTTPClient.swift` - 支持Cookies处理
- `Sources/MacAPITester/Core/Domain/Models.swift` - 添加Cookies相关模型

---

## 任务分解

### Task 1: 创建Cookies数据模型

**Files:**
- Create: `Sources/MacAPITester/Core/Cookies/CookieModels.swift`

- [ ] **Step 1: 创建Cookie数据模型**

```swift
import Foundation

struct HTTPCookie: Identifiable, Equatable, Codable {
    let id: UUID
    var domain: String
    var path: String
    var name: String
    var value: String
    var expiresDate: Date?
    var isSecure: Bool
    var isHTTPOnly: Bool
    var sameSite: SameSitePolicy
    
    enum SameSitePolicy: String, Codable, CaseIterable {
        case lax = "Lax"
        case strict = "Strict"
        case none = "None"
    }
    
    init(
        id: UUID = UUID(),
        domain: String,
        path: String = "/",
        name: String,
        value: String,
        expiresDate: Date? = nil,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        sameSite: SameSitePolicy = .lax
    ) {
        self.id = id
        self.domain = domain
        self.path = path
        self.name = name
        self.value = value
        self.expiresDate = expiresDate
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.sameSite = sameSite
    }
    
    var isExpired: Bool {
        guard let expiresDate else { return false }
        return Date() > expiresDate
    }
    
    func matches(domain: String, path: String) -> Bool {
        let domainMatch = self.domain.hasSuffix(domain) || domain.hasSuffix(self.domain)
        let pathMatch = path.hasPrefix(self.path)
        return domainMatch && pathMatch
    }
}

struct CookieJar: Codable {
    var cookies: [HTTPCookie]
    
    init(cookies: [HTTPCookie] = []) {
        self.cookies = cookies
    }
    
    mutating func addCookie(_ cookie: HTTPCookie) {
        // 移除已存在的同名Cookie
        cookies.removeAll { $0.domain == cookie.domain && $0.path == cookie.path && $0.name == cookie.name }
        cookies.append(cookie)
    }
    
    mutating func removeCookie(id: UUID) {
        cookies.removeAll { $0.id == id }
    }
    
    mutating func removeExpiredCookies() {
        cookies.removeAll { $0.isExpired }
    }
    
    func cookies(for domain: String, path: String) -> [HTTPCookie] {
        cookies.filter { $0.matches(domain: domain, path: path) && !$0.isExpired }
    }
}
```

- [ ] **Step 2: 编写Cookie模型测试**

```swift
import Testing
@testable import MacAPITester

@Suite("Cookie Models Tests")
struct CookieModelsTests {
    @Test func cookieMatchesDomainAndPath() {
        let cookie = HTTPCookie(domain: ".example.com", path: "/api", name: "session", value: "123")
        #expect(cookie.matches(domain: "api.example.com", path: "/api/users"))
        #expect(!cookie.matches(domain: "other.com", path: "/api"))
    }
    
    @Test func cookieExpirationCheck() {
        let expiredCookie = HTTPCookie(
            domain: ".example.com",
            name: "expired",
            value: "123",
            expiresDate: Date().addingTimeInterval(-3600)
        )
        #expect(expiredCookie.isExpired)
        
        let validCookie = HTTPCookie(
            domain: ".example.com",
            name: "valid",
            value: "123",
            expiresDate: Date().addingTimeInterval(3600)
        )
        #expect(!validCookie.isExpired)
    }
    
    @Test func cookieJarAddCookieRemovesDuplicates() {
        var jar = CookieJar()
        let cookie1 = HTTPCookie(domain: ".example.com", name: "session", value: "123")
        let cookie2 = HTTPCookie(domain: ".example.com", name: "session", value: "456")
        
        jar.addCookie(cookie1)
        jar.addCookie(cookie2)
        
        #expect(jar.cookies.count == 1)
        #expect(jar.cookies.first?.value == "456")
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test --filter CookieModelsTests`
Expected: 测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/Cookies/CookieModels.swift
git add Tests/MacAPITesterTests/CookieModelsTests.swift
git commit -m "feat: 添加Cookies数据模型"
```

### Task 2: 创建CookieStorage存储类

**Files:**
- Create: `Sources/MacAPITester/Core/Cookies/CookieStorage.swift`

- [ ] **Step 1: 创建CookieStorage类**

```swift
import Foundation

final class CookieStorage {
    private let database: MySQLDatabase?
    private let fileManager: FileManager
    private let fileURL: URL
    
    init(database: MySQLDatabase? = nil) {
        self.database = database
        self.fileManager = FileManager.default
        self.fileURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacAPITester")
            .appendingPathComponent("cookies.json")
        
        createDirectoryIfNeeded()
    }
    
    private func createDirectoryIfNeeded() {
        let directory = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    
    func saveCookies(_ cookieJar: CookieJar) throws {
        // 保存到文件
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cookieJar)
        try data.write(to: fileURL)
        
        // 保存到数据库
        if let database {
            try saveCookiesToDatabase(cookieJar.cookies)
        }
    }
    
    func loadCookies() throws -> CookieJar {
        // 优先从数据库加载
        if let database, let cookies = try? loadCookiesFromDatabase() {
            return CookieJar(cookies: cookies)
        }
        
        // 从文件加载
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return CookieJar()
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CookieJar.self, from: data)
    }
    
    private func saveCookiesToDatabase(_ cookies: [HTTPCookie]) throws {
        for cookie in cookies {
            let expiresDate = cookie.expiresDate.map { String($0.timeIntervalSince1970) } ?? "NULL"
            try database?.execute("""
                INSERT OR REPLACE INTO cookies (id, domain, path, name, value, expires_at, is_secure, is_http_only, same_site)
                VALUES ('\(cookie.id.uuidString)', '\(cookie.domain)', '\(cookie.path)', '\(cookie.name)', '\(cookie.value)', \(expiresDate), \(cookie.isSecure ? 1 : 0), \(cookie.isHTTPOnly ? 1 : 0), '\(cookie.sameSite.rawValue)')
            """)
        }
    }
    
    private func loadCookiesFromDatabase() throws -> [HTTPCookie]? {
        guard let results = try database?.query("SELECT * FROM cookies") else {
            return nil
        }
        
        return results.compactMap { row -> HTTPCookie? in
            guard let idString = row["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let domain = row["domain"] as? String,
                  let path = row["path"] as? String,
                  let name = row["name"] as? String,
                  let value = row["value"] as? String else {
                return nil
            }
            
            let expiresDate = (row["expires_at"] as? String).flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0) }
            let isSecure = (row["is_secure"] as? Int) == 1
            let isHTTPOnly = (row["is_http_only"] as? Int) == 1
            let sameSite = HTTPCookie.SameSitePolicy(rawValue: row["same_site"] as? String ?? "Lax") ?? .lax
            
            return HTTPCookie(
                id: id,
                domain: domain,
                path: path,
                name: name,
                value: value,
                expiresDate: expiresDate,
                isSecure: isSecure,
                isHTTPOnly: isHTTPOnly,
                sameSite: sameSite
            )
        }
    }
    
    func exportCookies(_ cookieJar: CookieJar) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(cookieJar)
    }
    
    func importCookies(from data: Data) throws -> CookieJar {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CookieJar.self, from: data)
    }
}
```

- [ ] **Step 2: 编写CookieStorage测试**

```swift
import Testing
@testable import MacAPITester

@Suite("Cookie Storage Tests")
struct CookieStorageTests {
    @Test func savesAndLoadsCookies() throws {
        let storage = CookieStorage()
        var jar = CookieJar()
        let cookie = HTTPCookie(domain: ".example.com", name: "session", value: "123")
        jar.addCookie(cookie)
        
        try storage.saveCookies(jar)
        let loaded = try storage.loadCookies()
        
        #expect(loaded.cookies.count == 1)
        #expect(loaded.cookies.first?.name == "session")
    }
    
    @Test func exportsAndImportsCookies() throws {
        let storage = CookieStorage()
        var jar = CookieJar()
        let cookie = HTTPCookie(domain: ".example.com", name: "session", value: "123")
        jar.addCookie(cookie)
        
        let data = try storage.exportCookies(jar)
        let imported = try storage.importCookies(from: data)
        
        #expect(imported.cookies.count == 1)
        #expect(imported.cookies.first?.value == "123")
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test --filter CookieStorageTests`
Expected: 测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/Cookies/CookieStorage.swift
git add Tests/MacAPITesterTests/CookieStorageTests.swift
git commit -m "feat: 添加CookieStorage存储类"
```

### Task 3: 创建CookieManager管理器

**Files:**
- Create: `Sources/MacAPITester/Core/Cookies/CookieManager.swift`

- [ ] **Step 1: 创建CookieManager类**

```swift
import Foundation

final class CookieManager {
    private var cookieJar: CookieJar
    private let storage: CookieStorage
    
    init(storage: CookieStorage) {
        self.storage = storage
        self.cookieJar = (try? storage.loadCookies()) ?? CookieJar()
    }
    
    func cookies(for request: URLRequest) -> [HTTPCookie] {
        guard let url = request.url,
              let host = url.host else {
            return []
        }
        
        return cookieJar.cookies(for: host, path: url.path)
    }
    
    func addCookies(from response: HTTPURLResponse, request: URLRequest) {
        guard let url = request.url,
              let host = url.host else {
            return
        }
        
        let headerFields = response.allHeaderFields as? [String: String] ?? [:]
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        
        for cookie in cookies {
            let httpCookie = HTTPCookie(
                domain: cookie.domain,
                path: cookie.path,
                name: cookie.name,
                value: cookie.value,
                expiresDate: cookie.expiresDate,
                isSecure: cookie.isSecure,
                isHTTPOnly: cookie.isHTTPOnly,
                sameSite: .lax
            )
            cookieJar.addCookie(httpCookie)
        }
        
        saveCookies()
    }
    
    func addCookie(_ cookie: HTTPCookie) {
        cookieJar.addCookie(cookie)
        saveCookies()
    }
    
    func removeCookie(id: UUID) {
        cookieJar.removeCookie(id: id)
        saveCookies()
    }
    
    func clearCookies() {
        cookieJar = CookieJar()
        saveCookies()
    }
    
    func removeExpiredCookies() {
        cookieJar.removeExpiredCookies()
        saveCookies()
    }
    
    func applyCookies(to request: inout URLRequest) {
        let cookies = cookies(for: request)
        guard !cookies.isEmpty else { return }
        
        var headers = request.allHTTPHeaderFields ?? [:]
        let cookieString = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        headers["Cookie"] = cookieString
        request.allHTTPHeaderFields = headers
    }
    
    func exportCookies() throws -> Data {
        try storage.exportCookies(cookieJar)
    }
    
    func importCookies(from data: Data) throws {
        cookieJar = try storage.importCookies(from: data)
        saveCookies()
    }
    
    private func saveCookies() {
        try? storage.saveCookies(cookieJar)
    }
}
```

- [ ] **Step 2: 编写CookieManager测试**

```swift
import Testing
@testable import MacAPITester

@Suite("Cookie Manager Tests")
struct CookieManagerTests {
    @Test func appliesCookiesToRequest() throws {
        let storage = CookieStorage()
        let manager = CookieManager(storage: storage)
        
        let cookie = HTTPCookie(domain: "example.com", name: "session", value: "123")
        manager.addCookie(cookie)
        
        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        manager.applyCookies(to: &request)
        
        #expect(request.value(forHTTPHeaderField: "Cookie") == "session=123")
    }
    
    @Test func extractsCookiesFromResponse() throws {
        let storage = CookieStorage()
        let manager = CookieManager(storage: storage)
        
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Set-Cookie": "session=123; Path=/; Secure"]
        )!
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        manager.addCookies(from: response, request: request)
        
        let cookies = manager.cookies(for: URLRequest(url: URL(string: "https://example.com/api")!))
        #expect(cookies.count == 1)
        #expect(cookies.first?.name == "session")
    }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `swift test --filter CookieManagerTests`
Expected: 测试通过

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Core/Cookies/CookieManager.swift
git add Tests/MacAPITesterTests/CookieManagerTests.swift
git commit -m "feat: 添加CookieManager管理器"
```

### Task 4: 创建Cookies编辑器UI

**Files:**
- Create: `Sources/MacAPITester/Features/CookiesEditor/CookiesEditorView.swift`

- [ ] **Step 1: 创建CookiesEditorView**

```swift
import SwiftUI

struct CookiesEditorView: View {
    @Binding var cookieJar: CookieJar
    let onImport: (Data) -> Void
    let onExport: () -> Data?
    
    @State private var selectedCookieID: HTTPCookie.ID?
    @State private var isEditing = false
    @State private var editingCookie = HTTPCookie(domain: "", name: "", value: "")
    @State private var searchText = ""
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    
    var filteredCookies: [HTTPCookie] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return cookieJar.cookies }
        return cookieJar.cookies.filter {
            $0.domain.localizedCaseInsensitiveContains(keyword) ||
            $0.name.localizedCaseInsensitiveContains(keyword)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            cookieList
            Divider()
            footer
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private var header: some View {
        HStack {
            Text("Cookies管理")
                .font(.headline)
            
            Spacer()
            
            TextField("搜索", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            
            Button("清除过期") {
                cookieJar.removeExpiredCookies()
            }
            .buttonStyle(.bordered)
            
            Button("清空全部") {
                cookieJar = CookieJar()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding()
    }
    
    private var cookieList: some View {
        List(selection: $selectedCookieID) {
            ForEach(filteredCookies) { cookie in
                CookieRow(cookie: cookie)
                    .tag(cookie.id)
                    .contextMenu {
                        Button("编辑") {
                            editingCookie = cookie
                            isEditing = true
                        }
                        Button("删除", role: .destructive) {
                            cookieJar.removeCookie(id: cookie.id)
                        }
                    }
            }
        }
        .listStyle(.inset)
    }
    
    private var footer: some View {
        HStack {
            Button("导入") {
                showingImportPicker = true
            }
            .buttonStyle(.bordered)
            
            Button("导出") {
                showingExportPicker = true
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("添加Cookie") {
                editingCookie = HTTPCookie(domain: "", name: "", value: "")
                isEditing = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .sheet(isPresented: $isEditing) {
            CookieEditSheet(cookie: $editingCookie, onSave: { cookie in
                cookieJar.addCookie(cookie)
                isEditing = false
            }, onCancel: {
                isEditing = false
            })
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json]
        ) { result in
            if case .success(let url) = result {
                if let data = try? Data(contentsOf: url) {
                    onImport(data)
                }
            }
        }
        .fileExporter(
            isPresented: $showingExportPicker,
            document: CookieDocument(data: onExport()),
            contentType: .json
        ) { _ in }
    }
}

struct CookieRow: View {
    let cookie: HTTPCookie
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(cookie.name)
                    .font(.headline)
                Text(cookie.domain)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(cookie.value)
                .font(.caption)
                .lineLimit(1)
            
            if cookie.isExpired {
                Text("已过期")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CookieEditSheet: View {
    @Binding var cookie: HTTPCookie
    let onSave: (HTTPCookie) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("编辑Cookie")
                .font(.headline)
            
            Form {
                TextField("域名", text: $cookie.domain)
                TextField("路径", text: $cookie.path)
                TextField("名称", text: $cookie.name)
                TextField("值", text: $cookie.value)
                DatePicker("过期时间", selection: Binding(
                    get: { cookie.expiresDate ?? Date() },
                    set: { cookie.expiresDate = $0 }
                ))
                Toggle("Secure", isOn: $cookie.isSecure)
                Toggle("HTTP Only", isOn: $cookie.isHTTPOnly)
                Picker("SameSite", selection: $cookie.sameSite) {
                    ForEach(HTTPCookie.SameSitePolicy.allCases) { policy in
                        Text(policy.rawValue).tag(policy)
                    }
                }
            }
            
            HStack {
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("保存") {
                    onSave(cookie)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct CookieDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data?
    
    init(data: Data?) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data ?? Data())
    }
}
```

- [ ] **Step 2: 更新AppContainer集成CookiesEditor**

```swift
// 在AppContainer中添加
@State private var cookieJar = CookieJar()
private let cookieManager: CookieManager

init() {
    // ... 现有代码
    let storage = CookieStorage()
    self.cookieManager = CookieManager(storage: storage)
    self.cookieJar = cookieManager.cookieJar
}

// 在body中添加Cookies编辑器标签页
```

- [ ] **Step 3: 运行应用验证UI**

Run: `./script/build_and_run.sh`
Expected: Cookies编辑器UI正常显示

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Features/CookiesEditor/CookiesEditorView.swift
git add Sources/MacAPITester/App/AppContainer.swift
git commit -m "feat: 添加Cookies编辑器UI"
```

---

## 验证清单

- [ ] Cookie模型正确创建
- [ ] CookieStorage正常工作
- [ ] CookieManager正确管理Cookies
- [ ] Cookies编辑器UI正常显示
- [ ] 导入导出功能正常
- [ ] 所有测试通过

---

## 回滚计划

如果Cookies功能失败，可以回滚：

1. 删除新增的Cookies相关文件
2. 恢复AppContainer.swift
3. 重新构建和测试
