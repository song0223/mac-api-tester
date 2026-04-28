# API文档服务器实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 MacAPITester 添加内置 HTTP 服务器，将 API 文档存储在 MySQL 数据库中，同事通过浏览器访问网页即可查看接口文档

**Architecture:** 使用 SwiftNIO 构建 HTTP 服务器，文档存储在 MySQL 的 api_documents 表中，保存请求时自动生成 HTML 文档

**Tech Stack:** Swift 6, SwiftNIO, MySQL, SwiftUI

---

## 文件结构

### 新增文件

```
Sources/MacAPITester/Core/DocServer/
├── DocModels.swift          # 文档数据模型
├── DocGenerator.swift       # 文档生成器
├── DocServer.swift          # HTTP 服务器
├── HTMLRenderer.swift       # HTML 渲染器
└── DocServerConfig.swift    # 服务器配置

Sources/MacAPITester/Features/DocServer/
└── DocServerSettingsView.swift  # 服务器设置界面

Tests/MacAPITesterTests/
├── DocGeneratorTests.swift     # 文档生成器测试
└── DocServerTests.swift        # HTTP 服务器测试
```

### 修改文件

```
Sources/MacAPITester/App/AppContainer.swift  # 集成文档服务器
Package.swift                                 # 添加 SwiftNIO 依赖
```

---

## Task 1: 添加 SwiftNIO 依赖

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: 更新 Package.swift 添加 SwiftNIO 依赖**

```swift
// swift-tools-version: 6.3

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
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.72.0"),
    ],
    targets: [
        .executableTarget(
            name: "MacAPITester",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
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

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift package resolve
```

Expected: 成功解析 SwiftNIO 依赖

- [ ] **Step 3: 验证构建成功**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift build
```

Expected: 构建成功

- [ ] **Step 4: 提交更改**

```bash
git add Package.swift Package.resolved
git commit -m "build: 添加 SwiftNIO 依赖"
```

---

## Task 2: 创建文档数据模型

**Files:**
- Create: `Sources/MacAPITester/Core/DocServer/DocModels.swift`
- Test: `Tests/MacAPITesterTests/DocModelsTests.swift`

- [ ] **Step 1: 编写数据模型测试**

```swift
import Testing
@testable import MacAPITester

@Suite("DocModels Tests")
struct DocModelsTests {
    @Test func testAPIDocModelInitialization() {
        let model = APIDocModel(
            projectID: "test-id",
            projectName: "测试项目",
            generatedAt: Date(),
            sections: []
        )
        
        #expect(model.projectID == "test-id")
        #expect(model.projectName == "测试项目")
        #expect(model.sections.isEmpty)
    }
    
    @Test func testAPIDocSectionInitialization() {
        let section = APIDocSection(
            id: "section-1",
            name: "获取用户",
            method: "GET",
            url: "https://api.example.com/users",
            description: "获取用户列表",
            authType: "Bearer",
            queryParams: [],
            headers: [],
            bodyParams: [],
            requestBody: nil,
            responseBody: "{\"users\": []}",
            variables: [:]
        )
        
        #expect(section.name == "获取用户")
        #expect(section.method == "GET")
    }
    
