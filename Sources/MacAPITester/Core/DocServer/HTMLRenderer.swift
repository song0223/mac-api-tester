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
