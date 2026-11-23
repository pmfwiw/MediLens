import Foundation

/// 사진 속 약 한 알에서 비전이 뽑아낸 단서. 모든 값은 "확신도"를 갖는 후보로 표현한다
/// (조명, 각도, 음각 각인 때문에 단정할 수 없으므로 매칭 단계에서 확률적으로 합산한다).
struct PillObservation: Identifiable, Equatable {
    let id: UUID
    /// 원본 사진 기준 정규화 좌표(0...1, **좌상단 원점**)의 경계 상자. Vision 좌표(좌하단 원점)는 비전 계층에서 변환한다. 결과 화면에서 약 위치 표시에 쓴다.
    let boundingBox: CGRect
    /// 모양 후보와 확신도(합 1). 예: ["원형": 0.7, "타원형": 0.3]
    var shapes: [String: Double]
    /// 식약처 색상 분류로 매핑된 색 후보와 확신도. 투톤 캡슐이면 색 2개를 각각 담는다.
    var colors: [String: Double]
    /// OCR로 읽은 각인 후보 (원문, 확신도 0...1). 앞/뒷면을 구분하지 않는다.
    var imprints: [ImprintReading]
    /// 장축/단축 비율 (1.0 = 정원). 모양 보조 단서.
    var aspectRatio: Double?
    /// 보정(동전 등 기준물)이 된 경우의 실제 길이(mm). 없으면 nil.
    var longAxisMM: Double?

    init(id: UUID = UUID(), boundingBox: CGRect, shapes: [String: Double] = [:], colors: [String: Double] = [:],
         imprints: [ImprintReading] = [], aspectRatio: Double? = nil, longAxisMM: Double? = nil) {
        self.id = id; self.boundingBox = boundingBox; self.shapes = shapes; self.colors = colors
        self.imprints = imprints; self.aspectRatio = aspectRatio; self.longAxisMM = longAxisMM
    }
}

struct ImprintReading: Equatable {
    let text: String
    let confidence: Double
}

/// 후보 한 건과 점수, 점수의 근거(결과 화면에서 "색 일치, 각인 일부 일치"처럼 설명).
struct PillMatch: Identifiable, Equatable {
    var id: String { pill.id }
    let pill: Pill
    let score: Double            // 0...1
    let reasons: [String]
}

extension PillObservation {
    /// 관찰 결과를 "생김새로 찾기" 조건으로 바꿔 수동 수정 화면에 채워 준다.
    var suggestedQuery: PillQuery {
        var q = PillQuery()
        q.shape = shapes.max { $0.value < $1.value }?.key
        q.colors = Set(colors.sorted { $0.value > $1.value }.prefix(2).map(\.key))
        q.imprint = imprints.max { $0.confidence < $1.confidence }?.text ?? ""
        return q
    }
}
