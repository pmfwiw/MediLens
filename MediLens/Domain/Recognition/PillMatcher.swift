import Foundation

/// 관찰 결과(PillObservation)를 DB의 약 후보와 비교해 점수순으로 정렬한다. 순수 로직이라 단위 테스트가 쉽다.
///
/// 설계 원칙
/// - 사진에서 뽑은 값은 틀릴 수 있다 → 일치하면 가점, 불일치해도 **즉시 탈락시키지 않고** 감점만 한다.
///   (예외: 모양/색 둘 다 완전히 다르면 사실상 0점)
/// - 각인은 가장 변별력이 높지만 OCR이 가장 불안정하다 → 읽혔을 때만 강하게 반영하고, 못 읽었다고 불이익은 주지 않는다.
struct PillMatcher {
    struct Weights {
        var color = 0.30
        var shape = 0.25
        var imprint = 0.40
        var size = 0.05
    }
    var weights = Weights()

    /// 모양 오인식이 잦은 쌍. 이웃 모양으로 오인식됐을 때의 인정 비율.
    static let shapeAffinity: [String: [String: Double]] = [
        "원형": ["타원형": 0.5, "팔각형": 0.4, "육각형": 0.3, "오각형": 0.3],
        "타원형": ["원형": 0.5, "장방형": 0.5],
        "장방형": ["타원형": 0.5],
        "사각형": ["마름모형": 0.4, "장방형": 0.2],
        "마름모형": ["사각형": 0.4],
        "팔각형": ["원형": 0.4, "육각형": 0.4],
        "육각형": ["팔각형": 0.4, "원형": 0.3, "오각형": 0.4],
        "오각형": ["육각형": 0.4, "원형": 0.3],
    ]

    /// 색 오인식이 잦은 쌍 (조명/화이트밸런스).
    static let colorAffinity: [String: [String: Double]] = [
        "하양": ["회색": 0.5, "분홍": 0.2, "노랑": 0.2, "투명": 0.3],
        "회색": ["하양": 0.5, "검정": 0.3],
        "노랑": ["주황": 0.4, "연두": 0.3, "하양": 0.2, "갈색": 0.2],
        "주황": ["노랑": 0.4, "빨강": 0.3, "분홍": 0.3, "갈색": 0.4],
        "분홍": ["빨강": 0.4, "주황": 0.3, "하양": 0.2, "자주": 0.3],
        "빨강": ["분홍": 0.4, "주황": 0.3, "갈색": 0.3, "자주": 0.3],
        "갈색": ["주황": 0.4, "빨강": 0.3, "노랑": 0.2],
        "연두": ["초록": 0.5, "노랑": 0.3],
        "초록": ["연두": 0.5, "청록": 0.4],
        "청록": ["초록": 0.4, "파랑": 0.4],
        "파랑": ["청록": 0.4, "남색": 0.5, "보라": 0.3],
        "남색": ["파랑": 0.5, "보라": 0.3, "검정": 0.3],
        "보라": ["자주": 0.4, "파랑": 0.3, "남색": 0.3, "분홍": 0.2],
        "자주": ["보라": 0.4, "분홍": 0.3, "빨강": 0.3],
        "검정": ["남색": 0.3, "회색": 0.3],
        "투명": ["하양": 0.3],
    ]

    func rank(_ obs: PillObservation, among candidates: [Pill], limit: Int = 10) -> [PillMatch] {
        candidates
            .compactMap { score(obs, $0) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.pill.name < $1.pill.name }
            .prefix(limit).map { $0 }
    }

