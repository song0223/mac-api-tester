# 数据库迁移与功能增强设计文档

## 概述

本文档描述了MacAPITester应用的数据库迁移（SQLite → MySQL）和新增功能（Cookies管理、前/后执行脚本、测试用例框架）的设计方案。

## 设计目标

1. **数据库迁移**：将现有SQLite数据库转换为MySQL数据库（127.0.0.1，root，无密码）
2. **Cookies管理**：实现高级Cookies管理功能，支持导入导出
3. **脚本功能**：实现可视化脚本编辑器，支持多引擎
4. **测试用例**：实现完整测试框架，支持用例集和测试套件
5. **导入导出**：实现JSON格式的Body参数导入导出

## 架构设计

### 整体架构

采用微服务风格架构，每个功能作为独立模块：

```
MacAPITester
├── App/                          # 应用入口
├── Core/
│   ├── Database/                 # 数据库服务
│   │   ├── MySQLDatabase.swift   # MySQL连接和操作
│   │   └── Repositories.swift    # 数据仓库
│   ├── Cookies/                  # Cookies服务
│   │   ├── CookieManager.swift   # Cookies管理
│   │   └── CookieStorage.swift   # Cookies存储
│   ├── Scripts/                  # 脚本服务
│   │   ├── ScriptEngine.swift    # 脚本引擎
│   │   └── ScriptEditor.swift    # 脚本编辑器
│   ├── TestCases/                # 测试用例服务
│   │   ├── TestCaseManager.swift # 测试用例管理
│   │   └── TestRunner.swift      # 测试运行器
│   ├── Domain/                   # 领域模型
│   ├── Networking/               # 网络层
│   └── Storage/                  # 存储层（保留兼容）
├── Features/
│   ├── Collections/              # 集合管理
│   ├── RequestEditor/            # 请求编辑器
│   ├── ResponseViewer/           # 响应查看器
│   ├── CookiesEditor/            # Cookies编辑器（新增）
│   ├── ScriptEditor/             # 脚本编辑器（新增）
│   └── TestCaseEditor/           # 测试用例编辑器（新增）
└── Tests/                        # 测试
```

### 数据库设计

#### 表结构

```sql
-- 项目表
CREATE TABLE projects (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 请求文档表
CREATE TABLE request_documents (
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
);

-- Cookies表
CREATE TABLE cookies (
    id VARCHAR(36) PRIMARY KEY,
    request_id VARCHAR(36),
    domain VARCHAR(255) NOT NULL,
    path VARCHAR(255) DEFAULT '/',
    name VARCHAR(255) NOT NULL,
    value TEXT,
    expires_at TIMESTAMP NULL,
    is_secure BOOLEAN DEFAULT FALSE,
    is_http_only BOOLEAN DEFAULT FALSE,
    same_site VARCHAR(10) DEFAULT 'Lax',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (request_id) REFERENCES request_documents(id) ON DELETE CASCADE
);

-- 脚本表
CREATE TABLE scripts (
    id VARCHAR(36) PRIMARY KEY,
    request_id VARCHAR(36),
    name VARCHAR(255) NOT NULL,
    script_type VARCHAR(20) NOT NULL, -- 'pre_request' 或 'post_response'
    engine VARCHAR(50) DEFAULT 'javascript',
    content TEXT,
    is_enabled BOOLEAN DEFAULT TRUE,
    execution_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (request_id) REFERENCES request_documents(id) ON DELETE CASCADE
);

-- 测试用例表
CREATE TABLE test_cases (
    id VARCHAR(36) PRIMARY KEY,
    request_id VARCHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    variables JSON,
    expected_status INT,
    expected_body_contains TEXT,
    expected_headers JSON,
    is_enabled BOOLEAN DEFAULT TRUE,
    execution_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (request_id) REFERENCES request_documents(id) ON DELETE CASCADE
);

-- 测试套件表
CREATE TABLE test_suites (
    id VARCHAR(36) PRIMARY KEY,
    project_id VARCHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- 测试套件-用例关联表
CREATE TABLE suite_test_cases (
    suite_id VARCHAR(36) NOT NULL,
    test_case_id VARCHAR(36) NOT NULL,
    execution_order INT DEFAULT 0,
    PRIMARY KEY (suite_id, test_case_id),
    FOREIGN KEY (suite_id) REFERENCES test_suites(id) ON DELETE CASCADE,
    FOREIGN KEY (test_case_id) REFERENCES test_cases(id) ON DELETE CASCADE
);

-- 测试执行历史表
CREATE TABLE test_executions (
    id VARCHAR(36) PRIMARY KEY,
    suite_id VARCHAR(36),
    test_case_id VARCHAR(36),
    status VARCHAR(20) NOT NULL, -- 'passed', 'failed', 'error', 'skipped'
    response_status INT,
    response_time_ms INT,
    error_message TEXT,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (suite_id) REFERENCES test_suites(id) ON DELETE SET NULL,
    FOREIGN KEY (test_case_id) REFERENCES test_cases(id) ON DELETE SET NULL
);

-- 请求历史表
CREATE TABLE request_history (
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
);
```

