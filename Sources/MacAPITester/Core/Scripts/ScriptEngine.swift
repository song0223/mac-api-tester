import Foundation
import JavaScriptCore

protocol ScriptEngineProtocol {
    func execute(script: String, context: ScriptExecutionContext) throws -> ScriptExecutionResult
}

final class JavaScriptCoreEngine: ScriptEngineProtocol {
    private var logs: [ScriptLog] = []

    func execute(script: String, context: ScriptExecutionContext) throws -> ScriptExecutionResult {
        let startTime = Date()
        logs.removeAll()

        let jsContext = JSContext()

        setupConsole(in: jsContext)
        setupRequest(in: jsContext, context: context)

        if let response = context.response, let body = context.responseBody {
            setupResponse(in: jsContext, response: response, body: body)
        }

        setupVariables(in: jsContext, variables: context.variables)
        setupCookies(in: jsContext, cookies: context.cookies)

        guard let result = jsContext?.evaluateScript(script) else {
            let error = jsContext?.exception?.toString() ?? "脚本执行失败"
            return ScriptExecutionResult(
                success: false,
                error: error,
                executionTime: Date().timeIntervalSince(startTime)
            )
        }

        let modifiedRequest = extractRequest(from: jsContext, original: context.request)
        let modifiedVariables = extractVariables(from: jsContext)
        let modifiedCookies = extractCookies(from: jsContext)

        let output = logs.map { "[\($0.level.rawValue)] \($0.message)" }.joined(separator: "\n")

        return ScriptExecutionResult(
            success: true,
            output: output,
            modifiedRequest: modifiedRequest,
            modifiedVariables: modifiedVariables,
            modifiedCookies: modifiedCookies,
            executionTime: Date().timeIntervalSince(startTime)
        )
    }

    private func setupConsole(in context: JSContext?) {
        let consoleObject = JSValue(newObjectIn: context)

        let logFunction: @convention(block) (String) -> Void = { [weak self] message in
            self?.logs.append(ScriptLog(level: .info, message: message))
        }
        consoleObject?.setObject(logFunction, forKeyedSubscript: "log" as NSString)

        let warnFunction: @convention(block) (String) -> Void = { [weak self] message in
            self?.logs.append(ScriptLog(level: .warning, message: message))
        }
        consoleObject?.setObject(warnFunction, forKeyedSubscript: "warn" as NSString)

        let errorFunction: @convention(block) (String) -> Void = { [weak self] message in
            self?.logs.append(ScriptLog(level: .error, message: message))
        }
        consoleObject?.setObject(errorFunction, forKeyedSubscript: "error" as NSString)

        let debugFunction: @convention(block) (String) -> Void = { [weak self] message in
            self?.logs.append(ScriptLog(level: .debug, message: message))
        }
        consoleObject?.setObject(debugFunction, forKeyedSubscript: "debug" as NSString)

        context?.setObject(consoleObject, forKeyedSubscript: "console" as NSString)
    }

    private func setupRequest(in context: JSContext?, context execContext: ScriptExecutionContext) {
        let requestObject = JSValue(newObjectIn: context)

        requestObject?.setObject(execContext.request.url?.absoluteString ?? "", forKeyedSubscript: "url" as NSString)
        requestObject?.setObject(execContext.request.httpMethod ?? "GET", forKeyedSubscript: "method" as NSString)

        if let headers = execContext.request.allHTTPHeaderFields {
            let headersObject = JSValue(newObjectIn: context)
            for (key, value) in headers {
                headersObject?.setObject(value, forKeyedSubscript: key as NSString)
            }
            requestObject?.setObject(headersObject, forKeyedSubscript: "headers" as NSString)
        }

        if let body = execContext.request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            requestObject?.setObject(bodyString, forKeyedSubscript: "body" as NSString)
        }

