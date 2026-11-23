import SwiftUI

enum ScanSource: Hashable { case camera, album }

enum Route: Hashable {
    case scan(ScanSource)
    case finder(PillQuery)
    case detail(Pill)
}

struct HomeView: View {
    let container: AppContainer
    var sync: SyncStatusModel
    @State private var total = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("약을 한 번에\n찍어서 찾아요")
                        .font(.largeTitle.weight(.bold)).foregroundStyle(Palette.textPrimary)
                    Text("여러 알을 한 장에 찍으면 한꺼번에 알려드려요")
                        .font(.subheadline).foregroundStyle(Palette.textSecondary).padding(.bottom, 12)

                    ScanHeroCard()

                    NavigationLink(value: Route.scan(.album)) {
                        SecondaryRow(symbol: "photo.on.rectangle", title: "앨범에서 사진 선택")
                    }
                    .buttonStyle(PressableStyle())
                    NavigationLink(value: Route.finder(PillQuery())) {
                        SecondaryRow(symbol: "slider.horizontal.3", title: "모양·색·각인으로 직접 찾기")
                    }
                    .buttonStyle(PressableStyle())

                    TipsCard().padding(.top, 8)
                    statusRow.padding(.top, 8)
                    Text("MediLens는 참고용 정보예요. 복용 전에는 의사·약사와 꼭 확인해 주세요.")
                        .font(.footnote).foregroundStyle(Palette.textTertiary).padding(.top, 16)
                }
                .padding(.horizontal, Metrics.screenPadding).padding(.top, 24).padding(.bottom, 32)
            }
            .background(Palette.background)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .scan(let source): ScanFlowView(container: container, source: source)
                case .finder(let query): FinderFlowView(container: container, initial: query)
                case .detail(let pill): PillDetailView(pill: pill)
                }
            }
            .onAppear(perform: loadTotal)
            .onChange(of: sync.revision) { loadTotal() }
        }
    }

    private func loadTotal() { total = (try? container.searchPills.count(PillQuery())) ?? 0 }

    @ViewBuilder private var statusRow: some View {
        HStack(spacing: 8) {
            switch sync.state {
            case .syncing:
                ProgressView().controlSize(.small)
                Text("새 의약품 정보를 확인하고 있어요")
            case .finished(let n):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.primary)
                Text("새 의약품 \(n.formatted())개를 추가했어요")
            case .failed:
                Image(systemName: "wifi.slash")
                Text("업데이트하지 못했어요. 저장된 정보로 계속 쓸 수 있어요")
            case .idle:
                Image(systemName: "internaldrive")
                Text("의약품 \(total.formatted())개가 기기에 저장되어 있어요")
            }
        }
        .font(.footnote).foregroundStyle(Palette.textSecondary)
        .animation(.snappy, value: sync.state)
    }
}

/// 홈의 주인공: 큰 파란 카드. 누르면 바로 촬영 화면.
private struct ScanHeroCard: View {
    var body: some View {
        NavigationLink(value: Route.scan(.camera)) {
            VStack(alignment: .leading, spacing: 20) {
                ZStack {   // 여러 알이 놓인 모습을 단순한 도형으로
                    Circle().fill(.white).frame(width: 46, height: 46).offset(x: -70, y: 6)
                    Capsule().fill(Color(hex: 0xFFD43B)).frame(width: 64, height: 28).rotationEffect(.degrees(-20)).offset(x: -4, y: -16)
                    Ellipse().fill(Color(hex: 0xFFA8C5)).frame(width: 52, height: 34).offset(x: 62, y: 10)
                    Circle().fill(Color(hex: 0xA9E34B)).frame(width: 30, height: 30).offset(x: 24, y: 32)
                }
                .frame(maxWidth: .infinity).frame(height: 96)

                VStack(alignment: .leading, spacing: 6) {
                    Text("사진으로 찾기").font(.title2.weight(.bold)).foregroundStyle(.white)
                    Text("알약을 펼쳐 놓고 한 장만 찍으세요").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                }
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("촬영하기").font(.headline)
                }
                .foregroundStyle(Palette.primary).frame(maxWidth: .infinity).frame(height: Metrics.buttonHeight)
                .background(.white, in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
            }
            .padding(20)
            .background(Palette.primary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

private struct SecondaryRow: View {
    let symbol: String
    let title: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.body).foregroundStyle(Palette.textSecondary).frame(width: 28)
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Palette.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Palette.textTertiary)
        }
        .padding(.horizontal, 20).frame(height: 60).frame(maxWidth: .infinity).cardBackground()
    }
}

private struct TipsCard: View {
    private let tips: [(String, String)] = [
        ("square.dashed", "무늬 없는 단색 배경 위에 올려주세요"),
        ("arrow.left.and.right", "약끼리 닿지 않게 간격을 두세요"),
        ("sun.max.fill", "밝은 곳에서 위에서 수직으로 찍어주세요"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("잘 찍는 방법").font(.headline).foregroundStyle(Palette.textPrimary)
            ForEach(tips, id: \.1) { tip in
                HStack(spacing: 12) {
                    Image(systemName: tip.0).foregroundStyle(Palette.primary).frame(width: 28)
                    Text(tip.1).font(.subheadline).foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }
}
