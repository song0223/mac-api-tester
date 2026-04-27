import Foundation

final class TestCaseManager {
    private let database: MySQLDatabase?
    private var testCases: [TestCase] = []
    private var testSuites: [TestSuite] = []
    
    init(database: MySQLDatabase? = nil) {
        self.database = database
        loadTestData()
    }
    
    private func loadTestData() {
        guard let database else { return }
        
        // 加载测试用例
        if let results = try? database.query("SELECT * FROM test_cases ORDER BY execution_order") {
            testCases = results.compactMap { row -> TestCase? in
                guard let idString = row["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let requestIDString = row["request_id"] as? String,
                      let requestID = UUID(uuidString: requestIDString),
                      let name = row["name"] as? String else {
                    return nil
                }
                
                return TestCase(
                    id: id,
                    requestID: requestID,
                    name: name,
                    description: row["description"] as? String ?? "",
                    variables: parseVariables(row["variables"]),
                    expectedStatusCode: row["expected_status"] as? Int,
                    expectedBodyContains: row["expected_body_contains"] as? String,
                    expectedHeaders: parseHeaders(row["expected_headers"]),
                    isEnabled: (row["is_enabled"] as? Int) == 1,
                    executionOrder: row["execution_order"] as? Int ?? 0
                )
            }
        }
        
        // 加载测试套件
        if let results = try? database.query("SELECT * FROM test_suites") {
            testSuites = results.compactMap { row -> TestSuite? in
                guard let idString = row["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let projectIDString = row["project_id"] as? String,
                      let projectID = UUID(uuidString: projectIDString),
                      let name = row["name"] as? String else {
                    return nil
                }
                
                return TestSuite(
                    id: id,
                    projectID: projectID,
                    name: name,
                    description: row["description"] as? String ?? ""
                )
            }
        }
        
        // 加载测试套件关联的测试用例
        for i in 0..<testSuites.count {
            let suiteID = testSuites[i].id
            if let results = try? database.query(
                "SELECT test_case_id FROM suite_test_cases WHERE suite_id = ?",
                parameters: [.string(suiteID.uuidString)]
            ) {
                testSuites[i].testCaseIDs = results.compactMap { row -> UUID? in
                    guard let idString = row["test_case_id"] as? String else { return nil }
                    return UUID(uuidString: idString)
                }
            }
        }
    }
    
    private func parseVariables(_ value: Any?) -> [String: String] {
        guard let jsonString = value as? String,
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }
    
    private func parseHeaders(_ value: Any?) -> [String: String] {
        guard let jsonString = value as? String,
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }
    
    func createTestCase(_ testCase: TestCase) throws {
        testCases.append(testCase)
        
        guard let database else { return }
        
        let variablesJSON = try? JSONSerialization.data(withJSONObject: testCase.variables)
        let variablesString = variablesJSON.flatMap { String(data: $0, encoding: .utf8) }
        
        let headersJSON = try? JSONSerialization.data(withJSONObject: testCase.expectedHeaders)
        let headersString = headersJSON.flatMap { String(data: $0, encoding: .utf8) }
        
        try database.execute(
            """
            INSERT INTO test_cases (id, request_id, name, description, variables, expected_status, expected_body_contains, expected_headers, is_enabled, execution_order)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .string(testCase.id.uuidString),
                .string(testCase.requestID.uuidString),
                .string(testCase.name),
                .string(testCase.description),
                .string(variablesString ?? "{}"),
                testCase.expectedStatusCode.map { .int($0) } ?? .null,
                testCase.expectedBodyContains.map { .string($0) } ?? .null,
                .string(headersString ?? "{}"),
                .int(testCase.isEnabled ? 1 : 0),
                .int(testCase.executionOrder)
            ]
        )
    }
    
    func updateTestCase(_ testCase: TestCase) throws {
        guard let index = testCases.firstIndex(where: { $0.id == testCase.id }) else {
            return
        }
        testCases[index] = testCase
        
        guard let database else { return }
        
        let variablesJSON = try? JSONSerialization.data(withJSONObject: testCase.variables)
        let variablesString = variablesJSON.flatMap { String(data: $0, encoding: .utf8) }
        
        let headersJSON = try? JSONSerialization.data(withJSONObject: testCase.expectedHeaders)
        let headersString = headersJSON.flatMap { String(data: $0, encoding: .utf8) }
        
        try database.execute(
            """
            UPDATE test_cases SET name = ?, description = ?, variables = ?, expected_status = ?, expected_body_contains = ?, expected_headers = ?, is_enabled = ?, execution_order = ? WHERE id = ?
            """,
            parameters: [
                .string(testCase.name),
                .string(testCase.description),
                .string(variablesString ?? "{}"),
                testCase.expectedStatusCode.map { .int($0) } ?? .null,
                testCase.expectedBodyContains.map { .string($0) } ?? .null,
                .string(headersString ?? "{}"),
                .int(testCase.isEnabled ? 1 : 0),
                .int(testCase.executionOrder),
                .string(testCase.id.uuidString)
            ]
        )
    }
    
    func deleteTestCase(id: UUID) throws {
        testCases.removeAll { $0.id == id }
        
        guard let database else { return }
        try database.execute(
            "DELETE FROM test_cases WHERE id = ?",
            parameters: [.string(id.uuidString)]
        )
    }
    
    func createTestSuite(_ suite: TestSuite) throws {
        testSuites.append(suite)
        
        guard let database else { return }
        
        try database.execute(
            """
            INSERT INTO test_suites (id, project_id, name, description)
            VALUES (?, ?, ?, ?)
            """,
            parameters: [
                .string(suite.id.uuidString),
                .string(suite.projectID.uuidString),
                .string(suite.name),
                .string(suite.description)
            ]
        )
    }
    
    func updateTestSuite(_ suite: TestSuite) throws {
        guard let index = testSuites.firstIndex(where: { $0.id == suite.id }) else {
            return
        }
        testSuites[index] = suite
        
        guard let database else { return }
        
        try database.execute(
            "UPDATE test_suites SET name = ?, description = ? WHERE id = ?",
            parameters: [
                .string(suite.name),
                .string(suite.description),
                .string(suite.id.uuidString)
            ]
        )
    }
    
    func deleteTestSuite(id: UUID) throws {
        testSuites.removeAll { $0.id == id }
        
        guard let database else { return }
        try database.execute(
            "DELETE FROM test_suites WHERE id = ?",
            parameters: [.string(id.uuidString)]
        )
    }
    
    func addTestCaseToSuite(testCaseID: UUID, suiteID: UUID) throws {
        guard let suiteIndex = testSuites.firstIndex(where: { $0.id == suiteID }) else {
            return
        }
        
        if !testSuites[suiteIndex].testCaseIDs.contains(testCaseID) {
            testSuites[suiteIndex].testCaseIDs.append(testCaseID)
        }
        
        guard let database else { return }
        
        try database.execute(
            "INSERT INTO suite_test_cases (suite_id, test_case_id) VALUES (?, ?)",
            parameters: [
                .string(suiteID.uuidString),
                .string(testCaseID.uuidString)
            ]
        )
    }
    
    func removeTestCaseFromSuite(testCaseID: UUID, suiteID: UUID) throws {
        guard let suiteIndex = testSuites.firstIndex(where: { $0.id == suiteID }) else {
            return
        }
        
        testSuites[suiteIndex].testCaseIDs.removeAll { $0 == testCaseID }
        
        guard let database else { return }
        
        try database.execute(
            "DELETE FROM suite_test_cases WHERE suite_id = ? AND test_case_id = ?",
            parameters: [
                .string(suiteID.uuidString),
                .string(testCaseID.uuidString)
            ]
        )
    }
    
    func getTestCases(for requestID: UUID) -> [TestCase] {
        testCases.filter { $0.requestID == requestID }
    }
    
    func getTestCases(in suiteID: UUID) -> [TestCase] {
        guard let suite = testSuites.first(where: { $0.id == suiteID }) else {
            return []
        }
        return suite.testCaseIDs.compactMap { id in
            testCases.first { $0.id == id }
        }
    }
    
    func getTestSuites(for projectID: UUID) -> [TestSuite] {
        testSuites.filter { $0.projectID == projectID }
    }
    
    func exportTestCase(id: UUID) throws -> Data? {
        guard let testCase = testCases.first(where: { $0.id == id }) else {
            return nil
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(testCase)
    }
    
    func importTestCase(from data: Data, requestID: UUID) throws -> TestCase {
        let decoder = JSONDecoder()
        var testCase = try decoder.decode(TestCase.self, from: data)
        testCase.requestID = requestID
        try createTestCase(testCase)
        return testCase
    }
}