        context?.setObject(requestObject, forKeyedSubscript: "request" as NSString)
    }

    private func setupResponse(in context: JSContext?, response: HTTPURLResponse, body: Data) {
        let responseObject = JSValue(newObjectIn: context)

        responseObject?.setObject(response.statusCode, forKeyedSubscript: "statusCode" as NSString)

        let headersObject = JSValue(newObjectIn: context)
        for (key, value) in response.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                headersObject?.setObject(valueString, forKeyedSubscript: keyString as NSString)
            }
        }
        responseObject?.setObject(headersObject, forKeyedSubscript: "headers" as NSString)

        if let bodyString = String(data: body, encoding: .utf8) {
            responseObject?.setObject(bodyString, forKeyedSubscript: "body" as NSString)
        }

        context?.setObject(responseObject, forKeyedSubscript: "response" as NSString)
    }

    private func setupVariables(in context: JSContext?, variables: [String: String]) {
        let variablesObject = JSValue(newObjectIn: context)
        for (key, value) in variables {
            variablesObject?.setObject(value, forKeyedSubscript: key as NSString)
        }
        context?.setObject(variablesObject, forKeyedSubscript: "variables" as NSString)
    }

    private func setupCookies(in context: JSContext?, cookies: [String: String]) {
        let cookiesObject = JSValue(newObjectIn: context)
        for (key, value) in cookies {
            cookiesObject?.setObject(value, forKeyedSubscript: key as NSString)
        }
        context?.setObject(cookiesObject, forKeyedSubscript: "cookies" as NSString)
    }

    private func extractRequest(from context: JSContext?, original: URLRequest) -> URLRequest? {
        guard let requestObject = context?.objectForKeyedSubscript("request") else {
            return nil
        }

        var modifiedRequest = original

        if let urlString = requestObject.objectForKeyedSubscript("url")?.toString(),
           let url = URL(string: urlString) {
            modifiedRequest.url = url
        }

        if let method = requestObject.objectForKeyedSubscript("method")?.toString() {
            modifiedRequest.httpMethod = method
        }

        if let headersObject = requestObject.objectForKeyedSubscript("headers")?.toDictionary() as? [String: String] {
            modifiedRequest.allHTTPHeaderFields = headersObject
        }

        if let body = requestObject.objectForKeyedSubscript("body")?.toString() {
            modifiedRequest.httpBody = body.data(using: .utf8)
        }

        return modifiedRequest
    }

    private func extractVariables(from context: JSContext?) -> [String: String]? {
        guard let variablesObject = context?.objectForKeyedSubscript("variables")?.toDictionary() as? [String: String] else {
            return nil
        }
        return variablesObject
    }

    private func extractCookies(from context: JSContext?) -> [String: String]? {
        guard let cookiesObject = context?.objectForKeyedSubscript("cookies")?.toDictionary() as? [String: String] else {
            return nil
        }
        return cookiesObject
    }
}

final class ScriptEngine {
    private let javaScriptCoreEngine = JavaScriptCoreEngine()

    func execute(script: Script, context: ScriptExecutionContext) throws -> ScriptExecutionResult {
        guard script.isEnabled else {
            return ScriptExecutionResult(success: true, output: "脚本已禁用")
        }

        switch script.engine {
        case .javaScriptCore:
            return try javaScriptCoreEngine.execute(script: script.content, context: context)
        case .quickJS:
            throw ScriptError.engineNotSupported("QuickJS引擎暂未实现")
        }
    }

    func executeScripts(_ scripts: [Script], context: ScriptExecutionContext) throws -> ScriptExecutionResult {
        let sortedScripts = scripts
            .filter { $0.isEnabled }
            .sorted { $0.executionOrder < $1.executionOrder }

        var currentContext = context
        var combinedOutput = ""

        for script in sortedScripts {
            let result = try execute(script: script, context: currentContext)

            if !result.success {
                return result
            }

            combinedOutput += result.output + "\n"

            if let modifiedRequest = result.modifiedRequest {
                currentContext.request = modifiedRequest
            }

            if let modifiedVariables = result.modifiedVariables {
                currentContext.variables = modifiedVariables
            }

            if let modifiedCookies = result.modifiedCookies {
                currentContext.cookies = modifiedCookies
            }
        }

        return ScriptExecutionResult(
            success: true,
            output: combinedOutput,
            modifiedRequest: currentContext.request,
            modifiedVariables: currentContext.variables,
            modifiedCookies: currentContext.cookies
        )
    }
}

enum ScriptError: Error, LocalizedError {
    case engineNotSupported(String)
    case compilationError(String)
    case runtimeError(String)

    var errorDescription: String? {
        switch self {
        case .engineNotSupported(let message):
            return "引擎不支持: \(message)"
        case .compilationError(let message):
            return "编译错误: \(message)"
        case .runtimeError(let message):
            return "运行时错误: \(message)"
        }
    }
}
