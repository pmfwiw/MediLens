import PhotosUI
import SwiftUI

struct ScanFlowView: View {
    @State private var model: ScanViewModel
    @State private var camera = CameraController()
    @State private var showPicker: Bool
    @State private var pickerItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    init(container: AppContainer, source: ScanSource) {
        _model = State(initialValue: ScanViewModel(container: container))
        _showPicker = State(initialValue: source == .album)
    }

    var body: some View {
        Group {
            switch model.phase {
            case .capture:
                CaptureView(camera: camera, onShutter: shoot, onAlbum: { showPicker = true })
            case .analyzing(let image):
                AnalyzingView(image: image)
            case .results(let image, let items):
                ScanResultView(image: image, items: items, isDemo: model.isDemo, focused: $model.focusedIndex, onRetake: model.retake)
            case .failed(let image, let reason):
                ScanFailedView(image: image, reason: reason, onRetake: model.retake)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(isCapture ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { model.retake() } label: { Image(systemName: "chevron.left").font(.body.weight(.semibold)) }
                    .accessibilityLabel("다시 촬영")
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await model.submit(image)
                }
                pickerItem = nil
            }
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .overlay(alignment: .topLeading) {
            if isCapture {   // 촬영 화면은 네비게이션 바를 숨기므로 닫기 버튼을 직접 둔다
                CircleIconButton(symbol: "xmark") { dismiss() }.padding(.leading, 16).padding(.top, 8)
            }
        }
    }

    private var isCapture: Bool { if case .capture = model.phase { true } else { false } }

    private func shoot() {
        Task { if let image = await camera.capture() { await model.submit(image) } }
    }
}

struct CircleIconButton: View {
    let symbol: String
    var size: CGFloat = 44
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(.white)
                .frame(width: size, height: size).background(.black.opacity(0.4), in: Circle())
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - 촬영

private struct CaptureView: View {
    let camera: CameraController
    let onShutter: () -> Void
    let onAlbum: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch camera.state {
            case .ready: CameraPreview(session: camera.session).ignoresSafeArea()
            case .denied: Notice(symbol: "camera.fill", text: "카메라 권한이 필요해요.\n설정에서 허용하거나 앨범에서 사진을 골라주세요.")
            case .unavailable: Notice(symbol: "camera.fill", text: "카메라를 사용할 수 없어요.\n앨범에서 사진을 골라주세요.")
            case .idle: ProgressView().tint(.white)
            }

            GuideCorners().stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .padding(.horizontal, 28).padding(.vertical, 150).allowsHitTesting(false)

            VStack {
                Text("무늬 없는 배경에 약을 간격 두고 올려주세요")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.top, 64)
                Spacer()
                HStack {
                    CircleIconButton(symbol: "photo.on.rectangle", size: 52, action: onAlbum)
                    Spacer()
                    Button(action: onShutter) {
                        ZStack {
                            Circle().strokeBorder(.white, lineWidth: 4).frame(width: 80, height: 80)
                            Circle().fill(.white).frame(width: 64, height: 64)
                        }
                    }
                    .buttonStyle(PressableStyle()).disabled(camera.state != .ready).accessibilityLabel("촬영")
                    Spacer()
                    CircleIconButton(symbol: camera.flashOn ? "bolt.fill" : "bolt.slash.fill", size: 52) { camera.flashOn.toggle() }
                }
                .padding(.horizontal, 32).padding(.bottom, 28)
            }
        }
    }

    private struct Notice: View {
        let symbol: String, text: String
        var body: some View {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.largeTitle).foregroundStyle(.white.opacity(0.6))
                Text(text).font(.subheadline).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
            }.padding(40)
        }
    }
}

/// 네 모서리 ㄱ자 가이드.
private struct GuideCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l: CGFloat = 36
        for (x, y, dx, dy) in [(rect.minX, rect.minY, 1.0, 1.0), (rect.maxX, rect.minY, -1.0, 1.0),
                               (rect.minX, rect.maxY, 1.0, -1.0), (rect.maxX, rect.maxY, -1.0, -1.0)] {
            p.move(to: CGPoint(x: x + dx * l, y: y)); p.addLine(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x, y: y + dy * l))
        }
        return p
    }
}

// MARK: - 분석 중

private struct AnalyzingView: View {
    let image: UIImage
    @State private var sweep = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: image).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                Color.black.opacity(0.45)
                LinearGradient(colors: [.clear, Palette.primary.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120).offset(y: sweep ? geo.size.height * 0.35 : -geo.size.height * 0.35)
                VStack(spacing: 8) {
                    ProgressView().tint(.white).controlSize(.large)
                    Text("알약을 찾고 있어요").font(.title3.weight(.bold)).foregroundStyle(.white).padding(.top, 8)
                    Text("사진 속 약을 하나씩 살펴보는 중이에요").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { sweep = true } }
    }
}

// MARK: - 실패

private struct ScanFailedView: View {
    let image: UIImage?
    let reason: ScanViewModel.FailureReason
    let onRetake: () -> Void

    private var message: (String, String) {
        switch reason {
        case .notAvailable: ("사진 인식은 준비 중이에요", "대신 모양과 색으로 직접 찾아볼 수 있어요")
        case .noPills: ("약을 찾지 못했어요", "밝은 곳에서 무늬 없는 배경에 약을 올리고 다시 찍어보세요")
        case .other: ("분석하지 못했어요", "잠시 후 다시 시도해 주세요")
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: reason == .notAvailable ? "hammer.fill" : "viewfinder").font(.system(size: 44)).foregroundStyle(Palette.textTertiary)
            Text(message.0).font(.title2.weight(.bold)).foregroundStyle(Palette.textPrimary)
            Text(message.1).font(.subheadline).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 4) {
                if reason == .notAvailable {
                    NavigationLink(value: Route.finder(PillQuery())) {
                        Text("생김새로 찾기").font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity)
                            .frame(height: Metrics.buttonHeight)
                            .background(Palette.primary, in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    TextButton(title: "다시 촬영하기", action: onRetake)
                } else {
                    PrimaryButton(title: "다시 촬영하기", action: onRetake)
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding).padding(.bottom, 8).frame(maxWidth: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }
}
