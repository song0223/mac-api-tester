import Foundation

enum AppRequestError: Error, Equatable {
    case invalidURL(String)
    case template(TemplateRendererError)
    case timeout
    case offline
    case tls
    case badResponse
}
