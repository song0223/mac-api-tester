import Foundation

enum TemplateRendererError: Error, Equatable {
    case missingVariable(String)
}

enum HTTPMethod: String, Equatable, CaseIterable, Identifiable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"

    var id: String { rawValue }
}

struct APIRequestDraft: Equatable {
    var method: HTTPMethod
    var path: String
    var query: [String: String]
    var queryItems: [URLQueryItem]?
    var headers: [String: String]
    var body: String?
    var variables: [String: String]
    var bearerToken: String?

    init(
        method: HTTPMethod,
        path: String,
        query: [String: String] = [:],
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        body: String? = nil,
        variables: [String: String] = [:],
        bearerToken: String? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.variables = variables
        self.bearerToken = bearerToken
    }
}

enum RequestAuthType: String, CaseIterable, Identifiable {
    case none = "None"
    case bearer = "Bearer"
    case basic = "Basic"
    case apiKey = "API Key"

    var id: String { rawValue }
}

struct RequestAuthConfiguration: Equatable {
    var type: RequestAuthType
    var bearerToken: String
    var basicUsername: String
    var basicPassword: String
    var apiKeyHeader: String
    var apiKeyValue: String

    init(
        type: RequestAuthType = .none,
        bearerToken: String = "",
        basicUsername: String = "",
        basicPassword: String = "",
        apiKeyHeader: String = "X-API-Key",
        apiKeyValue: String = ""
    ) {
        self.type = type
        self.bearerToken = bearerToken
        self.basicUsername = basicUsername
        self.basicPassword = basicPassword
        self.apiKeyHeader = apiKeyHeader
        self.apiKeyValue = apiKeyValue
    }
}

struct RequestProject: Identifiable, Equatable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct RequestDocument: Identifiable, Equatable {
    let id: UUID
    var projectID: UUID
    var name: String
    var apiStatus: String
    var descriptionText: String
    var method: HTTPMethod
    var urlString: String
    var queryText: String
    var headersText: String
    var bodyText: String
    var variablesText: String
    var auth: RequestAuthConfiguration

    init(
        id: UUID = UUID(),
        projectID: UUID,
        name: String,
        apiStatus: String = "接口状态",
        descriptionText: String = "",
        method: HTTPMethod = .get,
        urlString: String,
        queryText: String = "",
        headersText: String = "",
        bodyText: String = "",
        variablesText: String = "",
        auth: RequestAuthConfiguration = RequestAuthConfiguration()
    ) {
        self.id = id
        self.projectID = projectID
        self.name = name
        self.apiStatus = apiStatus
        self.descriptionText = descriptionText
        self.method = method
        self.urlString = urlString
        self.queryText = queryText
        self.headersText = headersText
        self.bodyText = bodyText
        self.variablesText = variablesText
        self.auth = auth
    }

    static func starter(named name: String = "Request 1", projectID: UUID) -> Self {
        RequestDocument(
            projectID: projectID,
            name: name,
            method: .get,
            urlString: "https://postman-echo.com/get",
            queryText: "hello={{name}}",
            headersText: "Accept: application/json",
            bodyText: "",
            variablesText: "name=world",
            auth: RequestAuthConfiguration()
        )
    }
    
    func toMySQLRecord() -> MySQLRequestDocumentRecord {
        MySQLRequestDocumentRecord(
            id: id.uuidString,
            projectID: projectID.uuidString,
            name: name,
            apiStatus: apiStatus,
            descriptionText: descriptionText,
            method: method.rawValue,
            urlString: urlString,
            queryText: queryText,
            headersText: headersText,
            bodyText: bodyText,
            variablesText: variablesText,
            authType: auth.type.rawValue,
            authConfig: nil
        )
    }
    
    static func fromMySQLRecord(_ record: MySQLRequestDocumentRecord) -> RequestDocument? {
        guard let id = UUID(uuidString: record.id),
              let projectID = UUID(uuidString: record.projectID),
              let method = HTTPMethod(rawValue: record.method) else {
            return nil
        }
        
        let authType = RequestAuthType(rawValue: record.authType) ?? .none
        
        return RequestDocument(
            id: id,
            projectID: projectID,
            name: record.name,
            apiStatus: record.apiStatus,
            descriptionText: record.descriptionText,
            method: method,
            urlString: record.urlString,
            queryText: record.queryText,
            headersText: record.headersText,
            bodyText: record.bodyText,
            variablesText: record.variablesText,
            auth: RequestAuthConfiguration(type: authType)
        )
    }
}

struct RequestResponseSnapshot: Equatable {
    let statusCode: Int
    let duration: TimeInterval
    let headersText: String
    let bodyText: String
    let timestamp: Date
}

struct RequestHistoryItem: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let message: String

    init(id: UUID = UUID(), timestamp: Date = Date(), message: String) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
    }
}
