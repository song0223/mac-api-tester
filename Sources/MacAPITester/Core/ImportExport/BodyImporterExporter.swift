import Foundation

struct BodyParameter: Codable, Equatable, Sendable {
    var name: String
    var value: String
    var type: String
    var required: Bool
    var description: String

    init(
        name: String = "",
        value: String = "",
        type: String = "string",
        required: Bool = false,
        description: String = ""
    ) {
        self.name = name
        self.value = value
        self.type = type
        self.required = required
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case name, value, type, required, description
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        value = try container.decodeIfPresent(String.self, forKey: .value) ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "string"
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
}

struct BodyImportExportData: Codable, Sendable {
    var parameters: [BodyParameter]
    var bodyMode: String
    var rawData: String?

    init(
        parameters: [BodyParameter] = [],
        bodyMode: String = "form-data",
        rawData: String? = nil
    ) {
        self.parameters = parameters
        self.bodyMode = bodyMode
        self.rawData = rawData
    }

    enum CodingKeys: String, CodingKey {
        case parameters, bodyMode, rawData
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parameters = try container.decodeIfPresent([BodyParameter].self, forKey: .parameters) ?? []
        bodyMode = try container.decodeIfPresent(String.self, forKey: .bodyMode) ?? "form-data"
        rawData = try container.decodeIfPresent(String.self, forKey: .rawData)
    }
}

enum ImportError: Error, LocalizedError, Sendable {
    case exportFailed(String)
    case importFailed(String)
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return "导出失败: \(message)"
        case .importFailed(let message):
            return "导入失败: \(message)"
        case .validationFailed(let message):
            return "验证失败: \(message)"
        }
    }
}

final class BodyImporterExporter: @unchecked Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
    }

    func exportParameters(_ parameters: [BodyParameter], bodyMode: String, rawData: String? = nil) throws -> Data {
        let exportData = BodyImportExportData(
            parameters: parameters,
            bodyMode: bodyMode,
            rawData: rawData
        )
        return try encoder.encode(exportData)
    }

    func importParameters(from data: Data) throws -> BodyImportExportData {
        return try decoder.decode(BodyImportExportData.self, from: data)
    }

    func exportToJSONString(_ parameters: [BodyParameter], bodyMode: String, rawData: String? = nil) throws -> String {
        let data = try exportParameters(parameters, bodyMode: bodyMode, rawData: rawData)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ImportError.exportFailed("无法将数据转换为JSON字符串")
        }
        return jsonString
    }

    func importFromJSONString(_ jsonString: String) throws -> BodyImportExportData {
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.importFailed("无法将JSON字符串转换为数据")
        }
        return try importParameters(from: data)
    }

    func validateImportData(_ data: Data) throws -> Bool {
        do {
            let importData = try decoder.decode(BodyImportExportData.self, from: data)
            return !importData.parameters.isEmpty || importData.rawData != nil
        } catch {
            throw ImportError.validationFailed("JSON格式无效: \(error.localizedDescription)")
        }
    }

    func validateImportString(_ jsonString: String) throws -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.validationFailed("无法将JSON字符串转换为数据")
        }
        return try validateImportData(data)
    }
}
