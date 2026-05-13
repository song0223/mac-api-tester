import Foundation

/// 集中管理所有 sheet 的路由枚举
enum SheetDestination: Identifiable, Hashable {
    case cookiesEditor
    case scriptEditor
    case testCaseEditor(requestID: UUID)
    case docServerSettings
    case environmentEditor
    case curlImport
    case history
    case databaseSettings

    var id: String {
        switch self {
        case .cookiesEditor:
            return "cookiesEditor"
        case .scriptEditor:
            return "scriptEditor"
        case .testCaseEditor:
            return "testCaseEditor"
        case .docServerSettings:
            return "docServerSettings"
        case .environmentEditor:
            return "environmentEditor"
        case .curlImport:
            return "curlImport"
        case .history:
            return "history"
        case .databaseSettings:
            return "databaseSettings"
        }
    }

    // Hashable 实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SheetDestination, rhs: SheetDestination) -> Bool {
        lhs.id == rhs.id
    }
}