    @Test func testParamInfoInitialization() {
        let param = ParamInfo(
            name: "page",
            type: "number",
            required: false,
            description: "页码"
        )
        
        #expect(param.name == "page")
        #expect(param.type == "number")
        #expect(!param.required)
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test --filter DocModelsTests
```

Expected: FAIL - DocModels 不存在

- [ ] **Step 3: 实现数据模型**

```swift
import Foundation

/// API 文档模型
struct APIDocModel: Codable, Equatable {
    let projectID: String
    let projectName: String
    let generatedAt: Date
    let sections: [APIDocSection]
}

/// API 文档章节
struct APIDocSection: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let method: String
    let url: String
    let description: String
    let authType: String
    let queryParams: [ParamInfo]
    let headers: [ParamInfo]
    let bodyParams: [ParamInfo]
    let requestBody: String?
    let responseBody: String?
    let variables: [String: String]
}

/// 参数信息
struct ParamInfo: Codable, Equatable {
    let name: String
    let type: String
    let required: Bool
    let description: String
}
```

- [ ] **Step 4: 运行测试验证通过**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test --filter DocModelsTests
```

Expected: PASS

- [ ] **Step 5: 提交更改**

```bash
git add Sources/MacAPITester/Core/DocServer/DocModels.swift Tests/MacAPITesterTests/DocModelsTests.swift
git commit -m "feat: 添加文档数据模型"
```

---

## Task 3: 创建文档生成器

**Files:**
- Create: `Sources/MacAPITester/Core/DocGenerator/DocGenerator.swift`
- Test: `Tests/MacAPITesterTests/DocGeneratorTests.swift`

- [ ] **Step 1: 编写文档生成器测试**

```swift
import Testing
@testable import MacAPITester

@Suite("DocGenerator Tests")
struct DocGeneratorTests {
    @Test func testBuildDocModel() {
        let generator = DocGenerator()
        
        let project = RequestProject(id: UUID(), name: "测试项目")
        let requests = [
            RequestDocument(
                id: UUID(),
                projectID: project.id,
                name: "获取用户",
                method: .get,
                urlString: "https://api.example.com/users",
                queryText: "page=1",
                headersText: "Accept: application/json",
                bodyText: "",
                variablesText: ""
            )
        ]
        
        let model = generator.buildDocModel(project: project, requests: requests)
        
        #expect(model.projectName == "测试项目")
        #expect(model.sections.count == 1)
        #expect(model.sections.first?.name == "获取用户")
    }
    
    @Test func testRenderMarkdown() {
        let generator = DocGenerator()
        
        let model = APIDocModel(
            projectID: "test-id",
            projectName: "测试项目",
            generatedAt: Date(),
            sections: [
                APIDocSection(
                    id: "section-1",
                    name: "获取用户",
                    method: "GET",
                    url: "https://api.example.com/users",
                    description: "获取用户列表",
                    authType: "None",
                    queryParams: [],
                    headers: [],
                    bodyParams: [],
                    requestBody: nil,
                    responseBody: nil,
                    variables: [:]
                )
            ]
        )
        
        let markdown = generator.renderMarkdown(model)
        
        #expect(markdown.contains("# API文档 - 测试项目"))
        #expect(markdown.contains("## 获取用户"))
        #expect(markdown.contains("GET"))
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test --filter DocGeneratorTests
```

Expected: FAIL - DocGenerator 不存在

- [ ] **Step 3: 实现文档生成器**

```swift
import Foundation

/// 文档生成器
final class DocGenerator {
    
    /// 构建文档模型
    func buildDocModel(project: RequestProject, requests: [RequestDocument]) -> APIDocModel {
        let sections = requests.map { request in
            buildSection(from: request)
        }
        
        return APIDocModel(
            projectID: project.id.uuidString,
            projectName: project.name,
            generatedAt: Date(),
            sections: sections
        )
    }
    
    /// 构建文档章节
    private func buildSection(from request: RequestDocument) -> APIDocSection {
        let queryParams = parseParams(from: request.queryText, separator: "=")
        let headers = parseParams(from: request.headersText, separator: ":")
        let bodyParams = parseParams(from: request.bodyText, separator: "=")
        
        return APIDocSection(
            id: request.id.uuidString,
            name: request.name,
            method: request.method.rawValue,
            url: request.urlString,
            description: request.descriptionText,
            authType: request.auth.type.rawValue,
            queryParams: queryParams,
            headers: headers,
            bodyParams: bodyParams,
            requestBody: request.bodyText.isEmpty ? nil : request.bodyText,
            responseBody: nil,
            variables: parseVariables(from: request.variablesText)
        )
    }
    
    /// 解析参数
    private func parseParams(from text: String, separator: Character) -> [ParamInfo] {
        guard !text.isEmpty else { return [] }
        
        return text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.split(separator: separator, maxSplits: 1)
                guard parts.count == 2 else { return nil }
                
                return ParamInfo(
                    name: String(parts[0]).trimmingCharacters(in: .whitespaces),
                    type: "string",
                    required: false,
                    description: ""
                )
            }
    }
    
    /// 解析变量
    private func parseVariables(from text: String) -> [String: String] {
        guard !text.isEmpty else { return [:] }
        
        var variables: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                variables[key] = value
            }
        }
        return variables
    }
    
    /// 渲染 Markdown
    func renderMarkdown(_ model: APIDocModel) -> String {
        var markdown = """
        # API文档 - \(model.projectName)
        
        > 生成时间：\(formatDate(model.generatedAt))
        
        ## 目录
        
        """
        
        // 生成目录
        for section in model.sections {
            markdown += "- [\(section.name)](#\(section.id))\n"
        }
        
        markdown += "\n---\n\n"
        
        // 生成各章节
        for section in model.sections {
            markdown += renderSection(section)
            markdown += "\n---\n\n"
        }
        
        return markdown
    }
    
    /// 渲染章节
    private func renderSection(_ section: APIDocSection) -> String {
        var markdown = """
        ## \(section.name)
        
        **URL:** `\(section.method) \(section.url)`
        
        """
        
        if !section.description.isEmpty {
            markdown += "**描述:** \(section.description)\n\n"
        }
        
        markdown += "**认证:** \(section.authType)\n\n"
        
        // 请求参数
        if !section.queryParams.isEmpty {
            markdown += "### 请求参数\n\n"
            markdown += "| 参数名 | 类型 | 必填 | 描述 |\n"
            markdown += "|--------|------|------|------|\n"
            for param in section.queryParams {
                markdown += "| \(param.name) | \(param.type) | \(param.required ? "是" : "否") | \(param.description) |\n"
            }
            markdown += "\n"
        }
        
        // 请求头
        if !section.headers.isEmpty {
            markdown += "### 请求头\n\n"
            markdown += "| Header | 值 |\n"
            markdown += "|--------|-----|\n"
            for header in section.headers {
                markdown += "| \(header.name) | \(header.description) |\n"
            }
            markdown += "\n"
        }
        
        // 请求体
        if let body = section.requestBody, !body.isEmpty {
            markdown += "### 请求示例\n\n"
            markdown += "```json\n\(body)\n```\n\n"
        }
        
        // 响应体
        if let response = section.responseBody, !response.isEmpty {
            markdown += "### 响应示例\n\n"
            markdown += "```json\n\(response)\n```\n\n"
        }
        
        // 环境变量
        if !section.variables.isEmpty {
            markdown += "### 环境变量\n\n"
            markdown += "| 变量名 | 示例值 |\n"
            markdown += "|--------|--------|\n"
            for (key, value) in section.variables {
                markdown += "| \(key) | \(value) |\n"
            }
            markdown += "\n"
        }
        
        return markdown
    }
    
    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 4: 运行测试验证通过**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test --filter DocGeneratorTests
```

Expected: PASS

- [ ] **Step 5: 提交更改**

```bash
git add Sources/MacAPITester/Core/DocGenerator/DocGenerator.swift Tests/MacAPITesterTests/DocGeneratorTests.swift
git commit -m "feat: 添加文档生成器"
```

---

## Task 4: 创建 HTML 渲染器

**Files:**
- Create: `Sources/MacAPITester/Core/DocGenerator/HTMLRenderer.swift`
- Test: `Tests/MacAPITesterTests/HTMLRendererTests.swift`

- [ ] **Step 1: 编写 HTML 渲染器测试**

```swift
import Testing
@testable import MacAPITester

@Suite("HTMLRenderer Tests")
struct HTMLRendererTests {
    @Test func testRenderHTML() {
        let renderer = HTMLRenderer()
        
        let markdown = """
        # API文档 - 测试项目
        
        ## 获取用户
        
        **URL:** `GET https://api.example.com/users`
        """
        
        let html = renderer.render(markdown, title: "测试项目")
        
        #expect(html.contains("<html"))
        #expect(html.contains("测试项目"))
        #expect(html.contains("获取用户"))
    }
    
    @Test func testHTMLContainsStyles() {
        let renderer = HTMLRenderer()
        
        let html = renderer.render("# Test", title: "Test")
        
        #expect(html.contains("<style>"))
        #expect(html.contains("</style>"))
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test --filter HTMLRendererTests
```

Expected: FAIL - HTMLRenderer 不存在

- [ ] **Step 3: 实现 HTML 渲染器**

```swift
import Foundation

/// HTML 渲染器
final class HTMLRenderer {
    
    /// 渲染 Markdown 为 HTML
    func render(_ markdown: String, title: String) -> String {
        let body = convertMarkdownToHTML(markdown)
        
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title) - API文档</title>
            \(cssStyles)
        </head>
        <body>
            <div class="container">
                <nav class="sidebar">
                    <div class="search-box">
                        <input type="text" id="searchInput" placeholder="搜索接口..." oninput="filterAPIs()">
                    </div>
                    <ul class="nav-list" id="navList">
                        \(generateNavigation(markdown))
                    </ul>
                </nav>
                <main class="content">
                    \(body)
                </main>
            </div>
            \(javascript)
        </body>
        </html>
        """
    }
    
    /// Markdown 转 HTML（简化实现）
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown
        
        // 标题
        html = html.replacingOccurrences(of: "^# (.+)$", with: "<h1>$1</h1>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^## (.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^### (.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        
        // 粗体
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        
        // 行内代码
        html = html.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        
        // 代码块
        html = html.replacingOccurrences(of: "```([^`]+)```", with: "<pre><code>$1</code></pre>", options: .regularExpression)
        
        // 表格
        html = convertTables(html)
        
        // 列表
        html = html.replacingOccurrences(of: "^- (.+)$", with: "<li>$1</li>", options: .regularExpression)
        
        // 分隔线
        html = html.replacingOccurrences(of: "^---$", with: "<hr>", options: .regularExpression)
        
        // 引用
        html = html.replacingOccurrences(of: "^> (.+)$", with: "<blockquote>$1</blockquote>", options: .regularExpression)
        
        // 段落
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = "<p>" + html + "</p>"
        
        return html
    }
    
    /// 转换表格
    private func convertTables(_ html: String) -> String {
        let lines = html.components(separatedBy: .newlines)
        var result: [String] = []
        var inTable = false
        var tableRows: [String] = []
        
        for line in lines {
            if line.contains("|") && line.contains("---") {
                // 表头分隔符，跳过
                continue
            } else if line.contains("|") {
                if !inTable {
                    inTable = true
                    tableRows = []
                }
                
                let cells = line.split(separator: "|")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                
                if tableRows.isEmpty {
                    // 表头
                    let header = cells.map { "<th>\($0)</th>" }.joined()
                    tableRows.append("<tr>\(header)</tr>")
                } else {
                    // 数据行
                    let row = cells.map { "<td>\($0)</td>" }.joined()
                    tableRows.append("<tr>\(row)</tr>")
                }
            } else {
                if inTable {
                    result.append("<table>" + tableRows.joined() + "</table>")
                    inTable = false
                    tableRows = []
                }
                result.append(line)
            }
        }
        
        if inTable {
            result.append("<table>" + tableRows.joined() + "</table>")
        }
        
        return result.joined(separator: "\n")
    }
    
    /// 生成导航
    private func generateNavigation(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var navItems: [String] = []
        
        for line in lines {
            if line.hasPrefix("## ") {
                let name = String(line.dropFirst(3))
                let id = name.lowercased().replacingOccurrences(of: " ", with: "-")
                navItems.append("<li><a href=\"#\(id)\">\(name)</a></li>")
            }
        }
        
        return navItems.joined(separator: "\n")
    }
    
    /// CSS 样式
    private var cssStyles: String {
        """
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                line-height: 1.6;
                color: #333;
                background-color: #f5f5f5;
            }
            
            .container {
                display: flex;
                min-height: 100vh;
            }
            
            .sidebar {
                width: 280px;
                background: #fff;
                border-right: 1px solid #e0e0e0;
                padding: 20px;
                position: fixed;
                height: 100vh;
                overflow-y: auto;
            }
            
            .search-box {
                margin-bottom: 20px;
            }
            
            .search-box input {
                width: 100%;
                padding: 10px;
                border: 1px solid #ddd;
                border-radius: 4px;
                font-size: 14px;
            }
            
            .nav-list {
                list-style: none;
            }
            
            .nav-list li {
                margin-bottom: 8px;
            }
            
            .nav-list a {
                color: #0066cc;
                text-decoration: none;
                font-size: 14px;
            }
            
            .nav-list a:hover {
                text-decoration: underline;
            }
            
            .content {
                flex: 1;
                margin-left: 280px;
                padding: 40px;
                max-width: 1000px;
            }
            
            h1 {
                font-size: 28px;
                margin-bottom: 20px;
                color: #222;
            }
            
            h2 {
                font-size: 22px;
                margin-top: 40px;
                margin-bottom: 16px;
                color: #333;
                border-bottom: 2px solid #0066cc;
                padding-bottom: 8px;
            }
            
            h3 {
                font-size: 18px;
                margin-top: 24px;
                margin-bottom: 12px;
                color: #444;
            }
            
            code {
                background: #f4f4f4;
                padding: 2px 6px;
                border-radius: 3px;
                font-family: "SF Mono", Monaco, Consolas, monospace;
                font-size: 14px;
            }
            
            pre {
                background: #2d2d2d;
                color: #f8f8f2;
                padding: 16px;
                border-radius: 6px;
                overflow-x: auto;
                margin: 16px 0;
            }
            
            pre code {
                background: none;
                color: inherit;
                padding: 0;
            }
            
            table {
                width: 100%;
                border-collapse: collapse;
                margin: 16px 0;
            }
            
            th, td {
                border: 1px solid #ddd;
                padding: 12px;
                text-align: left;
            }
            
            th {
                background: #f8f9fa;
                font-weight: 600;
            }
            
            tr:nth-child(even) {
                background: #f9f9f9;
            }
            
            hr {
                border: none;
                border-top: 1px solid #e0e0e0;
                margin: 40px 0;
            }
            
            blockquote {
                border-left: 4px solid #0066cc;
                padding: 12px 20px;
                margin: 16px 0;
                background: #f8f9fa;
                color: #666;
            }
            
            @media (max-width: 768px) {
                .sidebar {
                    display: none;
                }
                
                .content {
                    margin-left: 0;
                    padding: 20px;
                }
            }
        </style>
        """
    }
    
    /// JavaScript
    private var javascript: String {
        """
        <script>
            function filterAPIs() {
                const input = document.getElementById('searchInput');
                const filter = input.value.toLowerCase();
                const navItems = document.querySelectorAll('#navList li');
                
                navItems.forEach(item => {
                    const text = item.textContent.toLowerCase();
                    item.style.display = text.includes(filter) ? '' : 'none';
                });
            }
        </script>
        """
    }
}
```

- [ ] **Step 4: 运行测试验证通过**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test --filter HTMLRendererTests
```

