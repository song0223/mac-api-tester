import SwiftUI
import UniformTypeIdentifiers

private enum RequestParamTab: String, CaseIterable, Identifiable {
    case body = "Body"
    case query = "Query"
    case headers = "Headers"
    case auth = "认证"
    case cookies = "Cookies"
    case preScript = "前执行脚本"
    case postScript = "后执行脚本"
    case examples = "用例"

    var id: String { rawValue }
}

private enum BodyMode: String, CaseIterable, Identifiable {
    case formData = "form-data"
    case urlEncoded = "x-www-form-urlencoded"
    case raw = "raw"

    var id: String { rawValue }
}

private struct BodyParamRow: Identifiable, Equatable {
    let id: UUID
    var enabled: Bool
    var name: String
    var value: String
    var type: String
    var required: Bool
    var description: String

    init(
        id: UUID = UUID(),
        enabled: Bool = true,
        name: String = "",
        value: String = "",
        type: String = "string",
        required: Bool = false,
        description: String = ""
    ) {
        self.id = id
        self.enabled = enabled
        self.name = name
        self.value = value
        self.type = type
        self.required = required
        self.description = description
    }
}

private struct QueryParamRow: Identifiable, Equatable {
    let id: UUID
    var enabled: Bool
    var name: String
    var value: String
    var required: Bool
    var description: String

    init(
        id: UUID = UUID(),
        enabled: Bool = true,
        name: String = "",
        value: String = "",
        required: Bool = false,
        description: String = ""
    ) {
        self.id = id
        self.enabled = enabled
        self.name = name
        self.value = value
        self.required = required
        self.description = description
    }
}

private struct HeaderParamRow: Identifiable, Equatable {
    let id: UUID
    var enabled: Bool
    var name: String
    var value: String

    init(id: UUID = UUID(), enabled: Bool = true, name: String = "", value: String = "") {
        self.id = id
        self.enabled = enabled
        self.name = name
        self.value = value
    }
}

struct RequestEditorView: View {
    @Binding var request: RequestDocument
    let isSending: Bool
    let errorMessage: String?
    let onSend: () -> Void
    let showInlineRunButton: Bool

    @State private var selectedTab: RequestParamTab = .body
    @State private var bodyMode: BodyMode = .formData
    @State private var bodyRows: [BodyParamRow] = [BodyParamRow()]
    @State private var queryRows: [QueryParamRow] = [QueryParamRow()]
    @State private var headerRows: [HeaderParamRow] = [HeaderParamRow()]
    @State private var syncingFromRequest = false
    @State private var draggingBodyRowID: UUID?
    @State private var draggingQueryRowID: UUID?
    @State private var draggingHeaderRowID: UUID?
    @State private var showingImportExport = false
    private let panelBackground = Color(red: 249 / 255, green: 249 / 255, blue: 249 / 255)

    init(
        request: Binding<RequestDocument>,
        isSending: Bool,
        errorMessage: String?,
        onSend: @escaping () -> Void,
        showInlineRunButton: Bool = true
    ) {
        _request = request
        self.isSending = isSending
        self.errorMessage = errorMessage
        self.onSend = onSend
        self.showInlineRunButton = showInlineRunButton
    }

