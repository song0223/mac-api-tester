import Foundation

@Observable
@MainActor
final class HistoryStore {
    var historyItems: [RequestHistoryItem] = []
    var historySearchText = ""

    // 历史记录持久化
    var historyPersistence: HistoryPersistence

    init() {
        self.historyPersistence = HistoryPersistence.inMemory
    }

    init(database: MySQLDatabase) {
        self.historyPersistence = HistoryPersistence(database: database)
    }

    // MARK: - 历史记录操作

    func loadHistoryIfNeeded() {
        loadHistory()
    }

    func loadHistory() {
        let search = historySearchText.isEmpty ? nil : historySearchText
        historyItems = historyPersistence.loadItems(search: search)
    }

    func persistHistory(
        for requestDocument: RequestDocument,
        request: URLRequest,
        response: RequestResponseSnapshot
    ) {
        let message = historyMessage(for: requestDocument, request: request, response: response)
        historyPersistence.save(message: message, createdAt: response.timestamp)
        loadHistory()
    }

    private func historyMessage(
        for requestDocument: RequestDocument,
        request: URLRequest,
        response: RequestResponseSnapshot
    ) -> String {
        let urlText = request.url?.absoluteString ?? requestDocument.urlString
        let milliseconds = Int((response.duration * 1000).rounded())
        return "\(requestDocument.method.rawValue) \(urlText) -> \(response.statusCode) (\(milliseconds) ms)"
    }
}
