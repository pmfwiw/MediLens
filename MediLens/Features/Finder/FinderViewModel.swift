import SwiftUI
import Observation

/// "생김새로 찾기" 흐름: 모양 → 색 → 각인 → 결과. 조건이 바뀔 때마다 남은 후보 수를 즉시 갱신한다.
@Observable
final class FinderViewModel {
    enum Step: Int, CaseIterable { case shape, color, imprint, results }
    static let maxColors = 2
    static let resultLimit = 100

    private(set) var step: Step = .shape
    private(set) var movingForward = true
    private(set) var query = PillQuery()
    private(set) var shapes: [String] = []
    private(set) var colors: [String] = []
    private(set) var matchCount = 0
    private(set) var results: [Pill] = []

    private let container: AppContainer
    init(container: AppContainer, initial: PillQuery = PillQuery()) {
        self.container = container
        self.query = initial
    }

    func load() {
        shapes = (try? container.repository.distinctShapes()) ?? []
        colors = (try? container.repository.distinctColors()) ?? []
        refreshCount()
    }

    // MARK: 조건 변경

    func toggleShape(_ shape: String) {
        query.shape = query.shape == shape ? nil : shape
        refreshCount()
    }

    func toggleColor(_ color: String) {
        if query.colors.contains(color) { query.colors.remove(color) }
        else if query.colors.count < Self.maxColors { query.colors.insert(color) }
        refreshCount()
    }

    func setImprint(_ text: String) {
        query.imprint = text
        refreshCount()
    }

    // MARK: 이동

    func next() {
        guard let nextStep = Step(rawValue: step.rawValue + 1) else { return }
        if nextStep == .results { loadResults() }
        go(to: nextStep)
    }

    /// 현재 단계의 조건을 비우고 다음으로. ("잘 모르겠어요")
    func skip() {
        switch step {
        case .shape: query.shape = nil
        case .color: query.colors = []
        case .imprint: query.imprint = ""
        case .results: return
        }
        refreshCount()
        next()
    }

    /// 이전 단계로. 첫 단계면 false (화면을 닫아야 함).
    @discardableResult
    func back() -> Bool {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return false }
        go(to: prev)
        return true
    }

    func edit(_ target: Step) { go(to: target) }

    // MARK: 요약 (결과 화면 조건 칩)

    var shapeSummary: String { query.shape ?? "모양 전체" }
    var colorSummary: String { query.colors.isEmpty ? "색 전체" : query.colors.sorted().joined(separator: "·") }
    var imprintSummary: String {
        let t = query.imprint.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "각인 없음" : "각인 \(t.uppercased())"
    }

    // MARK: private

    private func go(to target: Step) {
        movingForward = target.rawValue > step.rawValue
        withAnimation(.snappy(duration: 0.3)) { step = target }
    }

    private func refreshCount() {
        matchCount = (try? container.searchPills.count(query)) ?? 0
    }

    private func loadResults() {
        var q = query
        q.limit = Self.resultLimit
        results = (try? container.searchPills(q)) ?? []
    }
}
