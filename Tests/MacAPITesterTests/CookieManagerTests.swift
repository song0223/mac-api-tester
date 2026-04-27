import Testing
import Foundation
@testable import MacAPITester

@Suite("Cookie Manager Tests")
struct CookieManagerTests {
    private func makeTemporaryManager() throws -> (CookieManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("cookies.json")
        let storage = CookieStorage(fileURL: fileURL)
        return (CookieManager(storage: storage), fileURL)
    }
    
    @Test func appliesCookiesToRequest() throws {
        let (manager, _) = try makeTemporaryManager()
        
        let cookie = HTTPCookie(domain: "example.com", name: "session", value: "123")
        manager.addCookie(cookie)
        
        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        manager.applyCookies(to: &request)
        
        #expect(request.value(forHTTPHeaderField: "Cookie") == "session=123")
    }
    
    @Test func extractsCookiesFromResponse() throws {
        let (manager, _) = try makeTemporaryManager()
        
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Set-Cookie": "session=123; Path=/; Secure"]
        )!
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        manager.addCookies(from: response, request: request)
        
        let cookies = manager.cookies(for: URLRequest(url: URL(string: "https://example.com/api")!))
        #expect(cookies.count == 1)
        #expect(cookies.first?.name == "session")
    }
    
    @Test func returnsEmptyForNilURL() throws {
        let (manager, _) = try makeTemporaryManager()
        
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.url = nil
        let cookies = manager.cookies(for: request)
        
        #expect(cookies.isEmpty)
    }
    
    @Test func removeCookieById() throws {
        let (manager, _) = try makeTemporaryManager()
        
        let cookie = HTTPCookie(domain: "example.com", name: "session", value: "123")
        manager.addCookie(cookie)
        
        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        manager.applyCookies(to: &request)
        #expect(request.value(forHTTPHeaderField: "Cookie") == "session=123")
        
        manager.removeCookie(id: cookie.id)
        
        request = URLRequest(url: URL(string: "https://example.com/api")!)
        manager.applyCookies(to: &request)
        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
    }
    
    @Test func clearCookies() throws {
        let (manager, _) = try makeTemporaryManager()
        
        let cookie1 = HTTPCookie(domain: "example.com", name: "session", value: "123")
        let cookie2 = HTTPCookie(domain: "example.com", name: "token", value: "abc")
        manager.addCookie(cookie1)
        manager.addCookie(cookie2)
        
        manager.clearCookies()
        
        let cookies = manager.cookies(for: URLRequest(url: URL(string: "https://example.com/api")!))
        #expect(cookies.isEmpty)
    }
    
    @Test func removeExpiredCookies() throws {
        let (manager, _) = try makeTemporaryManager()
        
        let expiredCookie = HTTPCookie(
            domain: "example.com",
            name: "expired",
            value: "123",
            expiresDate: Date().addingTimeInterval(-3600)
        )
        let validCookie = HTTPCookie(
            domain: "example.com",
            name: "valid",
            value: "456",
            expiresDate: Date().addingTimeInterval(3600)
        )
        
        manager.addCookie(expiredCookie)
        manager.addCookie(validCookie)
        
        manager.removeExpiredCookies()
        
        let cookies = manager.cookies(for: URLRequest(url: URL(string: "https://example.com/api")!))
        #expect(cookies.count == 1)
        #expect(cookies.first?.name == "valid")
    }
    
    @Test func applyCookiesDoesNotSetHeaderWhenEmpty() throws {
        let (manager, _) = try makeTemporaryManager()
        
        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        manager.applyCookies(to: &request)
        
        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
    }
    
    @Test func multipleCookiesFormattedCorrectly() throws {
        let (manager, _) = try makeTemporaryManager()
        
        let cookie1 = HTTPCookie(domain: "example.com", name: "session", value: "123")
        let cookie2 = HTTPCookie(domain: "example.com", name: "token", value: "abc")
        manager.addCookie(cookie1)
        manager.addCookie(cookie2)
        
        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        manager.applyCookies(to: &request)
        
        let cookieHeader = request.value(forHTTPHeaderField: "Cookie")!
        #expect(cookieHeader.contains("session=123"))
        #expect(cookieHeader.contains("token=abc"))
        #expect(cookieHeader.contains("; "))
    }
}