    func score(_ obs: PillObservation, _ pill: Pill) -> PillMatch? {
        var reasons: [String] = []
        var total = 0.0, weightSum = 0.0

        if !obs.colors.isEmpty {
            let s = Self.colorScore(obs.colors, pill.colors)
            total += weights.color * s; weightSum += weights.color
            if s >= 0.8 { reasons.append("색 일치") } else if s >= 0.4 { reasons.append("색 비슷함") }
        }
        if !obs.shapes.isEmpty, let shape = pill.shape {
            let s = Self.shapeScore(obs.shapes, shape)
            total += weights.shape * s; weightSum += weights.shape
            if s >= 0.8 { reasons.append("모양 일치") } else if s >= 0.4 { reasons.append("모양 비슷함") }
        }
        if let best = obs.imprints.max(by: { $0.confidence < $1.confidence }), !best.text.isEmpty {
            let s = Self.imprintScore(obs.imprints, pill)
            // 각인은 "읽혔는데 안 맞는" 경우만 감점. 못 읽었으면 가중치에 넣지 않는다.
            total += weights.imprint * s; weightSum += weights.imprint
            if s >= 0.8 { reasons.append("각인 일치") } else if s >= 0.4 { reasons.append("각인 일부 일치") }
        }
        if let mm = obs.longAxisMM, let long = pill.lengthLong, long > 0 {
            let s = Self.sizeScore(measured: mm, actual: long)
            total += weights.size * s; weightSum += weights.size
            if s >= 0.8 { reasons.append("크기 일치") }
        }
        guard weightSum > 0 else { return nil }
        return PillMatch(pill: pill, score: total / weightSum, reasons: reasons)
    }

    // MARK: 개별 점수 (모두 0...1)

    static func shapeScore(_ observed: [String: Double], _ actual: String) -> Double {
        var s = 0.0
        for (shape, p) in observed {
            let affinity = shape == actual ? 1.0 : (shapeAffinity[shape]?[actual] ?? 0)
            s += p * affinity
        }
        return min(s, 1)
    }

    /// 관찰된 색(1~2개)과 약의 색(1~2개)을 비교. 모든 관찰 색이 약 색 중 하나에 대응할수록 높다.
    static func colorScore(_ observed: [String: Double], _ pillColors: [String]) -> Double {
        guard !pillColors.isEmpty else { return 0.3 }
        let totalP = observed.values.reduce(0, +)
        guard totalP > 0 else { return 0 }
        var s = 0.0
        for (color, p) in observed {
            let best = pillColors.map { pc in pc == color ? 1.0 : (colorAffinity[color]?[pc] ?? 0) }.max() ?? 0
            s += (p / totalP) * best
        }
        // 약은 투톤인데 하나만 관찰했거나 그 반대인 경우 소폭 감점
        if pillColors.count != observed.count { s *= 0.9 }
        return min(s, 1)
    }

    /// OCR 결과와 약의 앞/뒤 각인을 비교. 정규화 후 완전일치 > 부분포함 > 편집거리 유사도 순.
    static func imprintScore(_ readings: [ImprintReading], _ pill: Pill) -> Double {
        let targets = [pill.printFront, pill.printBack].compactMap { $0 }
            .map(ImprintNormalizer.normalize).filter { !$0.isEmpty }
        guard !targets.isEmpty else { return 0 }      // 각인이 없는 약인데 글자가 읽힌 경우 → 불일치
        var best = 0.0
        for r in readings {
            let read = ImprintNormalizer.normalize(r.text)
            guard !read.isEmpty else { continue }
            for t in targets {
                let sim: Double
                if read == t { sim = 1 }
                else if t.contains(read) || read.contains(t) {
                    sim = 0.6 + 0.3 * Double(min(read.count, t.count)) / Double(max(read.count, t.count))
                } else {
                    let d = editDistance(Array(read), Array(t))
                    sim = max(0, 1 - Double(d) / Double(max(read.count, t.count))) * 0.8
                }
                best = max(best, sim * (0.5 + 0.5 * r.confidence))
            }
        }
        return best
    }

    /// 측정 길이와 실제 길이의 상대 오차 기반 (±10%면 만점, ±30% 이상이면 0).
    static func sizeScore(measured: Double, actual: Double) -> Double {
        let err = abs(measured - actual) / actual
        return max(0, min(1, (0.3 - err) / 0.2))
    }

    static func editDistance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[b.count]
    }
}
