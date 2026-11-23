import Foundation

/// 사진 속 약 한 알에서 비전이 뽑아낸 단서. 모든 값은 "확신도"를 갖는 후보로 표현한다
/// (조명, 각도, 음각 각인 때문에 단정할 수 없으므로 매칭 단계에서 확률적으로 합산한다).
struct PillObservation: Identifiable, Equatable {
    let id: UUID
    /// 원본 사진 기준 정규화 좌표(0...1)의 경계 상자. 결과 화면에서 약 위치 표시에 쓴다.
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
