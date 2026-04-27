import Testing
import Foundation
@testable import MacAPITester

@Suite("Cookie Storage Tests")
struct CookieStorageTests {
    private func makeTemporaryStorage() throws -> (CookieStorage, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("cookies.json")
        return (CookieStorage(fileURL: fileURL), fileURL)
    }
    
    @Test func savesAndLoadsCookies() throws {
        let (storage, _) = try makeTemporaryStorage()
        var jar = CookieJar()
        let cookie = HTTPCookie(domain: ".example.com", name: "session", value: "123")
        jar.addCookie(cookie)
        
        try storage.saveCookies(jar)
        let loaded = try storage.loadCookies()
        
        #expect(loaded.cookies.count == 1)
        #expect(loaded.cookies.first?.name == "session")
    }
    
    @Test func exportsAndImportsCookies() throws {
        let (storage, _) = try makeTemporaryStorage()
        var jar = CookieJar()
        let cookie = HTTPCookie(domain: ".example.com", name: "session", value: "123")
        jar.addCookie(cookie)
        
        let data = try storage.exportCookies(jar)
        let imported = try storage.importCookies(from: data)
        
        #expect(imported.cookies.count == 1)
        #expect(imported.cookies.first?.value == "123")
    }
    
    @Test func loadReturnsEmptyJarWhenNoFile() throws {
        let (storage, _) = try makeTemporaryStorage()
        let loaded = try storage.loadCookies()
        
        #expect(loaded.cookies.isEmpty)
    }
    
    @Test func savesAndLoadsMultipleCookies() throws {
        let (storage, _) = try makeTemporaryStorage()
        var jar = CookieJar()
        let cookie1 = HTTPCookie(domain: ".example.com", name: "session", value: "123")
        let cookie2 = HTTPCookie(domain: ".example.com", name: "token", value: "abc")
        jar.addCookie(cookie1)
        jar.addCookie(cookie2)
        
        try storage.saveCookies(jar)
        let loaded = try storage.loadCookies()
        
        #expect(loaded.cookies.count == 2)
    }
    
    @Test func exportsPrettyPrintedJSON() throws {
        let (storage, _) = try makeTemporaryStorage()
        var jar = CookieJar()
        let cookie = HTTPCookie(domain: ".example.com", name: "session", value: "123")
        jar.addCookie(cookie)
        
        let data = try storage.exportCookies(jar)
        let jsonString = String(data: data, encoding: .utf8)!
        
        #expect(jsonString.contains("\n"))
        #expect(jsonString.contains("session"))
    }
}
