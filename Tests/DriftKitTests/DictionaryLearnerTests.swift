import XCTest
@testable import DriftKit

final class DictionaryLearnerTests: XCTestCase {
    func testLearnsCorrectedName() {
        let pasted = "I met current johar yesterday"
        let terms = DictionaryLearner.newTerms(
            pasted: pasted,
            before: "Notes so far.\n\(pasted)",
            after: "Notes so far.\nI met Karan Johar yesterday",
            vocabulary: []
        )
        XCTAssertEqual(terms, ["Karan Johar"])
    }

    func testLearnsSeverelyMangledCorrection() {
        // The case the deterministic corrector deliberately skips: the user
        // demonstrating the fix is strong enough evidence to learn from.
        let pasted = "I should have a run is my favorite actress"
        let terms = DictionaryLearner.newTerms(
            pasted: pasted,
            before: pasted,
            after: "Aishwarya Rai is my favorite actress",
            vocabulary: []
        )
        XCTAssertEqual(terms, ["Aishwarya Rai"])
    }

    func testLearnsCasingFix() {
        let pasted = "meeting with vinayak tomorrow"
        let terms = DictionaryLearner.newTerms(
            pasted: pasted,
            before: pasted,
            after: "meeting with Vinayak tomorrow",
            vocabulary: []
        )
        XCTAssertEqual(terms, ["Vinayak"])
    }

    func testLearnsLowercaseSoundAlikeFix() {
        let pasted = "she cut her hat short"
        let terms = DictionaryLearner.newTerms(
            pasted: pasted,
            before: pasted,
            after: "she cut her hair short",
            vocabulary: []
        )
        XCTAssertEqual(terms, ["hair"])
    }

    func testIgnoresContentRewrites() {
        // "noon" -> "night" sounds nothing alike beyond a shared consonant,
        // so it's a content edit, not a mishear fix, and must not be learned.
        let pasted = "the meeting is at noon"
        let terms = DictionaryLearner.newTerms(
            pasted: pasted,
            before: pasted,
            after: "the meeting is at night",
            vocabulary: []
        )
        XCTAssertEqual(terms, [])
    }

    func testIgnoresEditsOutsideDictatedRegionEvenWithSharedWords() {
        // "well" appears in the dictation too, but the user edited the copy of
        // it in their own earlier text; nothing may be learned from that.
        let terms = DictionaryLearner.newTerms(
            pasted: "the demo went well",
            before: "well done team. the demo went well",
            after: "wale done team. the demo went well",
            vocabulary: []
        )
        XCTAssertEqual(terms, [])
    }

    func testLearnsSameWordWhenCorrectedInsideDictatedRegion() {
        let terms = DictionaryLearner.newTerms(
            pasted: "the demo went well",
            before: "well done team. the demo went well",
            after: "well done team. the demo went wale",
            vocabulary: []
        )
        XCTAssertEqual(terms, ["wale"])
    }

    func testIgnoresEditsOutsidePastedText() {
        let terms = DictionaryLearner.newTerms(
            pasted: "and the demo went well",
            before: "kiran presented today. and the demo went well",
            after: "Kiran presented today. and the demo went well",
            vocabulary: []
        )
        XCTAssertEqual(terms, [])
    }

    func testIgnoresAlreadyKnownTerms() {
        let pasted = "call current johar"
        let terms = DictionaryLearner.newTerms(
            pasted: pasted,
            before: pasted,
            after: "call Karan Johar",
            vocabulary: ["Karan Johar"]
        )
        XCTAssertEqual(terms, [])
    }

    func testIgnoresPureInsertionsAndDeletions() {
        let pasted = "send the report"
        let terms = DictionaryLearner.newTerms(
            pasted: pasted,
            before: pasted,
            after: "send the report to Priya please",
            vocabulary: []
        )
        XCTAssertEqual(terms, [])
    }

    func testLearnsMultipleCorrections() {
        let pasted = "current johar and ash rai"
        let terms = DictionaryLearner.newTerms(
            pasted: pasted,
            before: pasted,
            after: "Karan Johar and Aishwarya Rai",
            vocabulary: []
        )
        XCTAssertEqual(terms, ["Karan Johar", "Aishwarya Rai"])
    }

    func testNoChangeLearnsNothing() {
        let pasted = "hello there"
        XCTAssertEqual(
            DictionaryLearner.newTerms(pasted: pasted, before: pasted, after: pasted, vocabulary: []),
            []
        )
    }
}
