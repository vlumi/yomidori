import XCTest

@testable import YomidoriCore

final class LessonTests: XCTestCase {
    private struct Fixed: RandomNumberGenerator {
        var state: UInt64 = 42
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    private static func card(_ headword: String, day: Int) -> Card {
        Card(
            headword: headword, reading: headword, entryID: nil, sightings: [],
            created: Date(timeIntervalSince1970: Double(day) * 86_400))
    }

    private let waiting = [
        ("三", 3), ("一", 1), ("四", 4), ("二", 2), ("五", 5),
    ].map { card($0.0, day: $0.1) }

    func testOldestNewestAndSize() {
        XCTAssertEqual(
            Lesson.pick(from: waiting, order: .oldest, size: 3).map(\.headword), ["一", "二", "三"])
        XCTAssertEqual(
            Lesson.pick(from: waiting, order: .newest, size: 2).map(\.headword), ["五", "四"])
        XCTAssertEqual(Lesson.pick(from: waiting, order: .oldest, size: 0), [])
        XCTAssertEqual(Lesson.pick(from: waiting, order: .oldest, size: 10).count, 5)
    }

    func testCommonFirstThenTheRestByAge() {
        let picked = Lesson.pick(from: waiting, order: .common, size: 4) {
            ["四", "二"].contains($0.headword)
        }
        XCTAssertEqual(picked.map(\.headword), ["二", "四", "一", "三"])
    }

    func testRandomIsAShuffleOfTheSameCards() {
        var generator = Fixed()
        let picked = Lesson.pick(from: waiting, order: .random, size: 5, using: &generator)
        XCTAssertEqual(Set(picked.map(\.headword)), Set(waiting.map(\.headword)))
        var again = Fixed()
        XCTAssertEqual(Lesson.pick(from: waiting, order: .random, size: 5, using: &again), picked)
    }
}
