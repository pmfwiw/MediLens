import SwiftUI

enum Route: Hashable {
    case finder
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
                    Text("어떤 알약인지\n알려드릴게요")
                        .font(.largeTitle.weight(.bold)).foregroundStyle(Palette.textPrimary)
                    Text("모양과 색, 새겨진 글자로 의약품을 찾아요")
                        .font(.subheadline).foregroundStyle(Palette.textSecondary)
                        .padding(.bottom, 20)

                    NavigationLink(value: Route.finder) {
                        ActionCard(symbol: "pills.fill", tint: Palette.primary,
                                   title: "생김새로 찾기", subtitle: "모양, 색, 각인으로 후보를 좁혀요")
                    }
                    .buttonStyle(PressableStyle())

                    ActionCard(symbol: "camera.viewfinder", tint: Palette.textTertiary,
                               title: "사진으로 찾기", subtitle: "곧 만나볼 수 있어요", badge: "준비 중")
                        .opacity(0.7)

                    statusRow.padding(.top, 8)

                    Text("MediLens는 참고용 정보예요. 복용 전에는 의사·약사와 꼭 확인해 주세요.")
                        .font(.footnote).foregroundStyle(Palette.textTertiary).padding(.top, 24)
                }
                .padding(.horizontal, Metrics.screenPadding).padding(.top, 24).padding(.bottom, 32)
            }
            .background(Palette.background)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .finder: FinderFlowView(container: container)
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

private struct ActionCard: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    var badge: String?

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.title2).foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title).font(.headline).foregroundStyle(Palette.textPrimary)
                    if let badge { Tag(text: badge) }
                }
                Text(subtitle).font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Palette.textTertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}