    var body: some View {
        VStack(spacing: 4) {
            requestTopBar
            requestParamsPanel
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(panelBackground)
        .onAppear(perform: syncRowsFromRequest)
        .onChange(of: request.id) { _, _ in
            syncRowsFromRequest()
        }
        .onChange(of: bodyRows) { _, _ in
            guard !syncingFromRequest else { return }
            request.bodyText = serializeBodyRows(bodyRows)
        }
        .onChange(of: queryRows) { _, _ in
            guard !syncingFromRequest else { return }
            request.queryText = serializeQueryRows(queryRows)
        }
        .onChange(of: headerRows) { _, _ in
            guard !syncingFromRequest else { return }
            request.headersText = serializeHeaderRows(headerRows)
        }
        .sheet(isPresented: $showingImportExport) {
            ImportExportView(
                parameters: Binding(
                    get: {
                        bodyRows.map {
                            BodyParameter(
                                name: $0.name,
                                value: $0.value,
                                type: $0.type,
                                required: $0.required,
                                description: $0.description
                            )
                        }
                    },
                    set: { newParams in
                        bodyRows = newParams.map {
                            BodyParamRow(
                                name: $0.name,
                                value: $0.value,
                                type: $0.type,
                                required: $0.required,
                                description: $0.description
                            )
                        }
                        if bodyRows.isEmpty {
                            bodyRows = [BodyParamRow()]
                        }
                    }
                ),
                bodyMode: Binding(
                    get: { bodyMode.rawValue },
                    set: { newMode in
                        if let mode = BodyMode(rawValue: newMode) {
                            bodyMode = mode
                        }
                    }
                ),
                rawData: $request.bodyText
            )
        }
    }

    private var requestTopBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Menu {
                    ForEach(HTTPMethod.allCases) { method in
                        Button(method.rawValue) {
                            request.method = method
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(request.method.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(request.method == .post ? Color.orange.opacity(0.2) : Color.green.opacity(0.2), in: Capsule())
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(width: 100, height: 40, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 24)

                TextField("https://api.example.com/path", text: $request.urlString)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)

                if showInlineRunButton {
                    Button(action: onSend) {
                        if isSending {
                            ProgressView().controlSize(.small).frame(width: 72)
                        } else {
                            Text("运行调试").frame(width: 72)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSending || request.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .background(
                Color(red: 244 / 255, green: 244 / 255, blue: 244 / 255),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(4)
    }

    private var requestParamsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("请求参数")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            HStack(spacing: 20) {
                ForEach(RequestParamTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                            Rectangle()
                                .fill(selectedTab == tab ? Color.black.opacity(0.72) : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(minWidth: 72, minHeight: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()

            Group {
                switch selectedTab {
                case .body:
                    bodyTablePanel
                case .query:
                    queryTablePanel
                case .headers:
                    headersTablePanel
                case .auth:
                    authPanel
                case .cookies, .preScript, .postScript, .examples:
                    unsupportedTabPanel(title: selectedTab.rawValue)
                }
            }
            .padding(12)

            if showInlineRunButton {
                Divider()
                HStack {
                    Spacer()
                    Button(action: onSend) {
                        if isSending {
                            ProgressView().controlSize(.small).frame(width: 92)
                        } else {
                            Text("运行调试").frame(width: 92)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSending || request.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var bodyTablePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $bodyMode) {
                ForEach(BodyMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 180)

            if bodyMode == .raw {
                textEditorPanel(
                    prompt: "Raw Body",
                    text: $request.bodyText,
                    placeholder: #"{"name":"demo"}"#
                )
            } else {
                tableScaffold {
                    HStack(spacing: 0) {
                        tableHeaderCell("状态", width: 70)
                        tableHeaderFlexibleCell("参数名")
                        tableHeaderFlexibleCell("参数值")
                        tableHeaderCell("类型", width: 90)
                        tableHeaderCell("必填", width: 80)
                        tableHeaderFlexibleCell("参数描述")
                        tableHeaderCell("操作", width: 110)
                    }
                    .frame(height: 38)
                    .background(Color.black.opacity(0.02))

                    ForEach($bodyRows) { $row in
                        HStack(spacing: 0) {
                            tableCell(width: 70) {
                                Toggle("", isOn: $row.enabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .scaleEffect(0.8)
                            }
                            tableFlexibleCell {
                                TextField("", text: $row.name)
                                    .textFieldStyle(.plain)
                            }
                            tableFlexibleCell {
                                TextField("", text: $row.value)
                                    .textFieldStyle(.plain)
                            }
                            tableCell(width: 90) {
                                Picker("", selection: $row.type) {
                                    Text("string").tag("string")
                                    Text("number").tag("number")
                                    Text("boolean").tag("boolean")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                            tableCell(width: 80) {
                                Toggle("", isOn: $row.required)
                                    .labelsHidden()
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                            }
                            tableFlexibleCell {
                                TextField("(选填) 请输入详细的描述", text: $row.description)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(.secondary)
                            }
                            tableCell(width: 110) {
                                rowActions(
                                    onDelete: { removeBodyRow(row.id) },
                                    onDrag: { startBodyRowDrag(row.id) }
                                )
                            }
                        }
                        .frame(height: 46)
                        .overlay(Divider(), alignment: .bottom)
                        .onDrop(
                            of: [UTType.text],
                            delegate: ReorderDropDelegate(
                                targetID: row.id,
                                rows: $bodyRows,
                                draggingID: $draggingBodyRowID
                            )
                        )
                    }
                }

                HStack {
                    Spacer()
                    Button("导入导出") {
                        showingImportExport = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    Button {
                        bodyRows.append(BodyParamRow())
                    } label: {
                        Label("增加行", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 13, weight: .medium))
            }
        }
    }

    private var queryTablePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            tableScaffold {
                HStack(spacing: 0) {
                    tableHeaderCell("状态", width: 70)
                    tableHeaderFlexibleCell("参数名")
                    tableHeaderFlexibleCell("参数值")
                    tableHeaderCell("必填", width: 80)
                    tableHeaderFlexibleCell("参数描述")
                    tableHeaderCell("操作", width: 110)
                }
                .frame(height: 38)
                .background(Color.black.opacity(0.02))

                ForEach($queryRows) { $row in
                    HStack(spacing: 0) {
                        tableCell(width: 70) {
                            Toggle("", isOn: $row.enabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                        }
                        tableFlexibleCell {
                            TextField("key", text: $row.name)
                                .textFieldStyle(.plain)
                        }
                        tableFlexibleCell {
                            TextField("value", text: $row.value)
                                .textFieldStyle(.plain)
                        }
                        tableCell(width: 80) {
                            Toggle("", isOn: $row.required)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                        }
                        tableFlexibleCell {
                            TextField("(选填) 参数说明", text: $row.description)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.secondary)
                        }
                        tableCell(width: 110) {
                            rowActions(
                                onDelete: { removeQueryRow(row.id) },
                                onDrag: { startQueryRowDrag(row.id) }
                            )
                        }
                    }
                    .frame(height: 46)
                    .overlay(Divider(), alignment: .bottom)
                    .onDrop(
                        of: [UTType.text],
                        delegate: ReorderDropDelegate(
                            targetID: row.id,
                            rows: $queryRows,
                            draggingID: $draggingQueryRowID
                        )
                    )
                }
            }

            HStack {
                Spacer()
                Button {
                    queryRows.append(QueryParamRow())
                } label: {
                    Label("增加行", systemImage: "plus")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 13, weight: .medium))
        }
    }

    private var headersTablePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            tableScaffold {
                HStack(spacing: 0) {
                    tableHeaderCell("状态", width: 70)
                    tableHeaderFlexibleCell("参数名")
                    tableHeaderFlexibleCell("参数值")
                    tableHeaderCell("操作", width: 100)
                }
                .frame(height: 38)
                .background(Color.black.opacity(0.02))

                ForEach($headerRows) { $row in
                    HStack(spacing: 0) {
                        tableCell(width: 70) {
                            Toggle("", isOn: $row.enabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                        }
                        tableFlexibleCell {
                            TextField("Header 名，例如 Authorization", text: $row.name)
                                .textFieldStyle(.plain)
                        }
                        tableFlexibleCell {
                            TextField("Header 值", text: $row.value)
                                .textFieldStyle(.plain)
                        }
                        tableCell(width: 100) {
                            rowActions(
                                onDelete: { removeHeaderRow(row.id) },
                                onDrag: { startHeaderRowDrag(row.id) }
                            )
                        }
                    }
                    .frame(height: 46)
                    .overlay(Divider(), alignment: .bottom)
                    .onDrop(
                        of: [UTType.text],
                        delegate: ReorderDropDelegate(
                            targetID: row.id,
                            rows: $headerRows,
                            draggingID: $draggingHeaderRowID
                        )
                    )
                }
            }

            HStack {
                Spacer()
                Button {
                    headerRows.append(HeaderParamRow())
                } label: {
                    Label("增加行", systemImage: "plus")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 13, weight: .medium))
        }
    }

    private func tableScaffold<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func rowActions(onDelete: @escaping () -> Void, onDrag: @escaping () -> NSItemProvider) -> some View {
        HStack(spacing: 14) {
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .onDrag(onDrag)
        }
    }

    private func tableHeaderCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, height: 38)
            .overlay(Divider(), alignment: .trailing)
    }

    private func tableCell<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .frame(width: width, height: 46, alignment: .leading)
            .overlay(Divider(), alignment: .trailing)
    }

    private func tableHeaderFlexibleCell(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38)
            .overlay(Divider(), alignment: .trailing)
    }

    private func tableFlexibleCell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 46, alignment: .leading)
            .overlay(Divider(), alignment: .trailing)
    }

    private var authPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Auth", selection: $request.auth.type) {
                ForEach(RequestAuthType.allCases) { authType in
                    Text(authType.rawValue).tag(authType)
                }
            }
            .pickerStyle(.segmented)

            switch request.auth.type {
            case .none:
                Text("不附带鉴权信息")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .bearer:
                TextField("Bearer Token", text: $request.auth.bearerToken)
                    .textFieldStyle(.roundedBorder)
            case .basic:
                TextField("Username", text: $request.auth.basicUsername)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $request.auth.basicPassword)
                    .textFieldStyle(.roundedBorder)
            case .apiKey:
                TextField("Header Name", text: $request.auth.apiKeyHeader)
                    .textFieldStyle(.roundedBorder)
                TextField("Header Value", text: $request.auth.apiKeyValue)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func unsupportedTabPanel(title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) 暂未开放编辑")
                .font(.headline)
            Text("当前版本先聚焦接口调试主流程，后续可继续扩展。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
    }

    private func syncRowsFromRequest() {
        syncingFromRequest = true
        defer { syncingFromRequest = false }

        let parsedBody = parseBodyRows(from: request.bodyText)
        bodyRows = parsedBody.isEmpty ? [BodyParamRow()] : parsedBody

        let parsedQuery = parseQueryRows(from: request.queryText)
        queryRows = parsedQuery.isEmpty ? [QueryParamRow()] : parsedQuery

        let parsedHeaders = parseHeaderRows(from: request.headersText)
        headerRows = parsedHeaders.isEmpty ? [HeaderParamRow()] : parsedHeaders
    }

    private func removeBodyRow(_ id: UUID) {
        bodyRows.removeAll(where: { $0.id == id })
        if bodyRows.isEmpty { bodyRows = [BodyParamRow()] }
    }

    private func removeQueryRow(_ id: UUID) {
        queryRows.removeAll(where: { $0.id == id })
        if queryRows.isEmpty { queryRows = [QueryParamRow()] }
    }

    private func removeHeaderRow(_ id: UUID) {
        headerRows.removeAll(where: { $0.id == id })
        if headerRows.isEmpty { headerRows = [HeaderParamRow()] }
    }

    private func startBodyRowDrag(_ id: UUID) -> NSItemProvider {
        draggingBodyRowID = id
        return NSItemProvider(object: id.uuidString as NSString)
    }

    private func startQueryRowDrag(_ id: UUID) -> NSItemProvider {
        draggingQueryRowID = id
        return NSItemProvider(object: id.uuidString as NSString)
    }

    private func startHeaderRowDrag(_ id: UUID) -> NSItemProvider {
        draggingHeaderRowID = id
        return NSItemProvider(object: id.uuidString as NSString)
    }

    private func parseBodyRows(from text: String) -> [BodyParamRow] {
        parseKeyValueLines(text, separators: ["="]).map { BodyParamRow(name: $0.key, value: $0.value) }
    }

    private func parseQueryRows(from text: String) -> [QueryParamRow] {
        parseKeyValueLines(text, separators: ["="]).map { QueryParamRow(name: $0.key, value: $0.value) }
    }

    private func parseHeaderRows(from text: String) -> [HeaderParamRow] {
        parseKeyValueLines(text, separators: [":", "="]).map { HeaderParamRow(name: $0.key, value: $0.value) }
    }

    private func parseKeyValueLines(_ text: String, separators: [Character]) -> [(key: String, value: String)] {
        text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { rawLine in
                let line = String(rawLine)
                guard let separatorIndex = line.firstIndex(where: { separators.contains($0) }) else {
                    return nil
                }
                let key = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
                let valueStart = line.index(after: separatorIndex)
                let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty else { return nil }
                return (key, value)
        }
    }

    private func textEditorPanel(prompt: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prompt)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 180)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func serializeBodyRows(_ rows: [BodyParamRow]) -> String {
        rows
            .filter { $0.enabled && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "\n")
    }

    private func serializeQueryRows(_ rows: [QueryParamRow]) -> String {
        rows
            .filter { $0.enabled && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "\n")
    }

    private func serializeHeaderRows(_ rows: [HeaderParamRow]) -> String {
        rows
            .filter { $0.enabled && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "\($0.name): \($0.value)" }
            .joined(separator: "\n")
    }
}

private struct ReorderDropDelegate<Row: Identifiable>: DropDelegate where Row.ID == UUID {
    let targetID: UUID
    @Binding var rows: [Row]
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != targetID,
              let from = rows.firstIndex(where: { $0.id == draggingID }),
              let to = rows.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.12)) {
            let row = rows.remove(at: from)
            rows.insert(row, at: to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
