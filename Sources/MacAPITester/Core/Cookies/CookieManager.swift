import Foundation

final class CookieManager {
    private(set) var cookieJar: CookieJar
    private let storage: CookieStorage
    
    init(storage: CookieStorage) {
        self.storage = storage
        self.cookieJar = (try? storage.loadCookies()) ?? CookieJar()
    }
    
    func cookies(for request: URLRequest) -> [HTTPCookie] {
        guard let url = request.url,
              let host = url.host else {
            return []
        }
        
        return cookieJar.cookies(for: host, path: url.path)
    }
    
    func addCookies(from response: HTTPURLResponse, request: URLRequest) {
        guard let url = request.url,
              let host = url.host else {
            return
        }
        
        let headerFields = response.allHeaderFields as? [String: String] ?? [:]
        let foundationCookies = Foundation.HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        
        for cookie in foundationCookies {
            let httpCookie = HTTPCookie(
                domain: cookie.domain,
                path: cookie.path,
                name: cookie.name,
                value: cookie.value,
                expiresDate: cookie.expiresDate,
                isSecure: cookie.isSecure,
                isHTTPOnly: cookie.isHTTPOnly,
                sameSite: .lax
            )
            cookieJar.addCookie(httpCookie)
        }
        
        saveCookies()
    }
    
    func addCookie(_ cookie: HTTPCookie) {
        cookieJar.addCookie(cookie)
        saveCookies()
    }
    
    func removeCookie(id: UUID) {
        cookieJar.removeCookie(id: id)
        saveCookies()
    }
    
    func clearCookies() {
        cookieJar = CookieJar()
        saveCookies()
    }
    
    func removeExpiredCookies() {
        cookieJar.removeExpiredCookies()
        saveCookies()
    }
    
    func applyCookies(to request: inout URLRequest) {
        let cookies = cookies(for: request)
        guard !cookies.isEmpty else { return }
        
        var headers = request.allHTTPHeaderFields ?? [:]
        let cookieString = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        headers["Cookie"] = cookieString
        request.allHTTPHeaderFields = headers
    }
    
    func exportCookies() throws -> Data {
        try storage.exportCookies(cookieJar)
    }
    
    func importCookies(from data: Data) throws {
        cookieJar = try storage.importCookies(from: data)
        saveCookies()
    }
    
    private func saveCookies() {
        try? storage.saveCookies(cookieJar)
    }
}
