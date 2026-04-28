import Foundation
import Testing
@testable import MacAPITester

@Suite("Body Importer Exporter Tests")
struct BodyImporterExporterTests {
    @Test func exportsParametersToJSON() throws {
        let exporter = BodyImporterExporter()
        let parameters = [
            BodyParameter(name: "username", value: "test", type: "string", required: true, description: "用户名"),
            BodyParameter(name: "password", value: "123456", type: "string", required: true, description: "密码"),
        ]

        let jsonString = try exporter.exportToJSONString(parameters, bodyMode: "form-data")

        #expect(jsonString.contains("username"))
        #expect(jsonString.contains("password"))
        #expect(jsonString.contains("form-data"))
    }

    @Test func importsParametersFromJSON() throws {
        let exporter = BodyImporterExporter()
        let jsonString = """
        {
            "parameters": [
                {"name": "username", "value": "test", "type": "string", "required": true, "description": "用户名"}
            ],
            "bodyMode": "form-data"
        }
        """

        let importData = try exporter.importFromJSONString(jsonString)

        #expect(importData.parameters.count == 1)
        #expect(importData.parameters.first?.name == "username")
        #expect(importData.bodyMode == "form-data")
    }

    @Test func validatesImportData() throws {
        let exporter = BodyImporterExporter()
        let validJSON = """
        {
            "parameters": [{"name": "test", "value": "123"}],
            "bodyMode": "form-data"
        }
        """

        let isValid = try exporter.validateImportString(validJSON)
        #expect(isValid == true)
    }

    @Test func throwsErrorForInvalidJSON() {
        let exporter = BodyImporterExporter()
        let invalidJSON = "这不是有效的JSON"

        #expect(throws: ImportError.self) {
            try exporter.validateImportString(invalidJSON)
        }
    }

    @Test func exportAndImportRoundTrip() throws {
        let exporter = BodyImporterExporter()
        let original = [
            BodyParameter(name: "key1", value: "val1", type: "string", required: true, description: "desc1"),
            BodyParameter(name: "key2", value: "val2", type: "number", required: false, description: "desc2"),
        ]

        let jsonString = try exporter.exportToJSONString(original, bodyMode: "x-www-form-urlencoded", rawData: "raw content")
        let imported = try exporter.importFromJSONString(jsonString)

        #expect(imported.parameters == original)
        #expect(imported.bodyMode == "x-www-form-urlencoded")
        #expect(imported.rawData == "raw content")
    }

    @Test func validatesEmptyParametersAsInvalid() throws {
        let exporter = BodyImporterExporter()
        let emptyJSON = """
        {
            "parameters": [],
            "bodyMode": "form-data"
        }
        """

        let isValid = try exporter.validateImportString(emptyJSON)
        #expect(isValid == false)
    }

    @Test func validatesRawDataOnlyAsValid() throws {
        let exporter = BodyImporterExporter()
        let rawDataJSON = """
        {
            "parameters": [],
            "bodyMode": "raw",
            "rawData": "some raw content"
        }
        """

        let isValid = try exporter.validateImportString(rawDataJSON)
        #expect(isValid == true)
    }
}
