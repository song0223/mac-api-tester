import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1

/// 文档服务器配置
struct DocServerConfig {
    var port: Int = 8088
    var host: String = "0.0.0.0"
}

/// 文档服务器
final class DocServer {
    let port: Int
    private let host: String
    private let database: MySQLDatabase
    private var channel: Channel?
    private var group: MultiThreadedEventLoopGroup?

    init(port: Int = 8088, host: String = "0.0.0.0", database: MySQLDatabase) {
        self.port = port
        self.host = host
        self.database = database
    }

    /// 启动服务器
    func start() throws {
        group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        guard let group else {
            throw DocServerError.serverStartFailed("无法创建事件循环组")
        }

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [weak self] channel in
                guard let self else {
                    return channel.eventLoop.makeFailedFuture(DocServerError.serverStartFailed("服务器已释放"))
                }

                return channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(database: self.database))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        channel = try bootstrap.bind(host: host, port: port).wait()

        print("📄 文档服务器已启动: http://\(host):\(port)")
    }

    /// 停止服务器
    func stop() {
        try? channel?.close().wait()
        try? group?.syncShutdownGracefully()
        channel = nil
        group = nil

        print("📄 文档服务器已停止")
    }

    /// 获取访问地址
    var accessURL: String {
        "http://localhost:\(port)"
    }

    /// 获取局域网访问地址
    var localNetworkURL: String? {
        getLocalIPAddress().map { "http://\($0):\(port)" }
    }

    /// 获取本地 IP 地址
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = withUnsafePointer(to: hostname[0]) {
                        String(validatingCString: $0)
                    }
                }
            }
        }

        freeifaddrs(ifaddr)
        return address
    }
}

/// HTTP 请求处理器
final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let database: MySQLDatabase

    init(database: MySQLDatabase) {
        self.database = database
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)

        switch reqPart {
        case .head(let request):
            handleRequest(request: request, context: context)
        case .body:
            break
        case .end:
            break
        }
    }

    private func handleRequest(request: HTTPRequestHead, context: ChannelHandlerContext) {
        let path = request.uri

        if path == "/" || path == "/index.html" {
            serveIndexPage(context: context)
        } else if path.hasPrefix("/doc/") {
            let projectID = String(path.dropFirst(5))
            serveDocumentPage(projectID: projectID, context: context)
        } else {
            serve404(context: context)
        }
    }

    private func serveIndexPage(context: ChannelHandlerContext) {
        do {
            let repository = try DocRepository(database: database)
            let documents = try repository.fetchAllDocuments()

            var html = """
            <!DOCTYPE html>
            <html lang="zh-CN">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>API文档中心</title>
                <style>
                    body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 0 auto; padding: 40px; }
                    h1 { color: #333; }
                    .doc-list { list-style: none; padding: 0; }
                    .doc-item { margin: 16px 0; padding: 16px; background: #f5f5f5; border-radius: 8px; }
                    .doc-item a { color: #0066cc; text-decoration: none; font-size: 18px; }
                    .doc-item a:hover { text-decoration: underline; }
                </style>
            </head>
            <body>
                <h1>📚 API文档中心</h1>
                <ul class="doc-list">
            """

            for doc in documents {
                html += """
                    <li class="doc-item">
                        <a href="/doc/\(doc.projectID)">\(doc.title)</a>
                    </li>
                """
            }

            html += """
                </ul>
            </body>
            </html>
            """

            sendResponse(html: html, context: context)
        } catch {
            sendResponse(html: "<h1>服务器错误</h1>", status: .internalServerError, context: context)
        }
    }

    private func serveDocumentPage(projectID: String, context: ChannelHandlerContext) {
        do {
            let repository = try DocRepository(database: database)

            if let document = try repository.fetchDocument(projectID: projectID) {
                // Wrap with back button
                let html = wrapWithBackButton(document.htmlContent, title: document.title)
                sendResponse(html: html, context: context)
            } else {
                sendResponse(html: "<h1>文档不存在</h1>", status: .notFound, context: context)
            }
        } catch {
            sendResponse(html: "<h1>服务器错误</h1>", status: .internalServerError, context: context)
        }
    }

    private func wrapWithBackButton(_ html: String, title: String) -> String {
        // If it's already a full HTML page, add a back button inside
        if html.contains("<html") {
            // Insert back button after <body>
            return html.replacingOccurrences(
                of: "<body>",
                with: """
                <body>
                <div style="position:fixed;top:0;left:0;right:0;z-index:1000;background:#fff;border-bottom:1px solid #e0e0e0;padding:10px 20px;display:flex;align-items:center;gap:12px;">
                    <a href="/" style="color:#0066cc;text-decoration:none;font-size:14px;">← 返回首页</a>
                    <span style="color:#666;font-size:14px;">\(title)</span>
                </div>
                <div style="margin-top:50px;">
                """
            )
        }
        // If it's just a fragment, wrap it with a full page
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <style>
                body { font-family: -apple-system, sans-serif; margin: 0; padding: 0; }
                .nav-bar { position: fixed; top: 0; left: 0; right: 0; z-index: 1000; background: #fff; border-bottom: 1px solid #e0e0e0; padding: 10px 20px; display: flex; align-items: center; gap: 12px; }
                .nav-bar a { color: #0066cc; text-decoration: none; font-size: 14px; }
                .nav-bar a:hover { text-decoration: underline; }
                .nav-bar span { color: #666; font-size: 14px; }
                .content { margin-top: 50px; padding: 20px; }
            </style>
        </head>
        <body>
            <div class="nav-bar">
                <a href="/">← 返回首页</a>
                <span>\(title)</span>
            </div>
            <div class="content">
                \(html)
            </div>
        </body>
        </html>
        """
    }

    private func serve404(context: ChannelHandlerContext) {
        sendResponse(html: "<h1>404 - 页面不存在</h1>", status: .notFound, context: context)
    }

    private func sendResponse(html: String, status: HTTPResponseStatus = .ok, context: ChannelHandlerContext) {
        let body = ByteBuffer(string: html)

        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/html; charset=utf-8")
        headers.add(name: "Content-Length", value: "\(body.readableBytes)")

        let responseHead = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(responseHead)), promise: nil)

        let bodyPart = HTTPServerResponsePart.body(.byteBuffer(body))
        context.write(wrapOutboundOut(bodyPart), promise: nil)

        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}

/// 服务器错误
enum DocServerError: Error {
    case serverStartFailed(String)
}
