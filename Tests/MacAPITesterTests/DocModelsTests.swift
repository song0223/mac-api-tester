import Foundation
import Testing
@testable import MacAPITester

@Suite("DocModels Tests")
struct DocModelsTests {
    @Test func testAPIDocModelInitialization() {
        let model = APIDocModel(
            projectID: "test-id",
            projectName: "测试项目",
            generatedAt: Date(),
            sections: []
        )
        
        #expect(model.projectID == "test-id")
        #expect(model.projectName == "测试项目")
        #expect(model.sections.isEmpty)
    }
    
    @Test func testAPIDocSectionInitialization() {
        let section = APIDocSection(
            id: "section-1",
            name: "获取用户",
            method: "GET",
            url: "https://api.example.com/users",
            description: "获取用户列表",
            authType: "Bearer",
            queryParams: [],
            headers: [],
            bodyParams: [],
            requestBody: nil,
            responseBody: "{\"users\": []}",
            variables: [:]
        )
        
        #expect(section.name == "获取用户")
        #expect(section.method == "GET")
    }
    
    @Test func testParamInfoInitialization() {
        let param = ParamInfo(
            name: "page",
            type: "number",
            example: "1",
            required: false,
            description: "页码"
        )

        #expect(param.name == "page")
        #expect(param.type == "number")
        #expect(!param.required)
    }
}
