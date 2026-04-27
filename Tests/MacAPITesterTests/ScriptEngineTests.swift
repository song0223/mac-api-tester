import Foundation
import Testing
@testable import MacAPITester

@Suite("Script Engine Tests")
struct ScriptEngineTests {
    @Test func executesJavaScriptCoreScript() throws {
        let engine = ScriptEngine()
        let script = Script(
            name: "测试脚本",
            scriptType: .preRequest,
            engine: .javaScriptCore,
            content: "console.log('Hello from script'); variables.test = 'modified';"
        )

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let context = ScriptExecutionContext(request: request, variables: ["original": "value"])

        let result = try engine.execute(script: script, context: context)

        #expect(result.success)
        #expect(result.modifiedVariables?["test"] == "modified")
    }

    @Test func skipsDisabledScript() throws {
        let engine = ScriptEngine()
        let script = Script(
            name: "禁用脚本",
            scriptType: .preRequest,
            engine: .javaScriptCore,
            content: "variables.test = 'modified';",
            isEnabled: false
        )

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let context = ScriptExecutionContext(request: request)

        let result = try engine.execute(script: script, context: context)

        #expect(result.success)
        #expect(result.modifiedVariables == nil)
    }

    @Test func executesMultipleScriptsInOrder() throws {
        let engine = ScriptEngine()
        let scripts = [
            Script(name: "脚本1", content: "variables.order = '1';", executionOrder: 2),
            Script(name: "脚本2", content: "variables.order = '2';", executionOrder: 1),
        ]

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let context = ScriptExecutionContext(request: request)

        let result = try engine.executeScripts(scripts, context: context)

        #expect(result.success)
        #expect(result.modifiedVariables?["order"] == "1")
    }
}
