import Foundation

struct Environment: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var isActive: Bool
    var variables: [EnvironmentVariable]

    init(
        id: UUID = UUID(),
        name: String = "新环境",
        isActive: Bool = false,
        variables: [EnvironmentVariable] = []
    ) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.variables = variables
    }
}

struct EnvironmentVariable: Equatable, Codable, Identifiable {
    var id: UUID
    var key: String
    var value: String
    var enabled: Bool

    init(
        id: UUID = UUID(),
        key: String = "",
        value: String = "",
        enabled: Bool = true
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.enabled = enabled
    }
}
