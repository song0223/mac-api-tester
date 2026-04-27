import Foundation

enum ScriptType: String, Codable, CaseIterable, Identifiable {
    case preRequest = "pre_request"
    case postResponse = "post_response"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .preRequest: return "前执行脚本"
        case .postResponse: return "后执行脚本"
        }
    }
}

enum ScriptEngineType: String, Codable, CaseIterable, Identifiable {
    case javaScriptCore = "javascriptcore"
    case quickJS = "quickjs"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .javaScriptCore: return "JavaScriptCore"
        case .quickJS: return "QuickJS"
        }
    }
}

struct Script: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var scriptType: ScriptType
    var engine: ScriptEngineType
    var content: String
    var isEnabled: Bool
    var executionOrder: Int
    
    init(
        id: UUID = UUID(),
        name: String = "新脚本",
        scriptType: ScriptType = .preRequest,
        engine: ScriptEngineType = .javaScriptCore,
        content: String = "",
        isEnabled: Bool = true,
        executionOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.scriptType = scriptType
        self.engine = engine
        self.content = content
        self.isEnabled = isEnabled
        self.executionOrder = executionOrder
    }
}

struct ScriptExecutionContext {
    var request: URLRequest
    var response: HTTPURLResponse?
    var responseBody: Data?
    var variables: [String: String]
    var cookies: [String: String]
    
    init(
        request: URLRequest,
        response: HTTPURLResponse? = nil,
        responseBody: Data? = nil,
        variables: [String: String] = [:],
        cookies: [String: String] = [:]
    ) {
        self.request = request
        self.response = response
        self.responseBody = responseBody
        self.variables = variables
        self.cookies = cookies
    }
}

struct ScriptExecutionResult {
    var success: Bool
    var output: String
    var error: String?
    var modifiedRequest: URLRequest?
    var modifiedResponse: (HTTPURLResponse, Data)?
    var modifiedVariables: [String: String]?
    var modifiedCookies: [String: String]?
    var executionTime: TimeInterval
    
    init(
        success: Bool,
        output: String = "",
        error: String? = nil,
        modifiedRequest: URLRequest? = nil,
        modifiedResponse: (HTTPURLResponse, Data)? = nil,
        modifiedVariables: [String: String]? = nil,
        modifiedCookies: [String: String]? = nil,
        executionTime: TimeInterval = 0
    ) {
        self.success = success
        self.output = output
        self.error = error
        self.modifiedRequest = modifiedRequest
        self.modifiedResponse = modifiedResponse
        self.modifiedVariables = modifiedVariables
        self.modifiedCookies = modifiedCookies
        self.executionTime = executionTime
    }
}

struct ScriptLog: Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String
    
    enum LogLevel: String {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case debug = "DEBUG"
    }
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel = .info,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}
