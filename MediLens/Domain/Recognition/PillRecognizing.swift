import CoreGraphics
import Foundation

enum RecognitionError: Error, Equatable {
    case notAvailable      // 아직 비전 인식기가 연결되지 않음
    case noPillsFound      // 사진에서 약을 찾지 못함
}

/// 사진에서 약을 찾아 알약별 관찰 결과로 바꾼다. 구현은 Vision 계층(또는 데모)이 제공한다.
protocol PillRecognizing {
    /// true면 결과가 실제 인식이 아닌 데모 데이터다 (화면에 반드시 표시한다).
    var isDemo: Bool { get }
    func recognize(_ image: CGImage) async throws -> [PillObservation]
}

/// 실제 인식기가 없을 때의 기본값. 가짜 결과를 만들지 않고 "준비 중"으로 안내하게 한다.
struct UnavailableRecognizer: PillRecognizing {
    var isDemo: Bool { false }
    func recognize(_ image: CGImage) async throws -> [PillObservation] { throw RecognitionError.notAvailable }
}
