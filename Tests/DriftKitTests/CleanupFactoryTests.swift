import XCTest
@testable import DriftKit

final class CleanupFactoryTests: XCTestCase {
    private func makeSettings() -> Settings {
        let suite = "drift-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return Settings(defaults: defaults)
    }

    func testDefaultsToDeterministic() {
        XCTAssertEqual(CleanupFactory.make(settings: makeSettings()).id, "deterministic")
    }

    func testSelectsProviderByID() {
        for id in ["none", "openai", "ollama", "deterministic"] {
            let s = makeSettings()
            s.cleanupProviderID = id
            XCTAssertEqual(CleanupFactory.make(settings: s).id, id)
        }
    }

    func testProviderNetworkFlags() {
        let s = makeSettings()
        s.cleanupProviderID = "openai"
        XCTAssertTrue(CleanupFactory.make(settings: s).requiresNetwork)
        s.cleanupProviderID = "deterministic"
        XCTAssertFalse(CleanupFactory.make(settings: s).requiresNetwork)
    }

    func testLanguageRoundTrip() {
        let s = makeSettings()
        s.language = .malayalam
        XCTAssertEqual(s.language, .malayalam)
        XCTAssertEqual(s.languageCode, "ml")
    }

    func testDefaultModelIsTurbo() {
        XCTAssertEqual(makeSettings().modelVariant, "openai_whisper-large-v3-v20240930")
    }
}
