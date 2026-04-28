# API文档服务器设计文档

## 概述

为 MacAPITester 添加内置 HTTP 服务器，将 API 文档存储在 MySQL 数据库中，同事通过浏览器访问网页即可查看接口文档。

## 设计目标

1. **内置 HTTP 服务器**：应用启动时自动启动 Web 服务
2. **数据库存储**：文档数据存储在 MySQL 中
3. **只读访问**：同事只能查看，不能编辑
4. **可配置端口**：默认 8080，可在设置中修改
5. **实时更新**：保存请求时自动更新文档

## 架构设计

### 整体架构

```
MacAPITester 应用
├── SwiftUI 主界面
│   ├── Collections（项目/请求管理）
│   ├── RequestEditor（请求编辑器）
│   ├── ResponseViewer（响应查看器）
│   └── DocServerSettings（服务器设置）
├── HTTP 服务器（SwiftNIO）
│   ├── 监听端口（默认 8080）
│   ├── 路由处理
│   └── HTML 渲染
└── MySQL 数据库
    ├── projects（项目表）
    ├── request_documents（请求文档表）
    └── api_documents（API文档表）
```

### 数据流

```
用户保存请求
    ↓
AppContainer.saveCurrentDraft()
    ↓
DocGenerator.generate()
    ↓
渲染 HTML 页面
    ↓
存储到 api_documents 表
    ↓
同事访问 http://192.168.1.100:8080
    ↓
HTTP 服务器接收请求
    ↓
从数据库读取文档
    ↓
返回 HTML 页面
```

## 模块设计

### 1. Core/DocServer/

#### DocServer.swift

```swift
import NIOCore
import NIOPosix
import NIOHTTP1

final class DocServer {
    private var channel: Channel?
    private let port: Int
    private let database: MySQLDatabase
    
    init(port: Int = 8080, database: MySQLDatabase) {
        self.port = port
        self.database = database
    }
    
    func start() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(database: self.database))
                }
            }
        
        channel = try bootstrap.bind(host: "0.0.0.0", port: port).wait()
    }
    
    func stop() {
        try? channel?.close().wait()
    }
}

final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let database: MySQLDatabase
    
    init(database: MySQLDatabase) {
        self.database = database
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        // 处理 HTTP 请求
    }
}
```

#### DocGenerator.swift

```swift
final class DocGenerator {
    private let database: MySQLDatabase
    
    init(database: MySQLDatabase) {
        self.database = database
    }
    
    func generate(project: RequestProject, requests: [RequestDocument]) throws {
        let docModel = buildDocModel(project: project, requests: requests)
        let html = renderHTML(docModel)
        
        try saveToDatabase(projectID: project.id.uuidString, title: project.name, html: html)
    }
    
    private func buildDocModel(project: RequestProject, requests: [RequestDocument]) -> APIDocModel {
        // 转换请求文档为文档模型
    }
    
    private func renderHTML(_ model: APIDocModel) -> String {
        // 渲染 HTML 页面
    }
    
    private func saveToDatabase(projectID: String, title: String, html: String) throws {
        // 保存到 api_documents 表
    }
}
```

#### DocModels.swift

```swift
struct APIDocModel: Codable {
    let projectID: String
    let projectName: String
    let generatedAt: Date
    let sections: [APIDocSection]
}

struct APIDocSection: Codable {
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

struct ParamInfo: Codable {
    let name: String
    let type: String
    let required: Bool
    let description: String
}
```

### 2. 数据库表

```sql
-- API文档表
CREATE TABLE IF NOT EXISTS api_documents (
    id VARCHAR(36) PRIMARY KEY,
    project_id VARCHAR(36) NOT NULL,
    title VARCHAR(255) NOT NULL,
    content JSON NOT NULL,
    html_cache LONGTEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    INDEX idx_project_id (project_id)
);
```

### 3. AppContainer 集成

