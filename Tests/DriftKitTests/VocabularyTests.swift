import XCTest
@testable import DriftKit

final class VocabularyTests: XCTestCase {
    private func makeSettings() -> Settings {
        let suite = "drift-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return Settings(defaults: defaults)
    }

    func testParseSplitsLinesAndCommas() {
        let terms = Vocabulary.parse("Karan Johar\nAishwarya Rai, Bengaluru")
        XCTAssertEqual(terms, ["Karan Johar", "Aishwarya Rai", "Bengaluru"])
    }

    func testParseTrimsAndDropsBlanks() {
        let terms = Vocabulary.parse("  Karan Johar  \n\n , \n Rai ")
        XCTAssertEqual(terms, ["Karan Johar", "Rai"])
    }

    func testParseDedupesCaseInsensitivelyKeepingFirst() {
        let terms = Vocabulary.parse("Karan Johar\nkaran johar\nRai")
        XCTAssertEqual(terms, ["Karan Johar", "Rai"])
    }

    func testWhisperPromptJoinsTermsAndCapsCount() {
        XCTAssertNil(Vocabulary.whisperPrompt(terms: []))
        XCTAssertEqual(
            Vocabulary.whisperPrompt(terms: ["Karan Johar", "Rai"]),
            "Karan Johar, Rai"
        )
        let many = (0..<100).map { "Term\($0)" }
        let prompt = Vocabulary.whisperPrompt(terms: many)!
        XCTAssertEqual(prompt.components(separatedBy: ", ").count, Vocabulary.maxWhisperTerms)
    }

    func testCleanupClauseListsTerms() {
        XCTAssertNil(Vocabulary.cleanupClause(terms: []))
        let clause = Vocabulary.cleanupClause(terms: ["Karan Johar", "Aishwarya Rai"])!
        XCTAssertTrue(clause.contains("Karan Johar, Aishwarya Rai"))
    }

    func testSettingsParsesRawVocabulary() {
        let s = makeSettings()
        XCTAssertEqual(s.customVocabulary, [])
        s.customVocabularyRaw = "Karan Johar\nAishwarya Rai"
        XCTAssertEqual(s.customVocabulary, ["Karan Johar", "Aishwarya Rai"])
    }

    func testCleanupSystemPromptIncludesVocabulary() {
        let prompt = CleanupPrompt.system(for: .english, vocabulary: ["Karan Johar"])
        XCTAssertTrue(prompt.contains("Karan Johar"))
        let without = CleanupPrompt.system(for: .english)
        XCTAssertFalse(without.contains("often says"))
    }

    func testFactoryThreadsVocabularyIntoLLMProviders() {
        let s = makeSettings()
        s.customVocabularyRaw = "Karan Johar"
        s.cleanupProviderID = "openai"
        let openai = CleanupFactory.make(settings: s) as? OpenAICompatibleCleanup
        XCTAssertEqual(openai?.vocabulary, ["Karan Johar"])
        s.cleanupProviderID = "ollama"
        let ollama = CleanupFactory.make(settings: s) as? OllamaCleanup
        XCTAssertEqual(ollama?.vocabulary, ["Karan Johar"])
    }
}
