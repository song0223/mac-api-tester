import Testing
import Foundation
@testable import MacAPITester

@Suite("Test Case Manager Tests")
struct TestCaseManagerTests {
    @Test func createsAndRetrievesTestCase() throws {
        let manager = TestCaseManager()
        let requestID = UUID()
        let testCase = TestCase(requestID: requestID, name: "测试用例")
        
        try manager.createTestCase(testCase)
        
        let retrieved = manager.getTestCases(for: requestID)
        #expect(retrieved.count == 1)
        #expect(retrieved.first?.name == "测试用例")
    }
    
    @Test func createsAndManagesTestSuite() throws {
        let manager = TestCaseManager()
        let projectID = UUID()
        let suite = TestSuite(projectID: projectID, name: "测试套件")
        
        try manager.createTestSuite(suite)
        
        let suites = manager.getTestSuites(for: projectID)
        #expect(suites.count == 1)
        #expect(suites.first?.name == "测试套件")
    }
    
    @Test func addsTestCaseToSuite() throws {
        let manager = TestCaseManager()
        let requestID = UUID()
        let projectID = UUID()
        
        let testCase = TestCase(requestID: requestID, name: "测试用例")
        try manager.createTestCase(testCase)
        
        let suite = TestSuite(projectID: projectID, name: "测试套件")
        try manager.createTestSuite(suite)
        
        try manager.addTestCaseToSuite(testCaseID: testCase.id, suiteID: suite.id)
        
        let testCases = manager.getTestCases(in: suite.id)
        #expect(testCases.count == 1)
        #expect(testCases.first?.name == "测试用例")
    }
    
    @Test func updatesTestCase() throws {
        let manager = TestCaseManager()
        let requestID = UUID()
        var testCase = TestCase(requestID: requestID, name: "原始名称")
        
        try manager.createTestCase(testCase)
        
        testCase.name = "更新后的名称"
        try manager.updateTestCase(testCase)
        
        let retrieved = manager.getTestCases(for: requestID)
        #expect(retrieved.first?.name == "更新后的名称")
    }
    
    @Test func deletesTestCase() throws {
        let manager = TestCaseManager()
        let requestID = UUID()
        let testCase = TestCase(requestID: requestID, name: "待删除")
        
        try manager.createTestCase(testCase)
        #expect(manager.getTestCases(for: requestID).count == 1)
        
        try manager.deleteTestCase(id: testCase.id)
        #expect(manager.getTestCases(for: requestID).isEmpty)
    }
    
    @Test func removesTestCaseFromSuite() throws {
        let manager = TestCaseManager()
        let requestID = UUID()
        let projectID = UUID()
        
        let testCase = TestCase(requestID: requestID, name: "测试用例")
        try manager.createTestCase(testCase)
        
        let suite = TestSuite(projectID: projectID, name: "测试套件")
        try manager.createTestSuite(suite)
        
        try manager.addTestCaseToSuite(testCaseID: testCase.id, suiteID: suite.id)
        #expect(manager.getTestCases(in: suite.id).count == 1)
        
        try manager.removeTestCaseFromSuite(testCaseID: testCase.id, suiteID: suite.id)
        #expect(manager.getTestCases(in: suite.id).isEmpty)
    }
    
    @Test func exportsAndImportsTestCase() throws {
        let manager = TestCaseManager()
        let requestID = UUID()
        let testCase = TestCase(requestID: requestID, name: "导出测试")
        
        try manager.createTestCase(testCase)
        
        let exportedData = try manager.exportTestCase(id: testCase.id)
        #expect(exportedData != nil)
        
        let newRequestID = UUID()
        let importedTestCase = try manager.importTestCase(from: exportedData!, requestID: newRequestID)
        #expect(importedTestCase.name == "导出测试")
        #expect(importedTestCase.requestID == newRequestID)
    }
    
    @Test func filtersTestCasesByRequestID() throws {
        let manager = TestCaseManager()
        let requestID1 = UUID()
        let requestID2 = UUID()
        
        let testCase1 = TestCase(requestID: requestID1, name: "用例1")
        let testCase2 = TestCase(requestID: requestID1, name: "用例2")
        let testCase3 = TestCase(requestID: requestID2, name: "用例3")
        
        try manager.createTestCase(testCase1)
        try manager.createTestCase(testCase2)
        try manager.createTestCase(testCase3)
        
        let request1Cases = manager.getTestCases(for: requestID1)
        #expect(request1Cases.count == 2)
        
        let request2Cases = manager.getTestCases(for: requestID2)
        #expect(request2Cases.count == 1)
    }
    
    @Test func filtersTestSuitesByProjectID() throws {
        let manager = TestCaseManager()
        let projectID1 = UUID()
        let projectID2 = UUID()
        
        let suite1 = TestSuite(projectID: projectID1, name: "套件1")
        let suite2 = TestSuite(projectID: projectID1, name: "套件2")
        let suite3 = TestSuite(projectID: projectID2, name: "套件3")
        
        try manager.createTestSuite(suite1)
        try manager.createTestSuite(suite2)
        try manager.createTestSuite(suite3)
        
        let project1Suites = manager.getTestSuites(for: projectID1)
        #expect(project1Suites.count == 2)
        
        let project2Suites = manager.getTestSuites(for: projectID2)
        #expect(project2Suites.count == 1)
    }
}