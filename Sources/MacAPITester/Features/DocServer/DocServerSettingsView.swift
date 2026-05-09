import SwiftUI

/// 文档服务器设置视图
struct DocServerSettingsView: View {
    @Binding var isPresented: Bool
    let server: DocServer?
    let onRestart: (Int) -> Void

    @State private var port: String = "8088"
    @State private var isRunning: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("文档服务器设置")
                .font(.headline)

            Form {
                HStack {
                    Text("端口:")
                    TextField("端口号", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                HStack {
                    Text("状态:")
                    Circle()
                        .fill(isRunning ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    Text(isRunning ? "运行中" : "已停止")
                }

                if let server, isRunning {
                    HStack {
                        Text("访问地址:")
                        Text(server.accessURL)
                            .foregroundStyle(.blue)
                    }

                    if let localURL = server.localNetworkURL {
                        HStack {
                            Text("局域网地址:")
                            Text(localURL)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isRunning ? "重启" : "启动") {
                    if let portInt = Int(port) {
                        onRestart(portInt)
                        isRunning = true
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            isRunning = server != nil
            if let server {
                port = "\(server.port)"
            }
        }
    }
}