Expected: PASS

- [ ] **Step 5: 提交更改**

```bash
git add Sources/MacAPITester/Core/DocGenerator/HTMLRenderer.swift Tests/MacAPITesterTests/HTMLRendererTests.swift
git commit -m "feat: 添加HTML渲染器"
```

---

## Task 5: 创建数据库表和仓库

**Files:**
- Create: `Sources/MacAPITester/Core/DocGenerator/DocRepository.swift`
- Modify: `Sources/MacAPITester/Core/Database/DatabaseMigration.swift`
- Test: `Tests/MacAPITesterTests/DocRepositoryTests.swift`

- [ ] **Step 1: 编写仓库测试**

```swift
import Testing
@testable import MacAPITester

@Suite("DocRepository Tests")
struct DocRepositoryTests {
    @Test func testSaveAndFetchDocument() throws {
        let database = try MySQLDatabase()
        let repository = try DocRepository(database: database)
        
        let html = "<html><body>Test</body></html>"
        try repository.saveDocument(
            id: "test-doc-1",
            projectID: "test-project-1",
            title: "测试文档",
            html: html
        )
        
        let fetched = try repository.fetchDocument(projectID: "test-project-1")
        #expect(fetched != nil)
        #expect(fetched?.title == "测试文档")
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test --filter DocRepositoryTests
```

