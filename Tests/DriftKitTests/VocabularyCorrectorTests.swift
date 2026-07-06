import XCTest
@testable import DriftKit

final class VocabularyCorrectorTests: XCTestCase {
    private let vocab = ["Karan Johar", "Aishwarya Rai", "Bengaluru"]

    func testRestoresPhoneticallyCloseName() {
        XCTAssertEqual(
            VocabularyCorrector.correct("I met current johar yesterday", vocabulary: vocab),
            "I met Karan Johar yesterday"
        )
    }

    func testPreservesSurroundingPunctuation() {
        XCTAssertEqual(
            VocabularyCorrector.correct("Have you met current johar?", vocabulary: vocab),
            "Have you met Karan Johar?"
        )
    }

    func testFixesCasingOfExactMatch() {
        XCTAssertEqual(
            VocabularyCorrector.correct("karan johar is here", vocabulary: vocab),
            "Karan Johar is here"
        )
    }

    func testLeavesCorrectTextUntouched() {
        let text = "Karan Johar is here"
        XCTAssertEqual(VocabularyCorrector.correct(text, vocabulary: vocab), text)
    }

    func testSingleWordRespellings() {
        XCTAssertEqual(
            VocabularyCorrector.correct("I flew to bangalore last week", vocabulary: vocab),
            "I flew to Bengaluru last week"
        )
    }

    func testDoesNotTouchUnrelatedText() {
        let text = "the current year is busy"
        XCTAssertEqual(VocabularyCorrector.correct(text, vocabulary: vocab), text)
    }

    func testEmptyVocabularyIsNoOp() {
        let text = "current johar was there"
        XCTAssertEqual(VocabularyCorrector.correct(text, vocabulary: []), text)
    }

    func testPreservesNewlines() {
        XCTAssertEqual(
            VocabularyCorrector.correct("current johar\nhello there", vocabulary: vocab),
            "Karan Johar\nhello there"
        )
    }

    func testSeverelyMangledCaptureIsLeftForLLMLayer() {
        // Documents the deliberate limit: this mangle is too far for a
        // deterministic matcher, so it must not be "fixed" into a false positive.
        let text = "I should have a run"
        XCTAssertEqual(VocabularyCorrector.correct(text, vocabulary: vocab), text)
    }

    func testMultipleTermsInOneUtterance() {
        XCTAssertEqual(
            VocabularyCorrector.correct("current johar met ash warya rai in bangalore", vocabulary: vocab),
            "Karan Johar met Aishwarya Rai in Bengaluru"
        )
    }
}