```swift
struct AppContainer: View {
    // ... 现有属性
    
    private let docServer: DocServer
    private let docGenerator: DocGenerator
    
    init() {
        // ... 现有初始化
        
        // 初始化文档服务器
        self.docServer = DocServer(port: 8080, database: mysqlDatabase)
        self.docGenerator = DocGenerator(database: mysqlDatabase)
        
        // 启动服务器
        try? docServer.start()
    }
    
    private func saveCurrentDraft() {
        // ... 现有保存逻辑
        
        // 生成文档
        generateDocumentation()
    }
    
    private func generateDocumentation() {
        guard let selectedProjectID,
              let project = projects.first(where: { $0.id == selectedProjectID }) else {
            return
        }
        
        let projectRequests = requests.filter { $0.projectID == selectedProjectID }
        
        do {
            try docGenerator.generate(project: project, requests: projectRequests)
            statusMessage = "文档已更新，访问 http://localhost:8080 查看"
        } catch {
            statusMessage = "文档生成失败: \(error.localizedDescription)"
        }
    }
}
```

## HTML 页面设计

### 页面结构

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API文档 - {项目名称}</title>
    <style>
        /* 响应式布局样式 */
    </style>
</head>
<body>
    <div class="container">
        <!-- 左侧导航 -->
        <nav class="sidebar">
            <div class="search-box">
                <input type="text" placeholder="搜索接口...">
            </div>
            <ul class="nav-list">
                <!-- 接口列表 -->
            </ul>
        </nav>
        
        <!-- 右侧内容 -->
        <main class="content">
            <h1>API文档 - {项目名称}</h1>
            
            <!-- 接口详情 -->
            <section class="api-section">
                <h2>{接口名称}</h2>
                <div class="url-badge">
                    <span class="method">{METHOD}</span>
                    <code>{URL}</code>
                </div>
                
                <!-- 参数表格 -->
                <table class="params-table">
                    <thead>
                        <tr>
                            <th>参数名</th>
                            <th>类型</th>
                            <th>必填</th>
                            <th>描述</th>
                        </tr>
                    </thead>
                    <tbody>
                        <!-- 参数行 -->
                    </tbody>
                </table>
                
                <!-- 代码示例 -->
                <pre><code class="language-json">
                    // 请求/响应示例
                </code></pre>
            </section>
        </main>
    </div>
    
    <script>
        // 搜索功能
        // 主题切换
    </script>
</body>
</html>
```

### CSS 样式特性

- **响应式布局**：桌面/移动端适配
- **深色/浅色主题**：支持切换
- **代码高亮**：JSON 语法着色
- **平滑滚动**：锚点导航
- **搜索高亮**：关键词匹配

## 访问方式

### 本地访问

```
http://localhost:8080
```

### 局域网访问

```
http://192.168.1.100:8080
```

### 绑定域名（后续）

```
https://api-docs.example.com
```

## 配置选项

### 服务器设置

```swift
struct DocServerConfig {
    var port: Int = 8080
    var host: String = "0.0.0.0"
    var enableHTTPS: Bool = false
    var certPath: String?
    var keyPath: String?
}
```

### 设置界面

在 AppContainer 中添加设置入口：

```swift
Button("文档服务器设置") {
    showingDocServerSettings = true
}
.sheet(isPresented: $showingDocServerSettings) {
    DocServerSettingsView(config: $docServerConfig)
}
```

## 实现阶段

### 阶段1：基础功能

- [ ] DocModels 数据模型
- [ ] DocGenerator 文档生成器
- [ ] api_documents 表创建
- [ ] AppContainer 集成

### 阶段2：HTTP 服务器

- [ ] SwiftNIO 依赖添加
- [ ] DocServer 服务器实现
- [ ] HTTP 请求处理
- [ ] HTML 页面渲染

### 阶段3：UI 完善

- [ ] 服务器设置界面
- [ ] 状态栏显示访问地址
- [ ] 启动/停止服务器按钮

### 阶段4：高级功能

- [ ] 搜索功能
- [ ] 主题切换
- [ ] 访问日志

## 技术约束

1. **SwiftNIO 依赖**：需要添加 SwiftNIO 包依赖
2. **Swift 6 兼容**：使用 Swift 6 语法
3. **macOS 14+**：支持 Sonoma 及以上版本
4. **端口冲突**：需要检测端口是否被占用

## 测试策略

1. **单元测试**：文档生成器、HTML 渲染
2. **集成测试**：HTTP 服务器响应
3. **手动测试**：浏览器访问验证
