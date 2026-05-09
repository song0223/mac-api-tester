import AppKit
import SwiftUI

enum MacAPITesterAppMetadata {
    static let appName = "MacAPITester"
    static let bundleIdentifier = "com.songxiang.MacAPITester"
    static let bundleExecutable = "MacAPITester"
    static let minimumSystemVersion = "14.0"

    static let infoPlist: [String: String] = [
        "CFBundleExecutable": bundleExecutable,
        "CFBundleIdentifier": bundleIdentifier,
        "CFBundleName": appName,
        "CFBundlePackageType": "APPL",
        "LSMinimumSystemVersion": minimumSystemVersion,
        "NSPrincipalClass": "NSApplication",
    ]
}

@main
struct MacAPITesterApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            AppContainer()
        }
    }
}
