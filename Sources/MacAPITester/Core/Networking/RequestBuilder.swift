import Foundation

struct RequestBuilder {
    private let baseURL: URL
    private let templateRenderer: TemplateRenderer
    private let authInjector: AuthInjector

    init(
        baseURL: URL,
        templateRenderer: TemplateRenderer = TemplateRenderer(),
        authInjector: AuthInjector = AuthInjector()
    ) {
        self.baseURL = baseURL
        self.templateRenderer = templateRenderer
        self.authInjector = authInjector
    }

    func build(_ draft: APIRequestDraft) throws -> URLRequest {
        let renderedPath = try render(draft.path, variables: draft.variables)
        let renderedQuery = try renderQuery(from: draft, variables: draft.variables)
        let renderedHeaders = try renderHeaders(draft.headers, variables: draft.variables)

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        guard components != nil else {
            throw AppRequestError.invalidURL(baseURL.absoluteString)
        }

        components?.path = joinedPath(basePath: baseURL.path, renderedPath: renderedPath)
        components?.queryItems = renderedQuery

        guard let url = components?.url else {
            throw AppRequestError.invalidURL(components?.string ?? baseURL.absoluteString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = draft.method.rawValue

        let headers = draft.bearerToken.map {
            authInjector.injectBearerToken(into: renderedHeaders, token: $0)
        } ?? renderedHeaders
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        if let body = draft.body {
            let renderedBody = try render(body, variables: draft.variables)
            request.httpBody = renderedBody.data(using: .utf8)
        }

        return request
    }

    private func render(_ template: String, variables: [String: String]) throws -> String {
        do {
            return try templateRenderer.render(template, variables: variables)
        } catch let error as TemplateRendererError {
            throw AppRequestError.template(error)
        }
    }

    private func renderQuery(
        from draft: APIRequestDraft,
        variables: [String: String]
    ) throws -> [URLQueryItem] {
        if let queryItems = draft.queryItems {
            return try queryItems.map { item in
                URLQueryItem(
                    name: try render(item.name, variables: variables),
                    value: try item.value.map { try render($0, variables: variables) }
                )
            }
        }

        return try draft.query
            .sorted(by: { $0.key < $1.key })
            .map { key, value in
                URLQueryItem(
                    name: try render(key, variables: variables),
                    value: try render(value, variables: variables)
                )
            }
    }

    private func renderHeaders(
        _ headers: [String: String],
        variables: [String: String]
    ) throws -> [String: String] {
        var rendered: [String: String] = [:]
        rendered.reserveCapacity(headers.count)
        for (name, value) in headers {
            rendered[try render(name, variables: variables)] = try render(value, variables: variables)
        }
        return rendered
    }

    private func joinedPath(basePath: String, renderedPath: String) -> String {
        let normalizedBase = basePath == "/" ? "" : basePath
        let normalizedRendered = renderedPath.hasPrefix("/") ? String(renderedPath.dropFirst()) : renderedPath

        guard !normalizedBase.isEmpty else {
            return "/" + normalizedRendered
        }

        if normalizedBase.hasSuffix("/") {
            return normalizedBase + normalizedRendered
        }

        return normalizedBase + "/" + normalizedRendered
    }
}
