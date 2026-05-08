import Foundation

struct CurlParseResult {
    let method: HTTPMethod
    let url: String
    let headers: [String: String]
    let body: String?
}

enum CurlError: Error, LocalizedError {
    case invalidCommand
    case urlNotFound

    var errorDescription: String? {
        switch self {
        case .invalidCommand:
            return "无效的 cURL 命令格式"
        case .urlNotFound:
            return "未找到 URL"
        }
    }
}

final class CurlParser {
    func parse(_ curlCommand: String) throws -> CurlParseResult {
        let tokens = tokenize(curlCommand)
        guard !tokens.isEmpty else {
            throw CurlError.invalidCommand
        }

        var method: HTTPMethod = .get
        var url: String = ""
        var headers: [String: String] = [:]
        var body: String?

        var i = 0
        while i < tokens.count {
            let token = tokens[i]

            if token == "-X" || token == "--request" {
                i += 1
                guard i < tokens.count else { break }
                let methodString = tokens[i].uppercased()
                if let parsed = HTTPMethod(rawValue: methodString) {
                    method = parsed
                }
            } else if token == "-H" || token == "--header" {
                i += 1
                guard i < tokens.count else { break }
                let headerString = tokens[i]
                if let colonIndex = headerString.firstIndex(of: ":") {
                    let key = String(headerString[headerString.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(headerString[headerString.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    headers[key] = value
                }
            } else if token == "-d" || token == "--data" || token == "--data-raw" || token == "--data-binary" {
                i += 1
                guard i < tokens.count else { break }
                body = tokens[i]
                if method == .get {
                    method = .post
                }
            } else if token == "--url" {
                i += 1
                guard i < tokens.count else { break }
                url = tokens[i]
            } else if !token.hasPrefix("-") && url.isEmpty {
                url = token
            }

            i += 1
        }

        guard !url.isEmpty else {
            throw CurlError.urlNotFound
        }

        return CurlParseResult(method: method, url: url, headers: headers, body: body)
    }

    private func tokenize(_ command: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var escapeNext = false

        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove "curl" prefix if present
        let curlPrefix = "curl "
        let input: String
        if trimmed.lowercased().hasPrefix(curlPrefix) {
            input = String(trimmed.dropFirst(curlPrefix.count)).trimmingCharacters(in: .whitespaces)
        } else {
            input = trimmed
        }

        for char in input {
            if escapeNext {
                currentToken.append(char)
                escapeNext = false
                continue
            }

            if char == "\\" && !inSingleQuote {
                escapeNext = true
                continue
            }

            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                continue
            }

            if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                continue
            }

            if char.isWhitespace && !inSingleQuote && !inDoubleQuote {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                continue
            }

            currentToken.append(char)
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }
}

final class CurlExporter {
    func export(_ document: RequestDocument) -> String {
        var parts: [String] = ["curl"]

        // Method
        if document.method != .get {
            parts.append("-X \(document.method.rawValue)")
        }

        // URL
        let url = document.urlString
        if url.contains(" ") {
            parts.append("'\(url)'")
        } else {
            parts.append(url)
        }

        // Headers
        let headers = parseHeaders(document.headersText)
        for (key, value) in headers {
            parts.append("-H '\(key): \(value)'")
        }

        // Body
        let body = document.bodyText
        if !body.isEmpty {
            if body.contains("'") {
                parts.append("--data-raw \"\(body)\"")
            } else {
                parts.append("--data-raw '\(body)'")
            }
        }

        return parts.joined(separator: " \\\n  ")
    }

    private func parseHeaders(_ text: String) -> [(String, String)] {
        var headers: [(String, String)] = []
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    headers.append((key, value))
                }
            }
        }
        return headers
    }
}
