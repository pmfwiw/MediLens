import XCTest
@testable import MediLens

private func pill(_ id: String, shape: String, colors: [String], front: String?, back: String? = nil, long: Double? = nil) -> Pill {
    Pill(id: id, name: "약\(id)", company: nil, chart: nil, shape: shape, colors: colors, form: nil,
         printFront: front, printBack: back, lineFront: nil, lineBack: nil,
         lengthLong: long, lengthShort: nil, thickness: nil, imageURL: nil, className: nil, category: nil)
}

final class PillMatcherTests: XCTestCase {
    private let box = CGRect(x: 0, y: 0, width: 0.2, height: 0.2)
    private let matcher = PillMatcher()

    func testExactAttributesRankFirst() {
        let target = pill("1", shape: "원형", colors: ["노랑"], front: "YH")
        let others = [pill("2", shape: "원형", colors: ["노랑"], front: "AB"),
                      pill("3", shape: "장방형", colors: ["노랑"], front: "YH"),
                      pill("4", shape: "원형", colors: ["파랑"], front: "YH")]
        let obs = PillObservation(boundingBox: box, shapes: ["원형": 1], colors: ["노랑": 1],
                                  imprints: [ImprintReading(text: "YH", confidence: 0.9)])
        let ranked = matcher.rank(obs, among: [target] + others)
        XCTAssertEqual(ranked.first?.pill.id, "1")
        XCTAssertTrue(ranked.first!.reasons.contains("각인 일치"))
    }

    func testOCRMistakeStillFindsPillViaFuzzyImprint() {
        let target = pill("1", shape: "원형", colors: ["하양"], front: "SMT50")
        let obs = PillObservation(boundingBox: box, shapes: ["원형": 1], colors: ["하양": 1],
                                  imprints: [ImprintReading(text: "SMT5O", confidence: 0.6)])   // 0 ↔ O 오인식
        let m = matcher.score(obs, target)!
        XCTAssertGreaterThan(m.score, 0.7)
    }

    func testUnreadImprintDoesNotPenalize() {
        let p = pill("1", shape: "원형", colors: ["하양"], front: "YH")
        let withNoImprint = PillObservation(boundingBox: box, shapes: ["원형": 1], colors: ["하양": 1])
        XCTAssertEqual(matcher.score(withNoImprint, p)!.score, 1.0, accuracy: 0.001)
    }

    func testConfusableShapeAndColorGetPartialCredit() {
        XCTAssertEqual(PillMatcher.shapeScore(["원형": 1], "타원형"), 0.5, accuracy: 0.001)
        XCTAssertEqual(PillMatcher.colorScore(["하양": 1], ["회색"]), 0.5, accuracy: 0.001)
        XCTAssertEqual(PillMatcher.shapeScore(["원형": 1], "삼각형"), 0, accuracy: 0.001)
    }

    func testTwoToneCapsule() {
        let cap = pill("1", shape: "장방형", colors: ["하양", "파랑"], front: nil)
        let one = PillObservation(boundingBox: box, colors: ["하양": 0.5, "파랑": 0.5])
        let wrong = PillObservation(boundingBox: box, colors: ["빨강": 0.5, "노랑": 0.5])
        XCTAssertGreaterThan(matcher.score(one, cap)!.score, matcher.score(wrong, cap)!.score)
    }

    func testSizeScoreTolerance() {
        XCTAssertEqual(PillMatcher.sizeScore(measured: 10, actual: 10), 1)
        XCTAssertEqual(PillMatcher.sizeScore(measured: 13, actual: 10), 0, accuracy: 0.001)
    }

    func testEditDistance() {
        XCTAssertEqual(PillMatcher.editDistance(Array("KITTEN"), Array("SITTING")), 3)
    }
}
