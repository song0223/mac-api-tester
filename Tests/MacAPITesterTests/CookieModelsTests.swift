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
    
    @Test func domainMatchingEdgeCases() {
        // Cookie with leading dot should match base domain and subdomains
        let cookie = HTTPCookie(domain: ".example.com", path: "/", name: "test", value: "123")
        #expect(cookie.matches(domain: "example.com", path: "/"))
        #expect(cookie.matches(domain: "api.example.com", path: "/"))
        #expect(!cookie.matches(domain: "notexample.com", path: "/"))
        
        // Cookie without leading dot should match exactly
        let exactCookie = HTTPCookie(domain: "example.com", path: "/", name: "test", value: "123")
        #expect(exactCookie.matches(domain: "example.com", path: "/"))
        #expect(!exactCookie.matches(domain: "api.example.com", path: "/"))
        #expect(!exactCookie.matches(domain: "notexample.com", path: "/"))
    }
    
    @Test func pathMatchingEdgeCases() {
        // Cookie with path "/api" should match "/api" and "/api/users" but not "/apiary"
        let cookie = HTTPCookie(domain: ".example.com", path: "/api", name: "test", value: "123")
        #expect(cookie.matches(domain: "example.com", path: "/api"))
        #expect(cookie.matches(domain: "example.com", path: "/api/users"))
        #expect(!cookie.matches(domain: "example.com", path: "/apiary"))
        #expect(!cookie.matches(domain: "example.com", path: "/api2"))
    }
    
    @Test func cookieJarRemoveCookie() {
        var jar = CookieJar()
        let cookie1 = HTTPCookie(domain: ".example.com", name: "session", value: "123")
        let cookie2 = HTTPCookie(domain: ".example.com", name: "token", value: "456")
        
        jar.addCookie(cookie1)
        jar.addCookie(cookie2)
        #expect(jar.cookies.count == 2)
        
        jar.removeCookie(id: cookie1.id)
        #expect(jar.cookies.count == 1)
        #expect(jar.cookies.first?.name == "token")
    }
    
    @Test func cookieJarRemoveExpiredCookies() {
        var jar = CookieJar()
        let expiredCookie = HTTPCookie(
            domain: ".example.com",
            name: "expired",
            value: "123",
            expiresDate: Date().addingTimeInterval(-3600)
        )
        let validCookie = HTTPCookie(
            domain: ".example.com",
            name: "valid",
            value: "456",
            expiresDate: Date().addingTimeInterval(3600)
        )
        
        jar.addCookie(expiredCookie)
        jar.addCookie(validCookie)
        #expect(jar.cookies.count == 2)
        
        jar.removeExpiredCookies()
        #expect(jar.cookies.count == 1)
        #expect(jar.cookies.first?.name == "valid")
    }
    
    @Test func cookiesForDomainAndPath() {
        var jar = CookieJar()
        let cookie1 = HTTPCookie(domain: ".example.com", path: "/api", name: "session", value: "123")
        let cookie2 = HTTPCookie(domain: ".example.com", path: "/other", name: "token", value: "456")
        let cookie3 = HTTPCookie(domain: "other.com", path: "/api", name: "other", value: "789")
        let expiredCookie = HTTPCookie(
            domain: ".example.com",
            path: "/api",
            name: "expired",
            value: "000",
            expiresDate: Date().addingTimeInterval(-3600)
        )
        
        jar.addCookie(cookie1)
        jar.addCookie(cookie2)
        jar.addCookie(cookie3)
        jar.addCookie(expiredCookie)
        
        let result = jar.cookies(for: "api.example.com", path: "/api/users")
        #expect(result.count == 1)
        #expect(result.first?.name == "session")
    }
}