Expected: FAIL - DocRepository 不存在

- [ ] **Step 3: 更新数据库迁移**

在 `DatabaseMigration.swift` 的 `createTables()` 方法中添加：

```swift
// 创建 API 文档表
try mysqlDatabase.execute("""
    CREATE TABLE IF NOT EXISTS api_documents (
        id VARCHAR(36) PRIMARY KEY,
        project_id VARCHAR(36) NOT NULL,
        title VARCHAR(255) NOT NULL,
        html_content LONGTEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        INDEX idx_project_id (project_id)
    )
""")
```

- [ ] **Step 4: 实现文档仓库**

```swift
import Foundation

/// 文档仓库
final class DocRepository: MySQLRepository {
    
    override init(database: MySQLDatabase) throws {
        try super.init(database: database)
        try createTable()
    }
    
    /// 创建表
    private func createTable() throws {
        try database.execute("""
            CREATE TABLE IF NOT EXISTS api_documents (
                id VARCHAR(36) PRIMARY KEY,
                project_id VARCHAR(36) NOT NULL,
                title VARCHAR(255) NOT NULL,
                html_content LONGTEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
                INDEX idx_project_id (project_id)
            )
        """)
    }
    
    /// 保存文档
    func saveDocument(id: String, projectID: String, title: String, html: String) throws {
        try database.execute(
            """
            INSERT INTO api_documents (id, project_id, title, html_content)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE title = ?, html_content = ?, updated_at = CURRENT_TIMESTAMP
            """,
            parameters: [
                .string(id),
                .string(projectID),
                .string(title),
                .string(html),
                .string(title),
                .string(html)
            ]
        )
    }
    
    /// 获取文档
    func fetchDocument(projectID: String) throws -> (id: String, title: String, html: String)? {
        let results = try database.query(
            "SELECT id, title, html_content FROM api_documents WHERE project_id = ? ORDER BY updated_at DESC LIMIT 1",
            parameters: [.string(projectID)]
        )
        
        guard let row = results.first,
              let id = row["id"] as? String,
              let title = row["title"] as? String,
              let html = row["html_content"] as? String else {
            return nil
        }
        
        return (id: id, title: title, html: html)
    }
    
    /// 获取所有文档
    func fetchAllDocuments() throws -> [(id: String, projectID: String, title: String)] {
        let results = try database.query("SELECT id, project_id, title FROM api_documents ORDER BY updated_at DESC")
        
        return results.compactMap { row in
            guard let id = row["id"] as? String,
                  let projectID = row["project_id"] as? String,
                  let title = row["title"] as? String else {
                return nil
            }
            return (id: id, projectID: projectID, title: title)
        }
    }
    
    /// 删除文档
    func deleteDocument(id: String) throws {
        try database.execute(
            "DELETE FROM api_documents WHERE id = ?",
            parameters: [.string(id)]
        )
    }
}
```

