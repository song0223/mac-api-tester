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
    
    /// Markdown 转 HTML
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var htmlLines: [String] = []
        var inCodeBlock = false
        var codeContent = ""
        var inTable = false
        var tableRows: [String] = []
        var inList = false
        var listItems: [String] = []

        for line in lines {
            // Code block
            if line.hasPrefix("```") {
                if inCodeBlock {
                    htmlLines.append("<pre><code>\(codeContent)</code></pre>")
                    codeContent = ""
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeContent += line + "\n"
                continue
            }

            // Table
            if line.contains("|") && line.contains("---") {
                continue // Skip separator
            }

            if line.contains("|") && line.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                if !inTable {
                    inTable = true
                    tableRows = []
                }

                let cells = line.split(separator: "|")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                if tableRows.isEmpty {
                    let header = cells.map { "<th>\($0)</th>" }.joined()
                    tableRows.append("<thead><tr>\(header)</tr></thead>")
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
                htmlLines.append("<h2>\(formatInline(String(line.dropFirst(3))))</h2>")
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
            htmlLines.append("<pre><code>\(codeContent)</code></pre>")
        }

        return htmlLines.joined(separator: "\n")
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
            
            @media (prefers-color-scheme: dark) {
                body {
                    color: #e0e0e0;
                    background-color: #1a1a1a;
                }
                
                .sidebar {
                    background: #242424;
                    border-right-color: #404040;
                }
                
                .search-box input {
                    background: #2a2a2a;
                    border-color: #404040;
                    color: #e0e0e0;
                }
                
                .nav-list a {
                    color: #6db3f2;
                }
                
                h1 {
                    color: #f0f0f0;
                }
                
                h2 {
                    color: #e0e0e0;
                    border-bottom-color: #6db3f2;
                }
                
                h3 {
                    color: #d0d0d0;
                }
                
                code {
                    background: #2a2a2a;
                    color: #e0e0e0;
                }
                
                pre {
                    background: #1e1e1e;
                    color: #d4d4d4;
                }
                
                pre code {
                    background: none;
                    color: inherit;
                }
                
                th, td {
                    border-color: #404040;
                }
                
                th {
                    background: #2a2a2a;
                }
                
                tr:nth-child(even) {
                    background: #222222;
                }
                
                hr {
                    border-top-color: #404040;
                }
                
                blockquote {
                    border-left-color: #6db3f2;
                    background: #242424;
                    color: #b0b0b0;
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
