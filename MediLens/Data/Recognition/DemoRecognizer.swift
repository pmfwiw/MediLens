import CoreGraphics
import Foundation

/// 개발용: 사진 내용과 무관하게 고정된 알약 3개를 돌려준다. DEBUG 빌드에서만 연결되며 화면에 "데모"가 표시된다.
struct DemoRecognizer: PillRecognizing {
    var isDemo: Bool { true }

    func recognize(_ image: CGImage) async throws -> [PillObservation] {
        try await Task.sleep(nanoseconds: 1_600_000_000)   // 분석 중 화면 확인용
        return [
            PillObservation(boundingBox: CGRect(x: 0.14, y: 0.20, width: 0.22, height: 0.16),
                            shapes: ["원형": 0.8, "타원형": 0.2], colors: ["노랑": 0.9],
                            imprints: [ImprintReading(text: "YH", confidence: 0.8)], aspectRatio: 1.0),
            PillObservation(boundingBox: CGRect(x: 0.52, y: 0.26, width: 0.34, height: 0.12),
                            shapes: ["장방형": 0.7, "타원형": 0.3], colors: ["하양": 0.5, "파랑": 0.5], aspectRatio: 2.6),
            PillObservation(boundingBox: CGRect(x: 0.32, y: 0.58, width: 0.24, height: 0.18),
                            shapes: ["타원형": 0.7, "원형": 0.3], colors: ["분홍": 0.85],
                            imprints: [ImprintReading(text: "SMT", confidence: 0.5)], aspectRatio: 1.4),
        ]
    }
}
