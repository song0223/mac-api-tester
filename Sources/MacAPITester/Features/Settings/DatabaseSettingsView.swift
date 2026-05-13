import SwiftUI

struct DatabaseSettingsView: View {
    @Binding var isPresented: Bool
    let onSave: () -> Void

    @State private var host: String = ""
    @State private var port: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var database: String = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("数据库设置")
                .font(.headline)

            Form {
                TextField("主机地址", text: $host)
                TextField("端口", text: $port)
                TextField("用户名", text: $username)
                SecureField("密码", text: $password)
                TextField("数据库名", text: $database)
            }

            if showError {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("保存并重启") {
                    saveConfig()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            loadConfig()
        }
    }

    private func loadConfig() {
        let config = readConfigFile()
        host = config.host
        port = "\(config.port)"
        username = config.username
        password = config.password
        database = config.database
    }

    private func saveConfig() {
        guard let portInt = UInt32(port) else {
            errorMessage = "端口格式错误"
            showError = true
            return
        }

        let config: [String: Any] = [
            "database": [
                "host": host,
                "port": portInt,
                "username": username,
                "password": password,
                "database": database
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) else {
            errorMessage = "配置格式错误"
            showError = true
            return
        }

        let configPath = getConfigPath()
        do {
            try data.write(to: URL(fileURLWithPath: configPath))
            isPresented = false
            onSave()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
            showError = true
        }
    }

    private func readConfigFile() -> (host: String, port: UInt32, username: String, password: String, database: String) {
        var host = "127.0.0.1"
        var port: UInt32 = 3306
        var username = "root"
        var password = ""
        var database = "mac_api_tester"

        let configPath = getConfigPath()
        if let data = FileManager.default.contents(atPath: configPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dbConfig = json["database"] as? [String: Any] {
            host = dbConfig["host"] as? String ?? host
            port = UInt32(dbConfig["port"] as? Int ?? Int(port))
            username = dbConfig["username"] as? String ?? username
            password = dbConfig["password"] as? String ?? password
            database = dbConfig["database"] as? String ?? database
        }

        return (host, port, username, password, database)
    }

    private func getConfigPath() -> String {
        let paths = [
            "config.json",
            "../config.json",
            "../../config.json"
        ]

        for path in paths {
            let fullPath = URL(fileURLWithPath: path).standardized.path
            if FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }
        }

        return "config.json"
    }
}
