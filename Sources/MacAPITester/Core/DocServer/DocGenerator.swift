import Foundation

final class DocGenerator {

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

    func renderMarkdown(_ model: APIDocModel) -> String {
        var markdown = """
        # API文档 - \(model.projectName)

        > 生成时间：\(formatDate(model.generatedAt))

        ## 目录

        """

        for section in model.sections {
            markdown += "- [\(section.name)](#\(section.id))\n"
        }

        markdown += "\n---\n\n"

        for section in model.sections {
            markdown += renderSection(section)
            markdown += "\n---\n\n"
        }

        return markdown
    }

    private func renderSection(_ section: APIDocSection) -> String {
        var markdown = """
        ## \(section.name)

        **URL:** `\(section.method) \(section.url)`

        """

        if !section.description.isEmpty {
            markdown += "**描述:** \(section.description)\n\n"
        }

        markdown += "**认证:** \(section.authType)\n\n"

        if !section.queryParams.isEmpty {
            markdown += "### 请求参数\n\n"
            markdown += "| 参数名 | 类型 | 必填 | 描述 |\n"
            markdown += "|--------|------|------|------|\n"
            for param in section.queryParams {
                markdown += "| \(param.name) | \(param.type) | \(param.required ? "是" : "否") | \(param.description) |\n"
            }
            markdown += "\n"
        }

        if !section.headers.isEmpty {
            markdown += "### 请求头\n\n"
            markdown += "| Header | 值 |\n"
            markdown += "|--------|-----|\n"
            for header in section.headers {
                markdown += "| \(header.name) | \(header.description) |\n"
            }
            markdown += "\n"
        }

        if let body = section.requestBody, !body.isEmpty {
            markdown += "### 请求示例\n\n"
            markdown += "```json\n\(body)\n```\n\n"
        }

        if let response = section.responseBody, !response.isEmpty {
            markdown += "### 响应示例\n\n"
            markdown += "```json\n\(response)\n```\n\n"
        }

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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
