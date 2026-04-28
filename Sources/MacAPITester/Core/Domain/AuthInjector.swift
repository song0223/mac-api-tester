struct AuthInjector {
    func injectBearerToken(into headers: [String: String], token: String) -> [String: String] {
        var headers = headers

        for key in headers.keys where key.lowercased() == "authorization" {
            headers.removeValue(forKey: key)
        }

        headers["Authorization"] = "Bearer \(token)"
        return headers
    }
}