- [ ] **Step 5: 运行测试验证通过**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test --filter DocRepositoryTests
```

Expected: PASS

- [ ] **Step 6: 提交更改**

```bash
git add Sources/MacAPITester/Core/DocGenerator/DocRepository.swift Sources/MacAPITester/Core/Database/DatabaseMigration.swift Tests/MacAPITesterTests/DocRepositoryTests.swift
git commit -m "feat: 添加文档仓库和数据库表"
```

---

## Task 6: 创建 HTTP 服务器

**Files:**
- Create: `Sources/MacAPITester/Core/DocServer/DocServer.swift`
- Test: `Tests/MacAPITesterTests/DocServerTests.swift`

- [ ] **Step 1: 编写服务器测试**

```swift
import Testing
@testable import MacAPITester

@Suite("DocServer Tests")
struct DocServerTests {
    @Test func testServerInitialization() throws {
        let database = try MySQLDatabase()
        let server = DocServer(port: 8081, database: database)
        
        #expect(server.port == 8081)
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test --filter DocServerTests
```

Expected: FAIL - DocServer 不存在

- [ ] **Step 3: 实现 HTTP 服务器**

```swift
import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1

/// 文档服务器配置
struct DocServerConfig {
    var port: Int = 8080
    var host: String = "0.0.0.0"
}

/// 文档服务器
final class DocServer {
    let port: Int
    private let host: String
    private let database: MySQLDatabase
    private var channel: Channel?
    private var group: MultiThreadedEventLoopGroup?
    
    init(port: Int = 8080, host: String = "0.0.0.0", database: MySQLDatabase) {
        self.port = port
        self.host = host
        self.database = database
    }
    
    /// 启动服务器
    func start() throws {
        group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        guard let group else {
            throw DocServerError.serverStartFailed("无法创建事件循环组")
        }
        
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [weak self] channel in
                guard let self else {
                    return channel.makeFailedFuture(DocServerError.serverStartFailed("服务器已释放"))
                }
                
                return channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(database: self.database))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
        channel = try bootstrap.bind(host: host, port: port).wait()
        
        print("📄 文档服务器已启动: http://\(host):\(port)")
    }
    
    /// 停止服务器
    func stop() {
        try? channel?.close().wait()
        try? group?.syncShutdownGracefully()
        channel = nil
        group = nil
        
        print("📄 文档服务器已停止")
    }
    
    /// 获取访问地址
    var accessURL: String {
        "http://localhost:\(port)"
    }
    
    /// 获取局域网访问地址
    var localNetworkURL: String? {
        getLocalIPAddress().map { "http://\($0):\(port)" }
    }
    
    /// 获取本地 IP 地址
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
}

/// HTTP 请求处理器
final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let database: MySQLDatabase
    
