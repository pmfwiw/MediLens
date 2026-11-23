import Foundation

/// 사진 한 장에서 찾은 알약 한 알과 그 후보들.
struct ScannedPill: Identifiable {
    var id: UUID { observation.id }
    let index: Int                 // 화면 표시용 번호 (1부터)
    let observation: PillObservation
    let matches: [PillMatch]

    /// 상위 후보 중 점수가 거의 같은 것이 3개 이상이면 "첫 번째가 정답"이라고 말할 수 없다
    /// (예: 각인 없는 흰색 캡슐, 여러 제품이 공유하는 로고 각인). 화면에서 확정적으로 보이지 않게 한다.
    var isAmbiguous: Bool {
        guard let top = matches.first else { return false }
        return matches.filter { top.score - $0.score < 0.02 }.count >= 3
    }
}

/// 알약별 관찰 결과 → DB 후보 조회 → 점수화.
struct IdentifyPillsUseCase {
    let repository: PillRepositoryProtocol
    var matcher = PillMatcher()
    /// 전체(약 2.5만)보다 크게 둔다. 임의로 자르면 정답이 후보에서 빠질 수 있다.
    var candidateLimit = 30_000
    var perPillLimit = 5

    func callAsFunction(_ observations: [PillObservation]) throws -> [ScannedPill] {
        try observations.enumerated().map { i, obs in
            ScannedPill(index: i + 1, observation: obs, matches: try identify(obs))
        }
    }

    func identify(_ obs: PillObservation) throws -> [PillMatch] {
        // 1) 모양/색이 (혼동 가능한 이웃 포함해) 맞는 후보
        let shapes = expand(obs.shapes, affinity: PillMatcher.shapeAffinity, minProb: 0.1, minAffinity: 0.4)
        let colors = expand(obs.colors, affinity: PillMatcher.colorAffinity, minProb: 0.1, minAffinity: 0.3)
        var pool = try repository.candidates(shapes: shapes, colors: colors, limit: candidateLimit)

        // 2) 각인이 어느 정도 확실히 읽혔으면, 모양/색을 잘못 봤더라도 놓치지 않게 각인 일치 후보를 합친다
        if let r = obs.imprints.max(by: { $0.confidence < $1.confidence }), r.confidence >= 0.6, r.text.count >= 2 {
            var q = PillQuery(); q.imprint = r.text; q.limit = 200
            pool += try repository.search(q)
        }
        var seen = Set<String>()
        pool = pool.filter { seen.insert($0.id).inserted }
        return matcher.rank(obs, among: pool, limit: perPillLimit)
    }

    private func expand(_ observed: [String: Double], affinity: [String: [String: Double]],
                        minProb: Double, minAffinity: Double) -> Set<String> {
        var out = Set<String>()
        for (key, p) in observed where p >= minProb {
            out.insert(key)
            for (neighbor, a) in affinity[key] ?? [:] where a >= minAffinity { out.insert(neighbor) }
        }
        return out
    }
}
