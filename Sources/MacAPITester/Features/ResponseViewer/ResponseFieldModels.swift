import Foundation

/// 响应字段说明
struct ResponseFieldInfo: Identifiable, Equatable {
    let id: UUID
    var fieldName: String
    var fieldType: String
    var description: String

    init(id: UUID = UUID(), fieldName: String, fieldType: String, description: String = "") {
        self.id = id
        self.fieldName = fieldName
        self.fieldType = fieldType
        self.description = description
    }
}

/// JSON 字段解析器
enum ResponseFieldParser {

    /// 常见的包装字段名，解析时会跳过这些字段，直接解析其内部内容
    private static let wrapperKeys: Set<String> = ["data", "result", "items", "list", "rows", "records", "content"]

    /// 从 JSON 字符串解析字段信息
    static func parseFields(from jsonString: String) -> [ResponseFieldInfo] {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        var fields: [ResponseFieldInfo] = []
        extractFields(from: jsonObject, prefix: "", fields: &fields, isFirstLevel: true)
        return fields
    }

    /// 递归提取字段
    private static func extractFields(from object: Any, prefix: String, fields: inout [ResponseFieldInfo], isFirstLevel: Bool = false) {
        if let dict = object as? [String: Any] {
            // 如果是第一级，且包含包装字段（如 data），跳过 data 直接解析其内部，其他字段正常解析
            if isFirstLevel {
                for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                    if wrapperKeys.contains(key.lowercased()) {
                        // 跳过包装字段，直接解析其内部内容（支持字典和数组）
                        extractFields(from: value, prefix: "", fields: &fields, isFirstLevel: false)
                    } else {
                        // 其他字段正常解析
                        let fieldName = prefix.isEmpty ? key : "\(prefix).\(key)"
                        let fieldType = getType(of: value)
                        if let nestedDict = value as? [String: Any] {
                            fields.append(ResponseFieldInfo(fieldName: fieldName, fieldType: "object"))
                            extractFields(from: nestedDict, prefix: fieldName, fields: &fields)
                        } else if let array = value as? [Any], let first = array.first {
                            if let nestedDict = first as? [String: Any] {
                                fields.append(ResponseFieldInfo(fieldName: fieldName, fieldType: "array"))
                                extractFields(from: nestedDict, prefix: fieldName, fields: &fields)
                            } else {
                                fields.append(ResponseFieldInfo(fieldName: fieldName, fieldType: "array[\(getType(of: first))]"))
                            }
                        } else {
                            fields.append(ResponseFieldInfo(fieldName: fieldName, fieldType: fieldType))
                        }
                    }
                }
                return
            }

            for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                let fieldName = prefix.isEmpty ? key : "\(prefix).\(key)"
                let fieldType = getType(of: value)

                if let nestedDict = value as? [String: Any] {
                    // 对象类型，递归提取
                    fields.append(ResponseFieldInfo(fieldName: fieldName, fieldType: "object"))
                    extractFields(from: nestedDict, prefix: fieldName, fields: &fields)
                } else if let array = value as? [Any], let first = array.first {
                    // 数组类型
                    if let nestedDict = first as? [String: Any] {
                        fields.append(ResponseFieldInfo(fieldName: fieldName, fieldType: "array"))
                        extractFields(from: nestedDict, prefix: fieldName, fields: &fields)
                    } else {
                        fields.append(ResponseFieldInfo(fieldName: fieldName, fieldType: "array[\(getType(of: first))]"))
                    }
                } else {
                    fields.append(ResponseFieldInfo(fieldName: fieldName, fieldType: fieldType))
                }
            }
        } else if let array = object as? [Any], let first = array.first {
            extractFields(from: first, prefix: prefix, fields: &fields)
        }
    }

    /// 获取值的类型
    private static func getType(of value: Any) -> String {
        if value is NSNull {
            return "null"
        } else if value is Bool {
            return "boolean"
        } else if value is Int || value is Int64 {
            return "integer"
        } else if value is Double || value is Float {
            return "number"
        } else if value is String {
            return "string"
        } else if value is [Any] {
            return "array"
        } else if value is [String: Any] {
            return "object"
        }
        return "unknown"
    }
}