    init(database: MySQLDatabase) {
        self.database = database
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let request):
            handleRequest(request: request, context: context)
        case .body:
            break
        case .end:
            break
        }
    }
    
    private func handleRequest(request: HTTPRequestHead, context: ChannelHandlerContext) {
        let path = request.uri
        
        if path == "/" || path == "/index.html" {
            serveIndexPage(context: context)
        } else if path.hasPrefix("/doc/") {
            let projectID = String(path.dropFirst(5))
            serveDocumentPage(projectID: projectID, context: context)
        } else {
            serve404(context: context)
        }
    }
    
    private func serveIndexPage(context: ChannelHandlerContext) {
        do {
            let repository = try DocRepository(database: database)
            let documents = try repository.fetchAllDocuments()
            
            var html = """
            <!DOCTYPE html>
            <html lang="zh-CN">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>API文档中心</title>
                <style>
                    body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 0 auto; padding: 40px; }
                    h1 { color: #333; }
                    .doc-list { list-style: none; padding: 0; }
                    .doc-item { margin: 16px 0; padding: 16px; background: #f5f5f5; border-radius: 8px; }
                    .doc-item a { color: #0066cc; text-decoration: none; font-size: 18px; }
                    .doc-item a:hover { text-decoration: underline; }
                </style>
            </head>
            <body>
                <h1>📚 API文档中心</h1>
                <ul class="doc-list">
            """
            
            for doc in documents {
                html += """
                    <li class="doc-item">
                        <a href="/doc/\(doc.projectID)">\(doc.title)</a>
                    </li>
                """
            }
            
            html += """
                </ul>
            </body>
            </html>
            """
            
            sendResponse(html: html, context: context)
        } catch {
            sendResponse(html: "<h1>服务器错误</h1>", status: .internalServerError, context: context)
        }
    }
    
    private func serveDocumentPage(projectID: String, context: ChannelHandlerContext) {
        do {
            let repository = try DocRepository(database: database)
            
            if let document = try repository.fetchDocument(projectID: projectID) {
                sendResponse(html: document.html, context: context)
            } else {
                sendResponse(html: "<h1>文档不存在</h1>", status: .notFound, context: context)
            }
        } catch {
            sendResponse(html: "<h1>服务器错误</h1>", status: .internalServerError, context: context)
        }
    }
    
    private func serve404(context: ChannelHandlerContext) {
        sendResponse(html: "<h1>404 - 页面不存在</h1>", status: .notFound, context: context)
    }
    
    private func sendResponse(html: String, status: HTTPResponseStatus = .ok, context: ChannelHandlerContext) {
        let body = ByteBuffer(string: html)
        
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/html; charset=utf-8")
        headers.add(name: "Content-Length", value: "\(body.readableBytes)")
        
        let responseHead = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(responseHead)), promise: nil)
        
        let bodyPart = HTTPServerResponsePart.body(.byteBuffer(body))
        context.write(wrapOutboundOut(bodyPart), promise: nil)
        
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}

