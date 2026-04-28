import Foundation
import Testing
@testable import MacAPITester

@Suite("HTTP Client Tests", .serialized)
struct HTTPClientTests {
    @Test func sendReturnsStatusBodyAndDuration() async throws {
        let token = UUID()
        let session = makeSession(token: token) { request in
            #expect(request.url?.absoluteString == "https://api.example.com/v1/ping")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/plain"]
            )!

            return .success(
                response: response,
                data: Data("pong".utf8),
                delay: 0.03
            )
        }

        let client = HTTPClient(session: session)
        let request = makeRequest(token: token, url: "https://api.example.com/v1/ping")

        let response = try await client.send(request)

        #expect(response.statusCode == 201)
        #expect(String(data: response.body, encoding: .utf8) == "pong")
        #expect(response.duration >= 0.03)
    }

    @Test func sendMapsTimeoutErrorsToAppRequestError() async throws {
        let token = UUID()
        let session = makeSession(token: token) { _ in
            .failure(URLError(.timedOut))
        }

        let client = HTTPClient(session: session)

        await #expect(throws: AppRequestError.timeout) {
            _ = try await client.send(makeRequest(token: token, url: "https://api.example.com/v1/ping"))
        }
    }

    @Test func sendMapsOfflineErrorsToAppRequestError() async throws {
        let token = UUID()
        let session = makeSession(token: token) { _ in
            .failure(URLError(.notConnectedToInternet))
        }

        let client = HTTPClient(session: session)

        await #expect(throws: AppRequestError.offline) {
            _ = try await client.send(makeRequest(token: token, url: "https://api.example.com/v1/ping"))
        }
    }

    @Test func sendMapsTlsErrorsToAppRequestError() async throws {
        let token = UUID()
        let session = makeSession(token: token) { _ in
            .failure(URLError(.secureConnectionFailed))
        }

        let client = HTTPClient(session: session)

        await #expect(throws: AppRequestError.tls) {
            _ = try await client.send(makeRequest(token: token, url: "https://api.example.com/v1/ping"))
        }
    }

    @Test func sendMapsBadResponseToAppRequestError() async throws {
        let token = UUID()
        let session = makeSession(token: token) { _ in
            .success(
                response: URLResponse(url: URL(string: "https://api.example.com/v1/ping")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil),
                data: Data(),
                delay: 0
            )
        }

        let client = HTTPClient(session: session)

        await #expect(throws: AppRequestError.badResponse) {
            _ = try await client.send(makeRequest(token: token, url: "https://api.example.com/v1/ping"))
        }
    }

    private func makeSession(
        token: UUID,
        handler: @escaping (URLRequest) -> StubURLProtocol.Action
    ) -> URLSession {
        StubURLProtocol.register(handler: handler, for: token)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeRequest(token: UUID, url: String) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.setValue(token.uuidString, forHTTPHeaderField: StubURLProtocol.tokenHeaderName)
        return request
    }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    enum Action {
        case success(response: URLResponse, data: Data, delay: TimeInterval)
        case failure(Error)
    }

    static let tokenHeaderName = "X-Stub-Token"
    private static let store = HandlerStore()

    static func register(handler: @escaping (URLRequest) -> Action, for token: UUID) {
        store.register(handler: handler, for: token)
    }

    private static func handler(for token: UUID) -> ((URLRequest) -> Action)? {
        store.handler(for: token)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let tokenString = request.value(forHTTPHeaderField: Self.tokenHeaderName),
            let token = UUID(uuidString: tokenString),
            let action = Self.handler(for: token)?(request)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        switch action {
        case let .success(response, data, delay):
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
                self.client?.urlProtocolDidFinishLoading(self)
            }
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class HandlerStore: @unchecked Sendable {
    private var handlers: [UUID: (URLRequest) -> StubURLProtocol.Action] = [:]
    private let lock = NSLock()

    func register(handler: @escaping (URLRequest) -> StubURLProtocol.Action, for token: UUID) {
        lock.lock()
        handlers[token] = handler
        lock.unlock()
    }

    func handler(for token: UUID) -> ((URLRequest) -> StubURLProtocol.Action)? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[token]
    }
}
