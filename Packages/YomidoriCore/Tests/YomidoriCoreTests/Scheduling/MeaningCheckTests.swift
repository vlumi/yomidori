import XCTest

@testable import YomidoriCore

final class MeaningCheckTests: XCTestCase {
    private let glosses = [
        "bark (of a tree)", "to nod",
        "sounds given during a conversation to indicate comprehension",
    ]

    func testAGlossMatchesWhateverTheCaseArticleOrParenthetical() {
        XCTAssertTrue(MeaningCheck.matches(typed: "Bark", glosses: glosses))
        XCTAssertTrue(MeaningCheck.matches(typed: "the bark", glosses: glosses))
        XCTAssertTrue(MeaningCheck.matches(typed: "nod", glosses: glosses))
        XCTAssertTrue(MeaningCheck.matches(typed: "to nod.", glosses: glosses))
    }

    func testAWholePhraseInsideALongGlossCounts() {
        XCTAssertTrue(MeaningCheck.matches(typed: "indicate comprehension", glosses: glosses))
        XCTAssertFalse(MeaningCheck.matches(typed: "comprehend", glosses: glosses))
        XCTAssertFalse(MeaningCheck.matches(typed: "a", glosses: glosses))
    }

    func testOneTypoIsForgivenOnAWordLongEnough() {
        XCTAssertTrue(MeaningCheck.matches(typed: "bakr", glosses: ["bark"]))
        XCTAssertTrue(MeaningCheck.matches(typed: "fluorescnce", glosses: ["fluorescence"]))
        XCTAssertFalse(MeaningCheck.matches(typed: "nid", glosses: ["nod"]))
        XCTAssertFalse(MeaningCheck.matches(typed: "brak tree", glosses: ["bark"]))
    }

    func testTheCardsOwnAnswersCount() {
        XCTAssertFalse(MeaningCheck.matches(typed: "tree skin", glosses: glosses))
        XCTAssertTrue(
            MeaningCheck.matches(typed: "Tree skin", glosses: glosses, accepted: ["tree skin"]))
        XCTAssertFalse(MeaningCheck.matches(typed: "", glosses: glosses, accepted: [""]))
    }

    func testEditDistance() {
        XCTAssertEqual(MeaningCheck.editDistance("bark", "bark"), 0)
        XCTAssertEqual(MeaningCheck.editDistance("bark", "bakr"), 1)
        XCTAssertEqual(MeaningCheck.editDistance("bark", "bar"), 1)
        XCTAssertEqual(MeaningCheck.editDistance("bark", "dark"), 1)
        XCTAssertEqual(MeaningCheck.editDistance("bark", "barking"), 2)
    }
}
