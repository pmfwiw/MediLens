import AVFoundation
import Observation
import UIKit

/// 후면 카메라 세션과 촬영. 시뮬레이터처럼 카메라가 없으면 state = .unavailable (앨범 선택만 가능).
@Observable
final class CameraController: NSObject, AVCapturePhotoCaptureDelegate {
    enum State { case idle, ready, denied, unavailable }

    private(set) var state: State = .idle
    var flashOn = false
    let session = AVCaptureSession()

    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "medilens.camera.session")
    private var configured = false
    private var continuation: CheckedContinuation<UIImage?, Never>?

    @MainActor
    func start() async {
        guard await authorize() else { state = .denied; return }
        let ok = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            queue.async { c.resume(returning: self.configureIfNeeded()) }
        }
        guard ok else { state = .unavailable; return }
        queue.async { if !self.session.isRunning { self.session.startRunning() } }
        state = .ready
    }

    @MainActor
    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    @MainActor
    func capture() async -> UIImage? {
        guard state == .ready else { return nil }
        return await withCheckedContinuation { c in
            continuation = c
            let settings = AVCapturePhotoSettings()
            if flashOn, output.supportedFlashModes.contains(.on) { settings.flashMode = .on }
            if let conn = output.connection(with: .video), conn.isVideoRotationAngleSupported(90) {
                conn.videoRotationAngle = 90      // 세로 촬영 기준
            }
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = error == nil ? photo.fileDataRepresentation().flatMap(UIImage.init(data:)) : nil
        let c = continuation
        continuation = nil
        c?.resume(returning: image)
    }

    // MARK: private

    private func authorize() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func configureIfNeeded() -> Bool {
        if configured { return true }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(output) else { return false }
        session.addInput(input)
        session.addOutput(output)
        configured = true
        return true
    }
}
