import Foundation

@Observable
@MainActor
final class EnvironmentStore {
    var environments: [Environment] = []
    var activeEnvironmentID: UUID?

    // 数据库仓库
    var environmentRepository: MySQLEnvironmentRepository?

    init() {}

    // MARK: - 数据库同步

    func syncEnvironmentsToDatabase() {
        guard let environmentRepository else { return }

        do {
            // 获取数据库中现有的环境
            let existingEnvs = try environmentRepository.fetchAllEnvironments()
            let existingEnvIDs = Set(existingEnvs.map { $0.id })
            let currentEnvIDs = Set(environments.map { $0.id.uuidString })

            // 删除不再存在的环境
            for envID in existingEnvIDs where !currentEnvIDs.contains(envID) {
                try environmentRepository.deleteEnvironment(id: envID)
            }

            // 创建或更新环境
            for env in environments {
                let envID = env.id.uuidString
                if existingEnvIDs.contains(envID) {
                    try environmentRepository.updateEnvironment(id: envID, name: env.name, isActive: env.isActive)
                } else {
                    try environmentRepository.createEnvironment(id: envID, name: env.name, isActive: env.isActive)
                }

                // 同步环境变量
                let existingVars = try environmentRepository.fetchVariables(envId: envID)
                let existingVarIDs = Set(existingVars.map { $0.id })
                let currentVarIDs = Set(env.variables.map { $0.id.uuidString })

                // 删除不再存在的变量
                for varID in existingVarIDs where !currentVarIDs.contains(varID) {
                    try environmentRepository.deleteVariable(id: varID)
                }

                // 创建或更新变量
                for variable in env.variables {
                    let varID = variable.id.uuidString
                    if existingVarIDs.contains(varID) {
                        try environmentRepository.updateVariable(id: varID, keyName: variable.key, value: variable.value, enabled: variable.enabled)
                    } else {
                        try environmentRepository.createVariable(id: varID, envId: envID, keyName: variable.key, value: variable.value, enabled: variable.enabled)
                    }
                }
            }
        } catch {
            print("同步环境变量到数据库失败: \(error)")
        }
    }

    // MARK: - 环境变量合并

    func mergeVariables(with requestVariables: [String: String]) -> [String: String] {
        var variables = requestVariables

        // 合并环境变量（环境变量优先级低于请求级变量）
        if let envID = activeEnvironmentID,
           let env = environments.first(where: { $0.id == envID }) {
            for v in env.variables where v.enabled && !v.key.isEmpty {
                if variables[v.key] == nil {
                    variables[v.key] = v.value
                }
            }
        }

        return variables
    }
}
