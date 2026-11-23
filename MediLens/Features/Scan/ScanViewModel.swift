import SwiftUI
import Observation

/// 촬영 → 분석 → 알약별 결과. 비전/DB 작업은 백그라운드에서 하고 결과만 화면 상태에 반영한다.
@Observable
final class ScanViewModel {
    enum Phase {
        case capture
        case analyzing(UIImage)
        case results(UIImage, [ScannedPill])
        case failed(UIImage?, FailureReason)
    }
    enum FailureReason { case notAvailable, noPills, other }

    private(set) var phase: Phase = .capture
    var focusedIndex: Int?
    private let container: AppContainer
    init(container: AppContainer) { self.container = container }

    var isDemo: Bool { container.recognizer.isDemo }

    @MainActor
    func submit(_ original: UIImage) async {
        let image = original.normalized()
        withAnimation(.snappy) { phase = .analyzing(image) }
        guard let cg = image.cgImage else { phase = .failed(image, .other); return }

        let recognizer = container.recognizer, identify = container.identifyPills
        do {
            let scanned: [ScannedPill] = try await Task.detached(priority: .userInitiated) {
                let observations = try await recognizer.recognize(cg)
                guard !observations.isEmpty else { throw RecognitionError.noPillsFound }
                return try identify(observations)
            }.value
            withAnimation(.snappy) { phase = .results(image, scanned) }
        } catch RecognitionError.notAvailable {
            withAnimation(.snappy) { phase = .failed(image, .notAvailable) }
        } catch RecognitionError.noPillsFound {
            withAnimation(.snappy) { phase = .failed(image, .noPills) }
        } catch {
            withAnimation(.snappy) { phase = .failed(image, .other) }
        }
    }

    func retake() {
        focusedIndex = nil
        withAnimation(.snappy) { phase = .capture }
    }
}
