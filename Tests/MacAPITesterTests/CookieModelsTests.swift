import Foundation
import Testing
@testable import MacAPITester

@Suite("Cookie Models Tests")
struct CookieModelsTests {
    @Test func cookieMatchesDomainAndPath() {
        let cookie = HTTPCookie(domain: ".example.com", path: "/api", name: "session", value: "123")
        #expect(cookie.matches(domain: "api.example.com", path: "/api/users"))
        #expect(!cookie.matches(domain: "other.com", path: "/api"))
    }
    
    @Test func cookieExpirationCheck() {
        let expiredCookie = HTTPCookie(
            domain: ".example.com",
            name: "expired",
            value: "123",
            expiresDate: Date().addingTimeInterval(-3600)
        )
        #expect(expiredCookie.isExpired)
        
        let validCookie = HTTPCookie(
            domain: ".example.com",
            name: "valid",
            value: "123",
            expiresDate: Date().addingTimeInterval(3600)
        )
        #expect(!validCookie.isExpired)
    }
    
    @Test func cookieJarAddCookieRemovesDuplicates() {
        var jar = CookieJar()
        let cookie1 = HTTPCookie(domain: ".example.com", name: "session", value: "123")
        let cookie2 = HTTPCookie(domain: ".example.com", name: "session", value: "456")
        
        jar.addCookie(cookie1)
        jar.addCookie(cookie2)
        
        #expect(jar.cookies.count == 1)
        #expect(jar.cookies.first?.value == "456")
    }
}