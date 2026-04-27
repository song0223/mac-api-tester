import Foundation

struct HTTPCookie: Identifiable, Equatable, Codable {
    let id: UUID
    var domain: String
    var path: String
    var name: String
    var value: String
    var expiresDate: Date?
    var isSecure: Bool
    var isHTTPOnly: Bool
    var sameSite: SameSitePolicy
    
    enum SameSitePolicy: String, Codable, CaseIterable {
        case lax = "Lax"
        case strict = "Strict"
        case none = "None"
    }
    
    init(
        id: UUID = UUID(),
        domain: String,
        path: String = "/",
        name: String,
        value: String,
        expiresDate: Date? = nil,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        sameSite: SameSitePolicy = .lax
    ) {
        self.id = id
        self.domain = domain
        self.path = path
        self.name = name
        self.value = value
        self.expiresDate = expiresDate
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.sameSite = sameSite
    }
    
    var isExpired: Bool {
        guard let expiresDate else { return false }
        return Date() > expiresDate
    }
    
    func matches(domain: String, path: String) -> Bool {
        let domainMatch: Bool
        if self.domain.hasPrefix(".") {
            // Domain starts with dot: matches base domain and subdomains
            domainMatch = domain == String(self.domain.dropFirst()) || domain.hasSuffix(self.domain)
        } else {
            // No leading dot: exact match only
            domainMatch = domain == self.domain
        }
        
        let pathMatch: Bool
        if self.path == "/" {
            pathMatch = true
        } else {
            pathMatch = path == self.path || path.hasPrefix(self.path + "/")
        }
        return domainMatch && pathMatch
    }
}

struct CookieJar: Codable {
    var cookies: [HTTPCookie]
    
    init(cookies: [HTTPCookie] = []) {
        self.cookies = cookies
    }
    
    mutating func addCookie(_ cookie: HTTPCookie) {
        // 移除已存在的同名Cookie
        cookies.removeAll { $0.domain == cookie.domain && $0.path == cookie.path && $0.name == cookie.name }
        cookies.append(cookie)
    }
    
    mutating func removeCookie(id: UUID) {
        cookies.removeAll { $0.id == id }
    }
    
    mutating func removeExpiredCookies() {
        cookies.removeAll { $0.isExpired }
    }
    
    func cookies(for domain: String, path: String) -> [HTTPCookie] {
        cookies.filter { $0.matches(domain: domain, path: path) && !$0.isExpired }
    }
}
