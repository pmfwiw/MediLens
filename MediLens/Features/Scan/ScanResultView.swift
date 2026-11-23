import SwiftUI

struct ScanResultView: View {
    let image: UIImage
    let items: [ScannedPill]
    let isDemo: Bool
    @Binding var focused: Int?
    let onRetake: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("약 \(items.count)개를\n찾았어요").font(.title.weight(.bold)).foregroundStyle(Palette.textPrimary)
                    if isDemo { DemoBanner() }

                    AnnotatedPhoto(image: image, items: items, focused: focused) { index in
                        withAnimation(.snappy) { focused = index; proxy.scrollTo(index, anchor: .top) }
                    }

                    ForEach(items) { item in
                        PillResultSection(item: item, isFocused: focused == item.index).id(item.index)
                    }
                    Text("참고용 정보예요. 복용 전에는 의사·약사와 꼭 확인해 주세요.")
                        .font(.footnote).foregroundStyle(Palette.textTertiary).padding(.top, 8)
                }
                .padding(.horizontal, Metrics.screenPadding).padding(.top, 8).padding(.bottom, 24)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "다시 촬영하기", action: onRetake)
                .padding(.horizontal, Metrics.screenPadding).padding(.top, 12).padding(.bottom, 8)
                .background(Palette.background)
        }
    }
}

private struct DemoBanner: View {
    var body: some View {
        Label("개발용 데모 결과예요. 실제 인식이 아니에요.", systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.medium)).foregroundStyle(Color(hex: 0xB45309))
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xFFF4E0), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 사진 위에 알약별 번호 상자를 겹쳐 그린다. 상자를 누르면 해당 알약 결과로 이동.
private struct AnnotatedPhoto: View {
    let image: UIImage
    let items: [ScannedPill]
    let focused: Int?
    let onTap: (Int) -> Void

    var body: some View {
        Image(uiImage: image).resizable().scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay {
                GeometryReader { g in
                    ForEach(items) { item in
                        let b = item.observation.boundingBox
                        let rect = CGRect(x: b.minX * g.size.width, y: b.minY * g.size.height,
                                          width: b.width * g.size.width, height: b.height * g.size.height)
                        let on = focused == item.index
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(on ? Palette.primary : .white, lineWidth: on ? 3 : 2)
                            .shadow(color: .black.opacity(0.35), radius: 2)
                            .frame(width: rect.width, height: rect.height)
                            .overlay(alignment: .topLeading) { NumberBadge(number: item.index, highlighted: on).offset(x: -8, y: -8) }
                            .position(x: rect.midX, y: rect.midY)
                            .onTapGesture { onTap(item.index) }
                            .accessibilityLabel("\(item.index)번 알약")
                    }
                }
            }
    }
}

struct NumberBadge: View {
    let number: Int
    var highlighted = true
    var body: some View {
        Text("\(number)").font(.caption.weight(.bold)).foregroundStyle(.white)
            .frame(width: 24, height: 24).background(highlighted ? Palette.primary : Color.black.opacity(0.65), in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
    }
}

// MARK: - 알약별 결과

private struct PillResultSection: View {
    let item: ScannedPill
    let isFocused: Bool
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                NumberBadge(number: item.index)
                Text("\(item.index)번 알약").font(.headline).foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(observedSummary).font(.footnote).foregroundStyle(Palette.textSecondary).lineLimit(1)
            }

            if let top = item.matches.first {
                if item.isAmbiguous {
                    Label("비슷한 약이 여러 개예요. 새겨진 글자를 더하면 좁혀져요", systemImage: "info.circle.fill")
                        .font(.footnote.weight(.medium)).foregroundStyle(Palette.primary)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.primarySoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                MatchRow(match: top, isTop: true, ambiguous: item.isAmbiguous)
                if item.matches.count > 1 {
                    Button { withAnimation(.snappy) { expanded.toggle() } } label: {
                        HStack { Text(expanded ? "접기" : "다른 후보 \(item.matches.count - 1)개 보기")
                            Image(systemName: expanded ? "chevron.up" : "chevron.down") }
                            .font(.subheadline.weight(.medium)).foregroundStyle(Palette.primary)
                    }
                    .buttonStyle(PressableStyle())
                    if expanded { ForEach(item.matches.dropFirst()) { MatchRow(match: $0, isTop: false, ambiguous: item.isAmbiguous) } }
                }
            } else {
                Text("비슷한 약을 찾지 못했어요").font(.subheadline).foregroundStyle(Palette.textSecondary)
            }

            NavigationLink(value: Route.finder(item.observation.suggestedQuery)) {
                Text(item.isAmbiguous ? "각인 입력해서 좁히기" : "이게 아니에요 · 조건 바꿔서 찾기").font(.subheadline.weight(.medium)).foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(Palette.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
            .strokeBorder(isFocused ? Palette.primary : .clear, lineWidth: 2))
    }

    private var observedSummary: String {
        let o = item.observation
        var parts: [String] = []
        if let s = o.shapes.max(by: { $0.value < $1.value })?.key { parts.append(s) }
        let cs = o.colors.sorted { $0.value > $1.value }.prefix(2).map(\.key)
        if !cs.isEmpty { parts.append(cs.joined(separator: "·")) }
        if let t = o.imprints.max(by: { $0.confidence < $1.confidence })?.text, !t.isEmpty { parts.append(t) }
        return parts.joined(separator: " · ")
    }
}

private struct MatchRow: View {
    let match: PillMatch
    let isTop: Bool
    let ambiguous: Bool

    private var label: String {
        if ambiguous && match.score >= 0.65 { return "후보 중 하나예요" }   // 동률이 많으면 "아주 비슷"이라 단정하지 않는다
        return match.score >= 0.85 ? "아주 비슷해요" : match.score >= 0.65 ? "비슷해요" : "참고용 후보"
    }

    var body: some View {
        NavigationLink(value: Route.detail(match.pill)) {
            HStack(spacing: 14) {
                AsyncImage(url: match.pill.imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit().padding(4)
                    case .failure: Image(systemName: "pills").foregroundStyle(Palette.textTertiary)
                    default: ProgressView().controlSize(.small)
                    }
                }
                .frame(width: isTop ? 64 : 48, height: isTop ? 64 : 48)
                .background(Palette.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(match.pill.name).font(isTop ? .headline : .subheadline.weight(.semibold))
                        .foregroundStyle(Palette.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                    Text(label).font(.caption.weight(.semibold))
                        .foregroundStyle(match.score >= 0.65 ? Palette.primary : Palette.textSecondary)
                    if !match.reasons.isEmpty {
                        Text(match.reasons.joined(separator: " · ")).font(.caption).foregroundStyle(Palette.textSecondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Palette.textTertiary)
            }
        }
        .buttonStyle(PressableStyle())
    }
}
