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
            <meta name="apple-mobile-web-app-capable" content="yes">
            <meta name="apple-mobile-web-app-status-bar-style" content="default">
            <meta name="google" content="notranslate">
            <title>\(title) - API文档</title>
            \(cssStyles)
        </head>
        <body>
            <div class="container">
                <nav class="sidebar">
                    <div class="sidebar-header">
                        <a href="/" class="back-link">← 返回文档列表</a>
                        <h2 class="sidebar-title">\(escapeHTML(title))</h2>
                        <div class="search-box">
                            <input type="text" id="searchInput" placeholder="搜索接口..." oninput="filterAPIs()" autocomplete="off">
                        </div>
                    </div>
                    <ul class="nav-list" id="navList">
                        \(generateNavigation(markdown))
                    </ul>
                </nav>
                <main class="content" id="contentArea">
                    \(body)
                </main>
            </div>
            \(javascript)
        </body>
        </html>
        """
    }
    
    /// Markdown 转 HTML
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var htmlLines: [String] = []
        var inCodeBlock = false
        var codeContent = ""
        var codeLanguage = ""
        var inTable = false
        var tableRows: [String] = []
        var isFirstTableRow = true
        var inList = false
        var listItems: [String] = []
        var currentSectionId: String? = nil
        var isFirstSection = true

        for line in lines {
            // Code block - 支持 ```language 格式
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCodeBlock {
                    // 结束代码块
                    let escapedContent = escapeHTML(codeContent.trimmingCharacters(in: .newlines))
                    let langClass = codeLanguage.isEmpty ? "" : " class=\"language-\(codeLanguage)\""
                    htmlLines.append("<pre><code\(langClass)>\(escapedContent)</code></pre>")
                    codeContent = ""
                    codeLanguage = ""
                    inCodeBlock = false
                } else {
                    // 开始代码块，提取语言标识
                    let langPart = line.trimmingCharacters(in: .whitespaces).dropFirst(3).trimmingCharacters(in: .whitespaces)
                    codeLanguage = String(langPart)
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeContent += line + "\n"
                continue
            }

            // Table - 支持标准 Markdown 表格格式
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if isTableSeparator(trimmedLine) {
                // 跳过分隔行（如 |--------|------|）
                continue
            }

            if isTableRow(trimmedLine) {
                if !inTable {
                    inTable = true
                    tableRows = []
                    isFirstTableRow = true
                }

                let cells = parseTableCells(trimmedLine)

                if isFirstTableRow {
                    let header = cells.map { "<th>\(escapeHTML($0))</th>" }.joined()
                    tableRows.append("<thead><tr>\(header)</tr></thead>")
                    isFirstTableRow = false
                } else {
                    let row = cells.map { "<td>\(formatInline($0))</td>" }.joined()
                    tableRows.append("<tr>\(row)</tr>")
                }
                continue
            }

            if inTable {
                htmlLines.append("<table>" + tableRows.joined() + "</table>")
                inTable = false
                tableRows = []
                isFirstTableRow = true
            }

            // List items
            if line.hasPrefix("- ") {
                if !inList {
                    inList = true
                    listItems = []
                }
                listItems.append("<li>\(formatInline(String(line.dropFirst(2))))</li>")
                continue
            }

            if inList {
                htmlLines.append("<ul>" + listItems.joined() + "</ul>")
                inList = false
                listItems = []
            }

            // Headings
            if line.hasPrefix("### ") {
                htmlLines.append("<h3>\(formatInline(String(line.dropFirst(4))))</h3>")
                continue
            }
            if line.hasPrefix("## ") {
                // 关闭上一个 section（如果存在）
                if currentSectionId != nil {
                    htmlLines.append("</div>")
                }

                // 开始新的 section
                let name = String(line.dropFirst(3))
                let sectionId = name.lowercased().replacingOccurrences(of: " ", with: "-")
                currentSectionId = sectionId

                let activeClass = isFirstSection ? " active" : ""
                htmlLines.append("<div id=\"\(sectionId)\" class=\"api-section\(activeClass)\">")
                isFirstSection = false

                // 生成 API 头部
                let displayName = removeMethod(from: name)
                htmlLines.append("<div class=\"api-header\">")
                htmlLines.append("<h2>\(escapeHTML(displayName))</h2>")
                continue
            }
            if line.hasPrefix("# ") {
                htmlLines.append("<h1>\(formatInline(String(line.dropFirst(2))))</h1>")
                continue
            }

            // Horizontal rule
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                htmlLines.append("<hr>")
                continue
            }

            // Blockquote
            if line.hasPrefix("> ") {
                htmlLines.append("<blockquote>\(formatInline(String(line.dropFirst(2))))</blockquote>")
                continue
            }

            // URL line
            if line.hasPrefix("**URL:**") {
                let urlContent = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                // 提取方法和 URL
                let parts = urlContent.split(separator: " ", maxSplits: 1)
                if parts.count == 2 {
                    let method = String(parts[0]).replacingOccurrences(of: "`", with: "")
                    let url = String(parts[1]).replacingOccurrences(of: "`", with: "")
                    htmlLines.append("<div class=\"api-url\">")
                    htmlLines.append("<span class=\"method method-\(method.lowercased())\">\(escapeHTML(method))</span>")
                    htmlLines.append("<span class=\"url\">\(escapeHTML(url))</span>")
                    htmlLines.append("</div>")
                }
                continue
            }

            // Description line
            if line.hasPrefix("**描述:**") {
                let desc = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                htmlLines.append("<p class=\"api-description\">\(formatInline(desc))</p>")
                continue
            }

            // Auth line
            if line.hasPrefix("**认证:**") {
                let auth = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                htmlLines.append("<p class=\"api-auth\"><strong>认证:</strong> \(escapeHTML(auth))</p>")
                htmlLines.append("</div>") // Close api-header
                continue
            }

            // Empty line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                htmlLines.append("")
                continue
            }

            // Regular paragraph
            htmlLines.append("<p>\(formatInline(line))</p>")
        }

        // Close any open structures
        if inTable {
            htmlLines.append("<table>" + tableRows.joined() + "</table>")
        }
        if inList {
            htmlLines.append("<ul>" + listItems.joined() + "</ul>")
        }
        if inCodeBlock {
            let escapedContent = escapeHTML(codeContent.trimmingCharacters(in: .newlines))
            htmlLines.append("<pre><code>\(escapedContent)</code></pre>")
        }

        // Close last section
        if currentSectionId != nil {
            htmlLines.append("</div>")
        }

        return htmlLines.joined(separator: "\n")
    }

    /// 检查是否是表格分隔行（如 |--------|------|）
    private func isTableSeparator(_ line: String) -> Bool {
        // 移除所有 | 和空格，检查是否只包含 - 和 :
        let cleaned = line.replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
        return cleaned.isEmpty && line.contains("-") && line.contains("|")
    }

    /// 检查是否是表格行
    private func isTableRow(_ line: String) -> Bool {
        // 标准格式：以 | 开头和结尾
        if line.hasPrefix("|") && line.hasSuffix("|") {
            return true
        }
        // 以 | 开头
        if line.hasPrefix("|") {
            return true
        }
        // 包含多个 |（至少2个，表示有分隔的列）
        let pipeCount = line.filter { $0 == "|" }.count
        return pipeCount >= 2
    }

    /// 解析表格单元格
    private func parseTableCells(_ line: String) -> [String] {
        // 移除开头和结尾的 |
        var trimmed = line
        if trimmed.hasPrefix("|") {
            trimmed = String(trimmed.dropFirst())
        }
        if trimmed.hasSuffix("|") {
            trimmed = String(trimmed.dropLast())
        }

        // 按 | 分割并清理空格，保留空单元格
        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    /// 转义 HTML 特殊字符
    private func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
    }

    /// Format inline elements (bold, code, links)
    private func formatInline(_ text: String) -> String {
        var result = text

        // Bold
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)

        // Inline code
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)

        // Links
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)

        return result
    }
    
    /// 生成导航
    private func generateNavigation(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var navItems: [String] = []

        for line in lines {
            if line.hasPrefix("## ") {
                let name = String(line.dropFirst(3))
                let id = name.lowercased().replacingOccurrences(of: " ", with: "-")
                // 提取 HTTP 方法
                let method = extractMethod(from: name)
                let displayName = removeMethod(from: name)
                let methodBadge = method.isEmpty ? "" : "<span class=\"method-badge method-\(method.lowercased())\">\(method)</span>"
                navItems.append("<li><a href=\"#\(id)\">\(methodBadge)<span class=\"api-name\">\(escapeHTML(displayName))</span></a></li>")
            }
        }

        return navItems.joined(separator: "\n")
    }

    private func extractMethod(from name: String) -> String {
        let methods = ["GET ", "POST ", "PUT ", "PATCH ", "DELETE "]
        for method in methods {
            if name.uppercased().hasPrefix(method) {
                return String(method.dropLast()) // 移除末尾空格
            }
        }
        return ""
    }

    private func removeMethod(from name: String) -> String {
        let methods = ["GET ", "POST ", "PUT ", "PATCH ", "DELETE "]
        var result = name
        for method in methods {
            if result.uppercased().hasPrefix(method) {
                result = String(result.dropFirst(method.count))
                break
            }
        }
        return result
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
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                line-height: 1.7;
                color: #1d1d1f;
                background-color: #f5f5f7;
                -webkit-font-smoothing: antialiased;
            }

            .container {
                display: flex;
                min-height: 100vh;
            }

            .sidebar {
                width: 320px;
                min-width: 320px;
                background: #ffffff;
                border-right: 1px solid #d2d2d7;
                position: fixed;
                height: 100vh;
                overflow-y: auto;
                z-index: 10;
                display: flex;
                flex-direction: column;
            }

            .sidebar::-webkit-scrollbar {
                width: 6px;
            }

            .sidebar::-webkit-scrollbar-track {
                background: transparent;
            }

            .sidebar::-webkit-scrollbar-thumb {
                background: #d2d2d7;
                border-radius: 3px;
            }

            .sidebar-header {
                padding: 24px 20px 16px;
                border-bottom: 1px solid #d2d2d7;
                position: sticky;
                top: 0;
                background: #ffffff;
                z-index: 1;
            }

            .back-link {
                display: inline-block;
                font-size: 13px;
                color: #0071e3;
                text-decoration: none;
                margin-bottom: 12px;
            }

            .back-link:hover {
                text-decoration: underline;
            }

            .sidebar-title {
                font-size: 18px;
                font-weight: 600;
                color: #1d1d1f;
                margin-bottom: 16px;
            }

            .search-box {
                margin-bottom: 0;
            }

            .search-box input {
                width: 100%;
                padding: 10px 14px;
                border: 1px solid #d2d2d7;
                border-radius: 8px;
                font-size: 14px;
                background: #f5f5f7;
                transition: all 0.2s ease;
                outline: none;
            }

            .search-box input:focus {
                border-color: #0071e3;
                background: #fff;
                box-shadow: 0 0 0 3px rgba(0, 113, 227, 0.1);
            }

            .search-box input::placeholder {
                color: #86868b;
            }

            .nav-list {
                list-style: none;
                padding: 12px 12px;
            }

            .nav-list li {
                margin-bottom: 2px;
            }

            .nav-list a {
                color: #1d1d1f;
                text-decoration: none;
                font-size: 14px;
                font-weight: 500;
                display: block;
                padding: 10px 12px;
                border-radius: 8px;
                transition: all 0.2s ease;
                border: 1px solid transparent;
            }

            .nav-list a:hover {
                background: #f5f5f7;
                color: #0071e3;
            }

            .nav-list a.active {
                background: #0071e3;
                color: #ffffff;
                border-color: #0071e3;
            }

            .nav-list .method-badge {
                display: inline-block;
                font-size: 11px;
                font-weight: 700;
                padding: 2px 6px;
                border-radius: 4px;
                margin-right: 8px;
                text-transform: uppercase;
                letter-spacing: 0.3px;
            }

            .method-get { background: #34c759; color: #fff; }
            .method-post { background: #ff9500; color: #fff; }
            .method-put { background: #007aff; color: #fff; }
            .method-patch { background: #af52de; color: #fff; }
            .method-delete { background: #ff3b30; color: #fff; }

            .nav-list .api-name {
                font-size: 14px;
                font-weight: 500;
            }

            .content {
                flex: 1;
                margin-left: 320px;
                padding: 32px 48px;
                max-width: 1200px;
                min-height: 100vh;
            }

            .api-section {
                display: none;
                animation: fadeIn 0.2s ease;
            }

            .api-section.active {
                display: block;
            }

            @keyframes fadeIn {
                from { opacity: 0; transform: translateY(10px); }
                to { opacity: 1; transform: translateY(0); }
            }

            .api-header {
                margin-bottom: 32px;
                padding-bottom: 24px;
                border-bottom: 2px solid #0071e3;
            }

            .api-header h2 {
                font-size: 28px;
                font-weight: 700;
                margin: 0 0 16px 0;
                color: #1d1d1f;
                letter-spacing: -0.5px;
            }

            .api-url {
                display: flex;
                align-items: center;
                gap: 12px;
                padding: 14px 18px;
                background: #f5f5f7;
                border-radius: 10px;
                border: 1px solid #d2d2d7;
            }

            .api-url .method {
                font-size: 14px;
                font-weight: 700;
                padding: 4px 10px;
                border-radius: 6px;
                text-transform: uppercase;
                letter-spacing: 0.5px;
            }

            .api-url .url {
                font-family: "SF Mono", SFMono-Regular, Menlo, Monaco, Consolas, monospace;
                font-size: 14px;
                color: #1d1d1f;
                word-break: break-all;
            }

            .api-description {
                margin-top: 16px;
                font-size: 15px;
                color: #6e6e73;
                line-height: 1.6;
            }

            .api-auth {
                margin-top: 12px;
                font-size: 13px;
                color: #86868b;
            }

            .api-auth strong {
                color: #1d1d1f;
            }

            h1 {
                font-size: 34px;
                font-weight: 700;
                margin-bottom: 12px;
                color: #1d1d1f;
                letter-spacing: -0.5px;
            }

            h2 {
                font-size: 20px;
                font-weight: 600;
                margin-top: 32px;
                margin-bottom: 16px;
                color: #1d1d1f;
                letter-spacing: -0.3px;
            }

            h3 {
                font-size: 16px;
                font-weight: 600;
                margin-top: 24px;
                margin-bottom: 12px;
                color: #1d1d1f;
            }

            code {
                background: #f5f5f7;
                padding: 3px 7px;
                border-radius: 5px;
                font-family: "SF Mono", SFMono-Regular, Menlo, Monaco, Consolas, monospace;
                font-size: 13px;
                color: #1d1d1f;
                word-break: break-all;
            }

            pre {
                background: #1d1d1f;
                color: #f5f5f7;
                padding: 20px 24px;
                border-radius: 10px;
                overflow-x: auto;
                margin: 16px 0;
                font-size: 13px;
                line-height: 1.6;
                white-space: pre-wrap;
                word-break: break-all;
            }

            pre code {
                background: none;
                color: inherit;
                padding: 0;
                font-size: inherit;
                word-break: break-all;
            }

            table {
                width: 100%;
                border-collapse: separate;
                border-spacing: 0;
                margin: 16px 0;
                border-radius: 10px;
                overflow: hidden;
                border: 1px solid #d2d2d7;
                background: #fff;
                table-layout: fixed;
            }

            th, td {
                padding: 12px 16px;
                text-align: left;
                border-bottom: 1px solid #d2d2d7;
                word-break: break-all;
            }

            th {
                background: #f5f5f7;
                font-weight: 600;
                font-size: 13px;
                color: #6e6e73;
                text-transform: uppercase;
                letter-spacing: 0.5px;
            }

            td {
                font-size: 14px;
            }

            tr:last-child td {
                border-bottom: none;
            }

            tr:hover {
                background: #f5f5f7;
            }

            hr {
                border: none;
                border-top: 1px solid #d2d2d7;
                margin: 24px 0;
            }

            blockquote {
                border-left: 4px solid #0071e3;
                padding: 16px 24px;
                margin: 16px 0;
                background: #f5f5f7;
                border-radius: 0 8px 8px 0;
                color: #6e6e73;
                font-size: 15px;
            }

            .api-card {
                background: #fff;
                border-radius: 12px;
                border: 1px solid #d2d2d7;
                padding: 24px;
                margin-bottom: 24px;
            }

            .empty-state {
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                min-height: 60vh;
                color: #86868b;
                text-align: center;
            }

            .empty-state svg {
                width: 64px;
                height: 64px;
                margin-bottom: 16px;
                opacity: 0.5;
            }

            .empty-state h3 {
                font-size: 18px;
                font-weight: 600;
                margin-bottom: 8px;
                color: #6e6e73;
            }

            .empty-state p {
                font-size: 14px;
            }

            @media (max-width: 1024px) {
                .content {
                    padding: 24px 32px;
                }
            }

            @media (max-width: 768px) {
                .sidebar {
                    display: none;
                }

                .content {
                    margin-left: 0;
                    padding: 24px 20px;
                }

                h1 {
                    font-size: 28px;
                }

                h2 {
                    font-size: 20px;
                }
            }

            @media (prefers-color-scheme: dark) {
                body {
                    color: #f5f5f7;
                    background-color: #000000;
                }

                .sidebar {
                    background: #1c1c1e;
                    border-right-color: #38383a;
                }

                .sidebar-header {
                    background: #1c1c1e;
                    border-bottom-color: #38383a;
                }

                .back-link {
                    color: #0a84ff;
                }

                .sidebar-title {
                    color: #f5f5f7;
                }

                .sidebar::-webkit-scrollbar-thumb {
                    background: #48484a;
                }

                .search-box input {
                    background: #2c2c2e;
                    border-color: #48484a;
                    color: #f5f5f7;
                }

                .search-box input:focus {
                    border-color: #0a84ff;
                    background: #2c2c2e;
                    box-shadow: 0 0 0 3px rgba(10, 132, 255, 0.2);
                }

                .search-box input::placeholder {
                    color: #98989d;
                }

                .nav-list a {
                    color: #f5f5f7;
                }

                .nav-list a:hover {
                    background: #2c2c2e;
                    color: #0a84ff;
                }

                .nav-list a.active {
                    background: #0a84ff;
                    border-color: #0a84ff;
                }

                .api-url {
                    background: #2c2c2e;
                    border-color: #48484a;
                }

                .api-url .url {
                    color: #f5f5f7;
                }

                h1, h2, h3 {
                    color: #f5f5f7;
                }

                code {
                    background: #2c2c2e;
                    color: #f5f5f7;
                }

                pre {
                    background: #1c1c1e;
                    color: #f5f5f7;
                    white-space: pre-wrap;
                    word-break: break-all;
                }

                table {
                    background: #1c1c1e;
                    border-color: #48484a;
                }

                th, td {
                    border-bottom-color: #38383a;
                }

                th {
                    background: #2c2c2e;
                    color: #98989d;
                }

                tr:hover {
                    background: #2c2c2e;
                }

                hr {
                    border-top-color: #38383a;
                }

                blockquote {
                    border-left-color: #0a84ff;
                    background: #1c1c1e;
                    color: #98989d;
                }

                .api-card {
                    background: #1c1c1e;
                    border-color: #48484a;
                }
            }
        </style>
        """
    }
    
    /// JavaScript
    private var javascript: String {
        """
        <script>
            // 初始化：显示第一个接口
            document.addEventListener('DOMContentLoaded', function() {
                const firstLink = document.querySelector('.nav-list a');
                if (firstLink) {
                    showAPI(firstLink.getAttribute('href').substring(1));
                }
            });

            function filterAPIs() {
                const input = document.getElementById('searchInput');
                const filter = input.value.toLowerCase();
                const navItems = document.querySelectorAll('#navList li');

                navItems.forEach(item => {
                    const text = item.textContent.toLowerCase();
                    item.style.display = text.includes(filter) ? '' : 'none';
                });
            }

            function showAPI(sectionId) {
                // 隐藏所有接口区域
                document.querySelectorAll('.api-section').forEach(section => {
                    section.classList.remove('active');
                });

                // 显示选中的接口区域
                const targetSection = document.getElementById(sectionId);
                if (targetSection) {
                    targetSection.classList.add('active');
                }

                // 更新导航选中状态
                document.querySelectorAll('.nav-list a').forEach(link => {
                    link.classList.remove('active');
                    if (link.getAttribute('href') === '#' + sectionId) {
                        link.classList.add('active');
                    }
                });

                // 滚动到顶部
                document.getElementById('contentArea').scrollTop = 0;
            }

            // 拦截导航链接点击
            document.querySelectorAll('.nav-list a').forEach(link => {
                link.addEventListener('click', function(e) {
                    e.preventDefault();
                    const sectionId = this.getAttribute('href').substring(1);
                    showAPI(sectionId);
                });
            });
        </script>
        """
    }
}
