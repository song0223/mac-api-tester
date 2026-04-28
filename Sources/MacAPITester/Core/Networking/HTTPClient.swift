import Foundation

struct HTTPClientResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
    let duration: TimeInterval
}

struct HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> HTTPClientResponse {
        let start = Date()

        do {
            let (data, response) = try await perform(request)
            let duration = Date().timeIntervalSince(start)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppRequestError.badResponse
            }

            return HTTPClientResponse(
                statusCode: httpResponse.statusCode,
                headers: parsedHeaders(from: httpResponse),
                body: data,
                duration: duration
            )
        } catch let error as URLError {
            throw map(error)
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data, let response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }

                continuation.resume(returning: (data, response))
            }

            task.resume()
        }
    }

    private func map(_ error: URLError) -> AppRequestError {
        switch error.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost:
            return .offline
        case .secureConnectionFailed,
            .serverCertificateUntrusted,
            .serverCertificateHasBadDate,
            .serverCertificateHasUnknownRoot,
            .serverCertificateNotYetValid,
            .clientCertificateRejected,
            .clientCertificateRequired:
            return .tls
        default:
            return .badResponse
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
