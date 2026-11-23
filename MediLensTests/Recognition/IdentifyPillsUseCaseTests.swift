import XCTest
@testable import MediLens

private func pill(_ id: String, shape: String, colors: [String], front: String?) -> Pill {
    Pill(id: id, name: "약\(id)", company: nil, chart: nil, shape: shape, colors: colors, form: nil,
         printFront: front, printBack: nil, lineFront: nil, lineBack: nil,
         lengthLong: nil, lengthShort: nil, thickness: nil, imageURL: nil, className: nil, category: nil)
}

/// candidates/search 호출 인자를 기록하는 가짜 저장소.
private final class FakeRepo: PillRepositoryProtocol {
    var pool: [Pill]
    var lastShapes: Set<String> = [], lastColors: Set<String> = []
    init(_ pool: [Pill]) { self.pool = pool }
    func search(_ q: PillQuery) throws -> [Pill] {
        let key = ImprintNormalizer.normalize(q.imprint)
        return pool.filter { ImprintNormalizer.normalize($0.printFront ?? "").hasPrefix(key) }
    }
    func count(_ q: PillQuery) throws -> Int { 0 }
    func candidates(shapes: Set<String>, colors: Set<String>, limit: Int) throws -> [Pill] {
        lastShapes = shapes; lastColors = colors
        return pool.filter { shapes.contains($0.shape ?? "") && !Set($0.colors).isDisjoint(with: colors) }
    }
    func pill(id: String) throws -> Pill? { nil }
    func distinctShapes() throws -> [String] { [] }
    func distinctColors() throws -> [String] { [] }
}

final class IdentifyPillsUseCaseTests: XCTestCase {
    private let box = CGRect(x: 0, y: 0, width: 0.2, height: 0.2)

    func testCandidateRetrievalIncludesConfusableNeighbors() throws {
        let repo = FakeRepo([pill("1", shape: "원형", colors: ["노랑"], front: "YH")])
        let obs = PillObservation(boundingBox: box, shapes: ["원형": 1], colors: ["노랑": 1])
        _ = try IdentifyPillsUseCase(repository: repo).identify(obs)
        XCTAssertTrue(repo.lastShapes.isSuperset(of: ["원형", "타원형"]))   // 원형 ↔ 타원형 혼동 허용
        XCTAssertTrue(repo.lastColors.isSuperset(of: ["노랑", "주황"]))
    }

    func testConfidentImprintRescuesMisreadShapeAndColor() throws {
        // 사진에서는 하양/타원형으로 잘못 봤지만 각인 "YH"는 정확히 읽힌 경우
        let target = pill("1", shape: "원형", colors: ["노랑"], front: "YH")
        let repo = FakeRepo([target])
        let obs = PillObservation(boundingBox: box, shapes: ["삼각형": 1], colors: ["검정": 1],
                                  imprints: [ImprintReading(text: "YH", confidence: 0.9)])
        let matches = try IdentifyPillsUseCase(repository: repo).identify(obs)
        XCTAssertEqual(matches.first?.pill.id, "1")
    }

    func testNumbersPillsInOrder() throws {
        let repo = FakeRepo([pill("1", shape: "원형", colors: ["노랑"], front: nil)])
        let o = PillObservation(boundingBox: box, shapes: ["원형": 1], colors: ["노랑": 1])
        let scanned = try IdentifyPillsUseCase(repository: repo)([o, o])
        XCTAssertEqual(scanned.map(\.index), [1, 2])
    }

    func testManyTiedCandidatesAreMarkedAmbiguous() throws {
        let repo = FakeRepo((1...6).map { pill("\($0)", shape: "장방형", colors: ["하양", "파랑"], front: nil) })
        let o = PillObservation(boundingBox: box, shapes: ["장방형": 1], colors: ["하양": 0.5, "파랑": 0.5])
        let scanned = try IdentifyPillsUseCase(repository: repo)([o])
        XCTAssertTrue(scanned[0].isAmbiguous)

        let unique = FakeRepo([pill("1", shape: "원형", colors: ["노랑"], front: "ZQ9"),
                               pill("2", shape: "원형", colors: ["노랑"], front: "AB")])
        let o2 = PillObservation(boundingBox: box, shapes: ["원형": 1], colors: ["노랑": 1],
                                 imprints: [ImprintReading(text: "ZQ9", confidence: 0.9)])
        XCTAssertFalse(try IdentifyPillsUseCase(repository: unique)([o2])[0].isAmbiguous)
    }

    func testSuggestedQueryFromObservation() {
        let o = PillObservation(boundingBox: box, shapes: ["원형": 0.8, "타원형": 0.2], colors: ["하양": 0.5, "파랑": 0.5],
                                imprints: [ImprintReading(text: "YH", confidence: 0.7)])
        let q = o.suggestedQuery
        XCTAssertEqual(q.shape, "원형"); XCTAssertEqual(q.colors, ["하양", "파랑"]); XCTAssertEqual(q.imprint, "YH")
    }
}
