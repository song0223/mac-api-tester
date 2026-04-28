import Testing
@testable import MacAPITester

@Suite("Smoke Tests")
struct SmokeTests {
    @Test func appMetadataMatchesBundleContract() {
        #expect(MacAPITesterAppMetadata.appName == "MacAPITester")
        #expect(MacAPITesterAppMetadata.bundleIdentifier == "com.songxiang.MacAPITester")
        #expect(MacAPITesterAppMetadata.bundleExecutable == "MacAPITester")
        #expect(MacAPITesterAppMetadata.minimumSystemVersion == "14.0")
        #expect(MacAPITesterAppMetadata.infoPlist["CFBundlePackageType"] == "APPL")
        #expect(MacAPITesterAppMetadata.infoPlist["NSPrincipalClass"] == "NSApplication")
    }
}
