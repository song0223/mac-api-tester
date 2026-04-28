import Testing
@testable import MacAPITester

@Suite("DocServer Tests")
struct DocServerTests {
    @Test func testServerInitialization() throws {
        let database = try MySQLDatabase()
        let server = DocServer(port: 8081, database: database)

        #expect(server.port == 8081)
    }
}
