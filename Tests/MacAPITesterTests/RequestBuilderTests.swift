import Foundation
import Testing
@testable import MacAPITester

@Suite("Request Builder Tests")
struct RequestBuilderTests {
    @Test func buildsPostRequestWithRenderedQueryItems() throws {
        let builder = RequestBuilder(baseURL: URL(string: "https://api.example.com")!)
        let draft = APIRequestDraft(
            method: .post,
            path: "/v1/users/{{userId}}",
            query: [
                "locale": "{{locale}}",
                "sort": "desc",
            ],
            headers: [:],
            body: nil,
            variables: [
                "userId": "42",
                "locale": "zh-CN",
            ]
        )

        let request = try builder.build(draft)

        #expect(request.httpMethod == "POST")

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        #expect(components.path == "/v1/users/42")
        #expect(components.queryItems?.sorted(by: { $0.name < $1.name }) == [
            URLQueryItem(name: "locale", value: "zh-CN"),
            URLQueryItem(name: "sort", value: "desc"),
        ])
    }

    @Test func buildsHeadersAndInjectsAuthorization() throws {
        let builder = RequestBuilder(baseURL: URL(string: "https://api.example.com")!)
        let draft = APIRequestDraft(
            method: .post,
            path: "/v1/messages",
            query: [:],
            headers: [
                "Content-Type": "application/json",
                "X-Trace-ID": "{{traceId}}",
                "authorization": "Bearer old-token",
            ],
            body: nil,
            variables: [
                "traceId": "trace-123",
            ],
            bearerToken: "abc123"
        )

        let request = try builder.build(draft)

        let headers = request.allHTTPHeaderFields ?? [:]

        #expect(headers["Content-Type"] == "application/json")
        #expect(headers["X-Trace-ID"] == "trace-123")
        #expect(headers["Authorization"] == "Bearer abc123")
        #expect(headers["authorization"] == nil)
    }

    @Test func buildsRenderedBodyForPostRequests() throws {
        let builder = RequestBuilder(baseURL: URL(string: "https://api.example.com")!)
        let draft = APIRequestDraft(
            method: .post,
            path: "/v1/messages",
            query: [:],
            headers: [
                "Content-Type": "application/json",
            ],
            body: #"{"title":"{{title}}","published":true}"#,
            variables: [
                "title": "Hello",
            ]
        )

        let request = try builder.build(draft)
        let body = request.httpBody!
        let bodyString = String(data: body, encoding: .utf8)!

        #expect(bodyString == #"{"title":"Hello","published":true}"#)
    }

    @Test func preservesDuplicateQueryItemsAndOrderWhenProvidedExplicitly() throws {
        let builder = RequestBuilder(baseURL: URL(string: "https://api.example.com")!)
        let draft = APIRequestDraft(
            method: .get,
            path: "/v1/search",
            query: [:],
            queryItems: [
                URLQueryItem(name: "tag", value: "{{first}}"),
                URLQueryItem(name: "tag", value: "{{second}}"),
                URLQueryItem(name: "sort", value: "recent"),
            ],
            headers: [:],
            body: nil,
            variables: [
                "first": "swift",
                "second": "ui",
            ],
            bearerToken: nil
        )

        let request = try builder.build(draft)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!

        #expect(components.queryItems == [
            URLQueryItem(name: "tag", value: "swift"),
            URLQueryItem(name: "tag", value: "ui"),
            URLQueryItem(name: "sort", value: "recent"),
        ])
    }
}
