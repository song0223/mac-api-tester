import Foundation

struct HTTPClientResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
    let duration: TimeInterval
}

struct HTTPClient {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        // 不使用系统代理
        config.connectionProxyDictionary = [:]
        // 增加超时时间
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        print("🔧 URLSession 配置: proxy=\(config.connectionProxyDictionary ?? [:])")
    }

    func send(_ request: URLRequest) async throws -> HTTPClientResponse {
        let start = Date()

        print("📤 发送请求: \(request.url?.absoluteString ?? "nil")")
        print("📤 请求头: \(request.allHTTPHeaderFields ?? [:])")

        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(start)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 响应不是 HTTPURLResponse")
                throw AppRequestError.badResponse
            }

            print("✅ 收到响应: \(httpResponse.statusCode), 数据大小: \(data.count) bytes")
            return HTTPClientResponse(
                statusCode: httpResponse.statusCode,
                headers: parsedHeaders(from: httpResponse),
                body: data,
                duration: duration
            )
        } catch {
            print("❌ 请求失败: \(error)")
            throw error
        }
    }

    private func parsedHeaders(from response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            headers[String(describing: key)] = String(describing: value)
        }
        return headers
    }
}
