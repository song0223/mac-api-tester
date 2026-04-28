import Foundation

enum DocGenerator {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func buildDocModel(project: RequestProject, requests: [RequestDocument]) -> APIDocModel {
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

    private static func buildSection(from request: RequestDocument) -> APIDocSection {
        let queryParams = parseLines(from: request.queryText, separator: "=")
        let headers = parseLines(from: request.headersText, separator: ":")
        let bodyParams: [ParamInfo]
        if isJSONBody(request.bodyText) {
            bodyParams = []
        } else {
            bodyParams = parseLines(from: request.bodyText, separator: "=")
        }

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

    private static func isJSONBody(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
    }

    private static func parseLines(from text: String, separator: Character) -> [ParamInfo] {
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

    private static func parseVariables(from text: String) -> [String: String] {
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

    static func renderMarkdown(_ model: APIDocModel) -> String {
        var lines: [String] = []

        lines.append("# API文档 - \(model.projectName)")
        lines.append("")
        lines.append("> 生成时间：\(dateFormatter.string(from: model.generatedAt))")
        lines.append("")
        lines.append("## 目录")
        lines.append("")

        for section in model.sections {
            lines.append("- [\(section.name)](#\(section.id))")
        }

        lines.append("")
        lines.append("---")
        lines.append("")

        for section in model.sections {
            lines.append(renderSection(section))
            lines.append("---")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func renderSection(_ section: APIDocSection) -> String {
        var lines: [String] = []

        lines.append("## \(section.name)")
        lines.append("")
        lines.append("**URL:** `\(section.method) \(section.url)`")
        lines.append("")

        if !section.description.isEmpty {
            lines.append("**描述:** \(section.description)")
            lines.append("")
        }

        lines.append("**认证:** \(section.authType)")
        lines.append("")

        if !section.queryParams.isEmpty {
            lines.append("### 请求参数")
            lines.append("")
            lines.append("| 参数名 | 类型 | 必填 | 描述 |")
            lines.append("|--------|------|------|------|")
            for param in section.queryParams {
                lines.append("| \(param.name) | \(param.type) | \(param.required ? "是" : "否") | \(param.description) |")
            }
            lines.append("")
        }

        if !section.headers.isEmpty {
            lines.append("### 请求头")
            lines.append("")
            lines.append("| Header | 值 |")
            lines.append("|--------|-----|")
            for header in section.headers {
                lines.append("| \(header.name) | \(header.description) |")
            }
            lines.append("")
        }

        if let body = section.requestBody, !body.isEmpty {
            lines.append("### 请求示例")
            lines.append("")
            lines.append("```json")
            lines.append(body)
            lines.append("```")
            lines.append("")
        }

        if let response = section.responseBody, !response.isEmpty {
            lines.append("### 响应示例")
            lines.append("")
            lines.append("```json")
            lines.append(response)
            lines.append("```")
            lines.append("")
        }

        if !section.variables.isEmpty {
            lines.append("### 环境变量")
            lines.append("")
            lines.append("| 变量名 | 示例值 |")
            lines.append("|--------|--------|")
            for (key, value) in section.variables {
                lines.append("| \(key) | \(value) |")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
