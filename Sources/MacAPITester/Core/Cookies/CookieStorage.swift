import Foundation

final class CookieStorage {
    private let database: MySQLDatabase?
    private let fileManager: FileManager
    private let fileURL: URL
    
    init(database: MySQLDatabase? = nil, fileURL: URL? = nil) {
        self.database = database
        self.fileManager = FileManager.default
        self.fileURL = fileURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacAPITester")
            .appendingPathComponent("cookies.json")
        
        createDirectoryIfNeeded()
    }
    
    private func createDirectoryIfNeeded() {
        let directory = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    
    func saveCookies(_ cookieJar: CookieJar) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cookieJar)
        try data.write(to: fileURL)
        
        if let database {
            try saveCookiesToDatabase(cookieJar.cookies)
        }
    }
    
    func loadCookies() throws -> CookieJar {
        if let database, let cookies = try? loadCookiesFromDatabase() {
            return CookieJar(cookies: cookies)
        }
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return CookieJar()
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CookieJar.self, from: data)
    }
    
    private func saveCookiesToDatabase(_ cookies: [HTTPCookie]) throws {
        for cookie in cookies {
            let expiresDate = cookie.expiresDate.map { String($0.timeIntervalSince1970) }
            try database?.execute(
                """
                REPLACE INTO cookies (id, domain, path, name, value, expires_at, is_secure, is_http_only, same_site)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                parameters: [
                    .string(cookie.id.uuidString),
                    .string(cookie.domain),
                    .string(cookie.path),
                    .string(cookie.name),
                    .string(cookie.value),
                    expiresDate.map { .string($0) } ?? .null,
                    .int(cookie.isSecure ? 1 : 0),
                    .int(cookie.isHTTPOnly ? 1 : 0),
                    .string(cookie.sameSite.rawValue),
                ]
            )
        }
    }
    
    private func loadCookiesFromDatabase() throws -> [HTTPCookie]? {
        guard let results = try database?.query("SELECT * FROM cookies") else {
            return nil
        }
        
        return results.compactMap { row -> HTTPCookie? in
            guard let idString = row["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let domain = row["domain"] as? String,
                  let path = row["path"] as? String,
                  let name = row["name"] as? String,
                  let value = row["value"] as? String else {
                return nil
            }
            
            let expiresDate = (row["expires_at"] as? String).flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0) }
            let isSecure = (row["is_secure"] as? Int) == 1
            let isHTTPOnly = (row["is_http_only"] as? Int) == 1
            let sameSite = HTTPCookie.SameSitePolicy(rawValue: row["same_site"] as? String ?? "Lax") ?? .lax
            
            return HTTPCookie(
                id: id,
                domain: domain,
                path: path,
                name: name,
                value: value,
                expiresDate: expiresDate,
                isSecure: isSecure,
                isHTTPOnly: isHTTPOnly,
                sameSite: sameSite
            )
        }
    }
    
    func exportCookies(_ cookieJar: CookieJar) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(cookieJar)
    }
    
    func importCookies(from data: Data) throws -> CookieJar {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CookieJar.self, from: data)
    }
}
