import Foundation

/// API 文档模型
struct APIDocModel: Codable, Equatable {
    let projectID: String
    let projectName: String
    let generatedAt: Date
    let sections: [APIDocSection]
}

/// API 文档章节
struct APIDocSection: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let method: String
    let url: String
    let description: String
    let authType: String
    let queryParams: [ParamInfo]
    let headers: [ParamInfo]
    let bodyParams: [ParamInfo]
    let requestBody: String?
    let responseBody: String?
    let responseFields: [ResponseFieldDoc]
    let variables: [String: String]
}

/// 参数信息
struct ParamInfo: Codable, Equatable {
    let name: String
    let type: String
    let example: String
    let required: Bool
    let description: String
}

/// 响应字段文档
struct ResponseFieldDoc: Codable, Equatable {
    let fieldName: String
    let fieldType: String
    let description: String
}
