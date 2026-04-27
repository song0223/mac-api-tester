import Testing
@testable import MacAPITester

@Suite("Script Models Tests")
struct ScriptModelsTests {
    @Test func scriptTypeDisplayName() {
        #expect(ScriptType.preRequest.displayName == "前执行脚本")
        #expect(ScriptType.postResponse.displayName == "后执行脚本")
    }
    
    @Test func scriptEngineTypeDisplayName() {
        #expect(ScriptEngineType.javaScriptCore.displayName == "JavaScriptCore")
        #expect(ScriptEngineType.quickJS.displayName == "QuickJS")
    }
    
    @Test func scriptInitialization() {
        let script = Script(name: "测试脚本", scriptType: .preRequest, content: "console.log('hello')")
        #expect(script.name == "测试脚本")
        #expect(script.scriptType == .preRequest)
        #expect(script.isEnabled == true)
    }
}