### 模块设计

#### 1. 数据库模块（Core/Database）

**MySQLDatabase.swift**
- 提供MySQL连接管理
- 实现与SQLiteDatabase相同的接口
- 支持连接池
- 事务管理

**Repositories.swift**
- 项目仓库（ProjectRepository）
- 请求文档仓库（RequestDocumentRepository）
- Cookies仓库（CookieRepository）
- 脚本仓库（ScriptRepository）
- 测试用例仓库（TestCaseRepository）
- 测试套件仓库（TestSuiteRepository）
- 历史记录仓库（HistoryRepository）

#### 2. Cookies模块（Core/Cookies）

**CookieManager.swift**
- 从响应中提取Cookies
- 管理Cookies的生命周期
- 自动清理过期Cookies
- 支持Cookies的作用域（domain, path）

**CookieStorage.swift**
- 混合存储：数据库 + 文件
- 支持Cookies的导入导出（JSON格式）
- 与浏览器Cookies同步

#### 3. 脚本模块（Core/Scripts）

**ScriptEngine.swift**
- 多引擎支持：JavaScriptCore, QuickJS
- 脚本执行环境
- 脚本调试支持
- 脚本日志记录

**ScriptEditor.swift**
- 可视化脚本编辑器
- 语法高亮
- 自动补全
- 脚本预览

#### 4. 测试用例模块（Core/TestCases）

**TestCaseManager.swift**
- 测试用例的CRUD操作
- 测试用例的参数化
- 测试用例的导入导出

**TestRunner.swift**
- 混合执行模式：顺序/并行
- 测试结果收集
- 测试报告生成
- 测试覆盖率统计

#### 5. 导入导出模块（Core/ImportExport）

**BodyImporterExporter.swift**
- JSON格式导入导出
- 支持批量操作
- 数据验证

### UI设计

#### 1. Cookies编辑器（Features/CookiesEditor）

- Cookies列表视图
- 添加/编辑/删除Cookies
- Cookies搜索和过滤
- Cookies导入导出

#### 2. 脚本编辑器（Features/ScriptEditor）

- 脚本编辑区
- 脚本控制台
- 脚本调试工具栏
- 脚本模板库

#### 3. 测试用例编辑器（Features/TestCaseEditor）

- 测试用例列表
- 测试用例编辑表单
- 测试套件管理
- 测试执行控制台
- 测试结果展示

### 数据流

#### 1. 请求执行流程

```
用户点击发送
    ↓
执行前脚本（Scripts模块）
    ↓
构建请求（RequestBuilder）
    ↓
注入Cookies（CookieManager）
    ↓
发送请求（HTTPClient）
    ↓
提取响应Cookies（CookieManager）
    ↓
执行后脚本（Scripts模块）
    ↓
保存历史记录
    ↓
更新UI
```

#### 2. 测试执行流程

```
用户选择测试套件
    ↓
加载测试用例
    ↓
按顺序/并行执行
    ↓
每个用例执行：
    - 准备变量
    - 执行请求
    - 验证响应
    - 记录结果
    ↓
生成测试报告
    ↓
保存执行历史
```

### 错误处理

1. **数据库连接错误**：重试机制，连接池管理
2. **脚本执行错误**：错误捕获，日志记录，用户提示
3. **测试用例执行错误**：错误隔离，继续执行其他用例
4. **导入导出错误**：数据验证，错误提示

### 性能优化

1. **数据库**：连接池，索引优化，查询优化
2. **脚本**：脚本缓存，异步执行
3. **测试**：并行执行，结果缓存
4. **UI**：懒加载，分页加载

### 安全考虑

1. **数据库**：参数化查询，防止SQL注入
2. **脚本**：沙箱执行，权限控制
3. **Cookies**：敏感信息加密存储
4. **导入导出**：数据验证，防止XSS

### 测试策略

1. **单元测试**：每个模块的核心功能
2. **集成测试**：模块间的交互
3. **端到端测试**：完整功能流程
4. **性能测试**：大数据量下的性能

### 部署和迁移

1. **数据库迁移**：提供迁移脚本，支持增量迁移
2. **数据迁移**：从SQLite导出数据，导入到MySQL
3. **版本管理**：支持数据库版本升级
4. **回滚机制**：支持迁移回滚

## 实现阶段

### 第一阶段：核心功能

1. MySQL数据库连接和基本操作
2. 项目和请求的CRUD操作
3. 基本的Cookies管理
4. 简单的脚本执行

### 第二阶段：高级功能

1. 完整的Cookies管理（导入导出）
2. 可视化脚本编辑器
3. 测试用例管理
4. 测试执行框架

### 第三阶段：优化和完善

1. 性能优化
2. 安全加固
3. 用户体验改进
4. 文档完善

## 总结

本设计方案采用微服务风格架构，将每个功能作为独立模块，提高了代码的可维护性和可扩展性。数据库设计支持所有新功能的需求，UI设计符合用户习惯，数据流清晰合理。通过分阶段实现，可以逐步交付功能，降低风险。
