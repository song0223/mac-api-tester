import Testing
@testable import MacAPITester

@Suite("HTMLRenderer Tests")
struct HTMLRendererTests {
    @Test func testRenderHTML() {
        let renderer = HTMLRenderer()
        
        let markdown = """
        # API文档 - 测试项目
        
        ## 获取用户
        
        **URL:** `GET https://api.example.com/users`
        """
        
        let html = renderer.render(markdown, title: "测试项目")
        
        #expect(html.contains("<html"))
        #expect(html.contains("测试项目"))
        #expect(html.contains("获取用户"))
    }
    
    @Test func testHTMLContainsStyles() {
        let renderer = HTMLRenderer()
        
        let html = renderer.render("# Test", title: "Test")
        
        #expect(html.contains("<style>"))
        #expect(html.contains("</style>"))
    }
}