/// 服务器错误
enum DocServerError: Error {
    case serverStartFailed(String)
}
```

- [ ] **Step 4: 运行测试验证通过**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test --filter DocServerTests
```

Expected: PASS

- [ ] **Step 5: 提交更改**

```bash
git add Sources/MacAPITester/Core/DocServer/DocServer.swift Tests/MacAPITesterTests/DocServerTests.swift
git commit -m "feat: 添加HTTP文档服务器"
```

---

## Task 7: 集成到 AppContainer

**Files:**
- Modify: `Sources/MacAPITester/App/AppContainer.swift`

- [ ] **Step 1: 添加 DocServer 和 DocGenerator 属性**

在 AppContainer 中添加：

```swift
private var docServer: DocServer?
private let docGenerator = DocGenerator()
```

- [ ] **Step 2: 在初始化时启动服务器**

在 `init()` 方法的 MySQL 初始化成功后添加：

```swift
// 启动文档服务器
self.docServer = DocServer(database: mysqlDatabase)
try? self.docServer?.start()
```

- [ ] **Step 3: 添加文档生成方法**

```swift
/// 生成文档
private func generateDocumentation() {
    guard let selectedProjectID,
          let project = projects.first(where: { $0.id == selectedProjectID }) else {
        return
    }
    
    let projectRequests = requests.filter { $0.projectID == selectedProjectID }
    
    do {
        let model = docGenerator.buildDocModel(project: project, requests: projectRequests)
        let html = HTMLRenderer().render(docGenerator.renderMarkdown(model), title: project.name)
        
        guard let database = mysqlDatabase else { return }
        let repository = try DocRepository(database: database)
        
        try repository.saveDocument(
            id: project.id.uuidString,
            projectID: project.id.uuidString,
            title: project.name,
            html: html
        )
        
        if let url = docServer?.accessURL {
            statusMessage = "文档已更新，访问 \(url) 查看"
        }
    } catch {
        statusMessage = "文档生成失败: \(error.localizedDescription)"
    }
}
```

- [ ] **Step 4: 在保存时调用文档生成**

在 `saveCurrentDraft()` 方法中添加：

```swift
private func saveCurrentDraft() {
    guard let binding = selectedRequestBinding else { return }
    let request = binding.wrappedValue
    statusMessage = "已保存草稿：\(request.name)"
    
    // 同步到数据库
    syncRequestToDatabase(request, isNew: false)
    
    // 生成文档
    generateDocumentation()
}
```

- [ ] **Step 5: 验证构建成功**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift build
```

Expected: 构建成功

- [ ] **Step 6: 提交更改**

```bash
git add Sources/MacAPITester/App/AppContainer.swift
git commit -m "feat: 集成文档服务器到AppContainer"
```

---

## Task 8: 添加服务器设置界面

**Files:**
- Create: `Sources/MacAPITester/Features/DocServer/DocServerSettingsView.swift`
- Modify: `Sources/MacAPITester/App/AppContainer.swift`

- [ ] **Step 1: 创建设置界面**

```swift
import SwiftUI

/// 文档服务器设置视图
struct DocServerSettingsView: View {
    @Binding var isPresented: Bool
    let server: DocServer?
    let onRestart: (Int) -> Void
    
