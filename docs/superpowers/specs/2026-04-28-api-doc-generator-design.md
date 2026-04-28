# API文档生成器设计文档

## 概述

为 MacAPITester 添加 API 文档生成功能，在用户保存请求时自动生成 Markdown 和 HTML 格式的 API 文档。

## 设计目标

1. **自动生成**：点击保存时自动更新文档
2. **双格式支持**：同时生成 Markdown 和 HTML
3. **高级功能**：项目分组、目录导航、搜索
4. **零依赖**：使用模板引擎，不引入外部库

## 架构设计

### 模块结构

```
Sources/MacAPITester/
├── Core/
│   └── DocGenerator/
│       ├── DocModels.swift          # 文档数据模型
│       ├── MarkdownTemplate.swift   # Markdown 模板引擎
│       ├── HTMLRenderer.swift       # Markdown → HTML 转换
│       └── DocGenerator.swift       # 主入口
├── App/
│   └── AppContainer.swift           # 集成文档生成
└── docs/
    ├── {project-name}.md            # 生成的 Markdown
    ├── {project-name}.html          # 生成的 HTML
    └── assets/
        └── style.css                # HTML 样式
```

### 数据流

```
用户点击"保存"
    ↓
AppContainer.saveCurrentDraft()
    ↓
DocGenerator.generate(project, requests)
    ↓
MarkdownTemplate.render(docModel)
    ↓
生成 Markdown 内容
    ↓
HTMLRenderer.render(markdown)
    ↓
生成 HTML 内容
    ↓
保存到 docs/ 目录
    ↓
StatusMessage: "文档已更新"
```

## 详细设计

### 1. DocModels.swift

```swift
struct APIDocModel {
    let projectName: String
    let generatedAt: Date
    let sections: [APIDocSection]
}

struct APIDocSection {
    let id: String
    let name: String
    let method: HTTPMethod
    let url: String
    let description: String
    let auth: RequestAuthConfiguration
    let queryParams: [ParamInfo]
    let headers: [ParamInfo]
    let bodyParams: [ParamInfo]
    let requestBody: String?
    let responseBody: String?
    let variables: [String: String]
}

struct ParamInfo {
    let name: String
    let type: String
    let required: Bool
    let description: String
}
```

### 2. MarkdownTemplate.swift

生成的 Markdown 结构：

```markdown
# API文档 - {项目名称}

> 生成时间：2026-04-28 14:00:00

## 目录

- [{接口名称1}](#{接口名称1})
- [{接口名称2}](#{接口名称2})

---

## {接口名称1}

**URL:** `{METHOD} {URL}`

**描述:** {描述}

**认证:** {认证类型}

### 请求参数

| 参数名 | 类型 | 必填 | 描述 |
|--------|------|------|------|
| {name} | {type} | {required} | {description} |

### 请求头

| Header | 值 |
|--------|-----|
| {name} | {value} |

### 请求示例

```{lang}
{body}
```

### 环境变量

| 变量名 | 示例值 |
|--------|--------|
| {name} | {value} |

---

## {接口名称2}

...
```

### 3. HTMLRenderer.swift

HTML 模板特性：

- **响应式布局**：适配桌面和移动端
- **侧边栏导航**：可折叠的目录树
- **搜索功能**：实时过滤接口列表
- **代码高亮**：JSON 语法着色
- **主题切换**：深色/浅色模式

### 4. DocGenerator.swift

```swift
final class DocGenerator {
    private let template = MarkdownTemplate()
    private let renderer = HTMLRenderer()
    
    func generate(project: RequestProject, requests: [RequestDocument]) throws {
        let docModel = buildDocModel(project: project, requests: requests)
        let markdown = template.render(docModel)
        let html = renderer.render(markdown, title: project.name)
        
        try saveToDocs(markdown: markdown, html: html, projectName: project.name)
    }
    
    private func buildDocModel(project: RequestProject, requests: [RequestDocument]) -> APIDocModel {
        // 转换请求文档为文档模型
    }
    
    private func saveToDocs(markdown: String, html: String, projectName: String) throws {
        // 保存到 docs/ 目录
    }
}
```

### 5. AppContainer 集成

在 `saveCurrentDraft()` 方法中添加文档生成：

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

private func generateDocumentation() {
    guard let selectedProjectID,
          let project = projects.first(where: { $0.id == selectedProjectID }) else {
        return
    }
    
    let projectRequests = requests.filter { $0.projectID == selectedProjectID }
    
    do {
        try docGenerator.generate(project: project, requests: projectRequests)
        statusMessage = "文档已更新"
    } catch {
        statusMessage = "文档生成失败: \(error.localizedDescription)"
    }
}
```

## 输出示例

### Markdown 输出

文件位置：`docs/我的项目.md`

```markdown
# API文档 - 我的项目

> 生成时间：2026-04-28 14:00:00

## 目录

- [获取用户列表](#获取用户列表)
- [创建用户](#创建用户)

---

## 获取用户列表

**URL:** `GET https://api.example.com/users`

**描述:** 获取所有用户信息

**认证:** Bearer Token

### 请求参数

| 参数名 | 类型 | 必填 | 描述 |
|--------|------|------|------|
| page | number | 否 | 页码 |
| limit | number | 否 | 每页数量 |

### 请求示例

```json
```

### 响应示例

```json
{
  "users": [
    {"id": 1, "name": "张三"},
    {"id": 2, "name": "李四"}
  ],
  "total": 100
}
```
```

### HTML 输出

文件位置：`docs/我的项目.html`

特性：
- 左侧目录导航
- 顶部搜索框
- JSON 语法高亮
- 响应式布局
- 深色/浅色主题切换

## 实现阶段

### 阶段1：基础功能

- [ ] DocModels 数据模型
- [ ] MarkdownTemplate 模板引擎
- [ ] DocGenerator 主入口
- [ ] AppContainer 集成

### 阶段2：HTML 渲染

- [ ] HTMLRenderer 转换器
- [ ] CSS 样式设计
- [ ] 代码语法高亮

### 阶段3：高级功能

- [ ] 目录导航
- [ ] 搜索功能
- [ ] 主题切换

## 技术约束

1. **零外部依赖**：不引入第三方库
2. **Swift 6 兼容**：使用 Swift 6 语法
3. **macOS 14+**：支持 Sonoma 及以上版本
4. **性能要求**：文档生成应在 100ms 内完成

## 测试策略

1. **单元测试**：模板引擎、HTML 渲染器
2. **集成测试**：完整文档生成流程
3. **手动测试**：验证输出文档的正确性
