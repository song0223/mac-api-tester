# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build only
swift build

# Build, package as .app bundle, and launch
./script/build_and_run.sh

# Debug mode (launches under lldb)
./script/build_and_run.sh --debug

# Run tests
swift test

# Run a single test class
swift test --filter MacAPITesterTests.DocGeneratorTests
```

Requires macOS 14+ and MySQL 8.0 (via Homebrew). MySQL must be running locally for data persistence; otherwise the app falls back to in-memory storage.

## Architecture

A native macOS API testing tool (similar to Postman) built with **SwiftUI** and **Swift Package Manager** (Swift 6, strict concurrency).

### Data Flow

App entry: `MacAPITesterApp` → `AppContainer` (single-window NavigationSplitView)

`AppContainer` is the central coordinator — it owns all state (projects, requests, responses, history) and wires together every feature view. There is no view model layer; SwiftUI bindings drive state directly.

### Core Layer (`Sources/MacAPITester/Core/`)

- **Domain/** — `Models.swift` defines all core types: `RequestProject`, `RequestDocument`, `APIRequestDraft`, `RequestAuthConfiguration`, `HTTPMethod`. `TemplateRenderer` handles `{{variable}}` substitution. `AuthInjector` applies auth config to requests.
- **Networking/** — `HTTPClient` sends `URLRequest` via `URLSession`. `RequestBuilder` converts `APIRequestDraft` into `URLRequest`.
- **Storage/** — `SQLiteDatabase` (SQLite3 C API) and `MySQLDatabase` (CMySQL system library) for persistence. `Repositories.swift` contains both SQLite and MySQL repository classes. MySQL is primary; SQLite is available as fallback.
- **Database/** — `MySQLDatabase` manages MySQL connections. `DatabaseMigration` handles schema migrations.
- **Cookies/** — `CookieManager` / `CookieStorage` for HTTP cookie management.
- **Scripts/** — `ScriptEngine` for user-defined pre/post-request scripts.
- **TestCases/** — `TestCaseManager` and `TestRunner` for API test case execution.
- **DocServer/** — Built on **SwiftNIO** (`NIOHTTP1`). `DocServer` runs an HTTP server (default port 8088) that serves auto-generated API documentation. `DocGenerator` builds doc models from projects/requests, `HTMLRenderer` renders them, `DocRepository` persists to MySQL.
- **ImportExport/** — `BodyImporterExporter` for request body import/export.

### Features Layer (`Sources/MacAPITester/Features/`)

SwiftUI views, one folder per feature: `Collections`, `RequestEditor`, `ResponseViewer`, `CookiesEditor`, `ScriptEditor`, `TestCaseEditor`, `DocServer`, `ImportExport`.

### Key Dependencies

- **swift-nio** — HTTP server for the documentation feature only
- **CMySQL** — System library wrapper (`Sources/CMySQL/`), links against `mysqlclient` from Homebrew
- **SQLite3** — Linked via system library

## Tests

Tests are in `Tests/MacAPITesterTests/`. Most test files correspond 1:1 with Core modules (e.g., `DocGeneratorTests.swift` tests `DocGenerator`, `StorageTests.swift` tests repositories). The MySQL-dependent tests require a running MySQL instance.