    @State private var port: String = "8080"
    @State private var isRunning: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("文档服务器设置")
                .font(.headline)
            
            Form {
                HStack {
                    Text("端口:")
                    TextField("端口号", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                
                HStack {
                    Text("状态:")
                    Circle()
                        .fill(isRunning ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    Text(isRunning ? "运行中" : "已停止")
                }
                
                if let server, isRunning {
                    HStack {
                        Text("访问地址:")
                        Text(server.accessURL)
                            .foregroundColor(.blue)
                    }
                    
                    if let localURL = server.localNetworkURL {
                        HStack {
                            Text("局域网地址:")
                            Text(localURL)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(isRunning ? "重启" : "启动") {
                    if let portInt = Int(port) {
                        onRestart(portInt)
                        isRunning = true
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            isRunning = server != nil
            if let server {
                port = "\(server.port)"
            }
        }
    }
}
```

- [ ] **Step 2: 在 AppContainer 中添加设置入口**

在底部操作栏添加设置按钮：

```swift
Button("文档设置") {
    showingDocServerSettings = true
}
.sheet(isPresented: $showingDocServerSettings) {
    DocServerSettingsView(
        isPresented: $showingDocServerSettings,
        server: docServer,
        onRestart: { newPort in
            docServer?.stop()
            docServer = DocServer(port: newPort, database: mysqlDatabase!)
            try? docServer?.start()
        }
    )
}
```

- [ ] **Step 3: 验证构建成功**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift build
```

Expected: 构建成功

- [ ] **Step 4: 提交更改**

```bash
git add Sources/MacAPITester/Features/DocServer/DocServerSettingsView.swift Sources/MacAPITester/App/AppContainer.swift
git commit -m "feat: 添加文档服务器设置界面"
```

---

## Task 9: 端到端测试

**Files:**
- Test: `Tests/MacAPITesterTests/DocServerIntegrationTests.swift`

- [ ] **Step 1: 编写集成测试**

```swift
import Testing
@testable import MacAPITester

@Suite("DocServer Integration Tests")
struct DocServerIntegrationTests {
    @Test func testEndToEndDocumentGeneration() throws {
        let database = try MySQLDatabase()
        let generator = DocGenerator()
        let repository = try DocRepository(database: database)
        
        // 创建测试数据
        let project = RequestProject(id: UUID(), name: "测试项目")
        let requests = [
            RequestDocument(
                id: UUID(),
                projectID: project.id,
                name: "获取用户",
                method: .get,
                urlString: "https://api.example.com/users",
                queryText: "page=1",
                headersText: "Accept: application/json",
                bodyText: "",
                variablesText: "token=abc123"
            )
        ]
        
        // 生成文档
        let model = generator.buildDocModel(project: project, requests: requests)
        let html = HTMLRenderer().render(generator.renderMarkdown(model), title: project.name)
        
        // 保存到数据库
        try repository.saveDocument(
            id: project.id.uuidString,
            projectID: project.id.uuidString,
            title: project.name,
            html: html
        )
        
        // 验证可以读取
        let fetched = try repository.fetchDocument(projectID: project.id.uuidString)
        #expect(fetched != nil)
        #expect(fetched?.title == "测试项目")
        #expect(fetched?.html.contains("获取用户") == true)
    }
}
```

- [ ] **Step 2: 运行集成测试**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test --filter DocServerIntegrationTests
```

Expected: PASS

- [ ] **Step 3: 提交更改**

```bash
git add Tests/MacAPITesterTests/DocServerIntegrationTests.swift
git commit -m "test: 添加文档服务器集成测试"
```

---

## Task 10: 完整验证

- [ ] **Step 1: 运行所有测试**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift test
```

Expected: 所有测试通过

- [ ] **Step 2: 构建应用**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift build
```

Expected: 构建成功

- [ ] **Step 3: 运行应用并测试**

```bash
cd /Users/songxiang/work/mac/mac-api-tester && swift run
```

Expected:
1. 应用启动成功
2. 保存请求后生成文档
3. 浏览器访问 http://localhost:8080 可以看到文档

- [ ] **Step 4: 最终提交**

```bash
git add .
git commit -m "feat: 完成API文档服务器功能"
```

---

## 验证清单

- [ ] SwiftNIO 依赖添加成功
- [ ] 数据模型定义正确
- [ ] 文档生成器工作正常
- [ ] HTML 渲染器生成正确页面
- [ ] 数据库表创建成功
- [ ] HTTP 服务器启动成功
- [ ] 浏览器可以访问文档
- [ ] 保存请求时自动更新文档
- [ ] 设置界面可以配置端口
- [ ] 所有测试通过
