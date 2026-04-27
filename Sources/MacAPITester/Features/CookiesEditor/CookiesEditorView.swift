import SwiftUI
import UniformTypeIdentifiers

struct CookiesEditorView: View {
    @Binding var cookieJar: CookieJar
    let onImport: (Data) -> Void
    let onExport: () -> Data?

    @State private var selectedCookieID: HTTPCookie.ID?
    @State private var isEditing = false
    @State private var editingCookie = HTTPCookie(domain: "", name: "", value: "")
    @State private var searchText = ""
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var exportData: Data?

    var filteredCookies: [HTTPCookie] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return cookieJar.cookies }
        return cookieJar.cookies.filter {
            $0.domain.localizedCaseInsensitiveContains(keyword) ||
            $0.name.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            cookieList
            Divider()
            footer
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private var header: some View {
        HStack {
            Text("Cookies管理")
                .font(.headline)

            Spacer()

            TextField("搜索", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            Button("清除过期") {
                cookieJar.removeExpiredCookies()
            }
            .buttonStyle(.bordered)

            Button("清空全部") {
                cookieJar = CookieJar()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding()
    }

    private var cookieList: some View {
        List(selection: $selectedCookieID) {
            ForEach(filteredCookies) { cookie in
                CookieRow(cookie: cookie)
                    .tag(cookie.id)
                    .contextMenu {
                        Button("编辑") {
                            editingCookie = cookie
                            isEditing = true
                        }
                        Button("删除", role: .destructive) {
                            cookieJar.removeCookie(id: cookie.id)
                        }
                    }
            }
        }
        .listStyle(.inset)
    }

    private var footer: some View {
        HStack {
            Button("导入") {
                showingImportPicker = true
            }
            .buttonStyle(.bordered)

            Button("导出") {
                if let data = onExport() {
                    exportData = data
                    showingExportPicker = true
                }
            }
            .buttonStyle(.bordered)
            .disabled(onExport() == nil)

            Spacer()

            Button("添加Cookie") {
                editingCookie = HTTPCookie(domain: "", name: "", value: "")
                isEditing = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .sheet(isPresented: $isEditing) {
            CookieEditSheet(
                cookie: $editingCookie,
                onSave: { cookie in
                    cookieJar.addCookie(cookie)
                    isEditing = false
                },
                onCancel: {
                    isEditing = false
                }
            )
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json]
        ) { result in
            if case .success(let url) = result {
                if let data = try? Data(contentsOf: url) {
                    onImport(data)
                }
            }
        }
        .fileExporter(
            isPresented: $showingExportPicker,
            document: CookieDocument(data: exportData),
            contentType: .json
        ) { _ in }
    }
}

struct CookieRow: View {
    let cookie: HTTPCookie

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(cookie.name)
                    .font(.headline)
                Text(cookie.domain)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(cookie.value)
                .font(.caption)
                .lineLimit(1)

            if cookie.isExpired {
                Text("已过期")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CookieEditSheet: View {
    @Binding var cookie: HTTPCookie
    let onSave: (HTTPCookie) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("编辑Cookie")
                .font(.headline)

            Form {
                TextField("域名", text: $cookie.domain)
                TextField("路径", text: $cookie.path)
                TextField("名称", text: $cookie.name)
                TextField("值", text: $cookie.value)
                DatePicker(
                    "过期时间",
                    selection: Binding(
                        get: { cookie.expiresDate ?? Date() },
                        set: { cookie.expiresDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                Toggle("Secure", isOn: $cookie.isSecure)
                Toggle("HTTP Only", isOn: $cookie.isHTTPOnly)
                Picker("SameSite", selection: $cookie.sameSite) {
                    ForEach(HTTPCookie.SameSitePolicy.allCases) { policy in
                        Text(policy.rawValue).tag(policy)
                    }
                }
            }

            HStack {
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("保存") {
                    onSave(cookie)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct CookieDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data?

    init(data: Data?) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data ?? Data())
    }
}
