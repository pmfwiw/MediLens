import XCTest
@testable import MediLens

private final class FakeRepository: PillRepositoryProtocol {
    var lastQuery = PillQuery()
    func search(_ query: PillQuery) throws -> [Pill] { lastQuery = query; return [] }
    func count(_ query: PillQuery) throws -> Int { lastQuery = query; return query.shape == nil ? 100 : 7 }
    func pill(id: String) throws -> Pill? { nil }
    func distinctShapes() throws -> [String] { ["원형", "타원형"] }
    func distinctColors() throws -> [String] { ["하양", "노랑", "파랑"] }
}

final class FinderViewModelTests: XCTestCase {
    private func makeModel() -> FinderViewModel {
        let m = FinderViewModel(container: AppContainer(repository: FakeRepository()))
        m.load()
        return m
    }

    func testCountUpdatesImmediatelyWhenConditionChanges() {
        let m = makeModel()
        XCTAssertEqual(m.matchCount, 100)
        m.toggleShape("원형")
        XCTAssertEqual(m.matchCount, 7)
        m.toggleShape("원형")            // 같은 걸 다시 누르면 해제
        XCTAssertEqual(m.matchCount, 100)
    }

    func testColorSelectionIsCappedAtTwo() {
        let m = makeModel()
        m.toggleColor("하양"); m.toggleColor("노랑"); m.toggleColor("파랑")
        XCTAssertEqual(m.query.colors, ["하양", "노랑"])
    }

    func testStepFlowAndSkip() {
        let m = makeModel()
        m.toggleShape("원형")
        m.skip()                         // 모양 단계 건너뛰기 → 조건 비움
        XCTAssertNil(m.query.shape); XCTAssertEqual(m.step, .color)
        m.next(); XCTAssertEqual(m.step, .imprint)
        m.next(); XCTAssertEqual(m.step, .results)
        XCTAssertTrue(m.back()); XCTAssertEqual(m.step, .imprint)
    }

    func testBackOnFirstStepReturnsFalse() {
        XCTAssertFalse(makeModel().back())
    }
}
