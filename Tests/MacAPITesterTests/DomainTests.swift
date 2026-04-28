import Testing
@testable import MacAPITester

@Suite("Domain Tests")
struct DomainTests {
    @Test func templateRendererReplacesVariables() throws {
        let renderer = TemplateRenderer()

        let rendered = try renderer.render(
            "Hello, {{name}}!",
            variables: ["name": "World"]
        )

        #expect(rendered == "Hello, World!")
    }

    @Test func templateRendererThrowsWhenVariableIsMissing() {
        let renderer = TemplateRenderer()

        #expect(throws: TemplateRendererError.missingVariable("name")) {
            _ = try renderer.render(
                "Hello, {{name}}!",
                variables: [:]
            )
        }
    }

    @Test func authInjectorAddsBearerTokenAuthorizationHeader() {
        let injector = AuthInjector()

        let result = injector.injectBearerToken(
            into: ["Accept": "application/json"],
            token: "abc123"
        )

        #expect(result["Accept"] == "application/json")
        #expect(result["Authorization"] == "Bearer abc123")
    }

    @Test func authInjectorReplacesExistingAuthorizationHeaderRegardlessOfCase() {
        let injector = AuthInjector()

        let result = injector.injectBearerToken(
            into: [
                "Accept": "application/json",
                "authorization": "Bearer old-token",
            ],
            token: "abc123"
        )

        #expect(result["authorization"] == nil)
        #expect(result["Authorization"] == "Bearer abc123")
        #expect(result.count == 2)
    }
}
