import SwiftUI

struct PillDetailView: View {
    let pill: Pill

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncImage(url: pill.imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit().padding(24)
                    case .failure: Image(systemName: "pills").font(.largeTitle).foregroundStyle(Palette.textTertiary)
                    default: ProgressView()
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 240)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        if let c = pill.category { Tag(text: c) }
                        if let f = pill.form { Tag(text: f) }
                    }
                    Text(pill.name).font(.title2.weight(.bold)).foregroundStyle(Palette.textPrimary)
                    if let company = pill.company {
                        Text(company).font(.subheadline).foregroundStyle(Palette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)

                InfoCard(title: "생김새", rows: [
                    ("모양", pill.shape), ("색", pill.colors.isEmpty ? nil : pill.colors.joined(separator: ", ")),
                    ("앞면 각인", pill.printFront), ("뒷면 각인", pill.printBack),
                    ("앞면 분할선", pill.lineFront), ("뒷면 분할선", pill.lineBack), ("크기", sizeText),
                ])
                InfoCard(title: "분류", rows: [("효능군", pill.className), ("전문/일반", pill.category), ("제형", pill.form)])
                if let chart = pill.chart, !chart.isEmpty {
                    InfoCard(title: "성상", rows: [("", chart)])
                }

                Text("참고용 정보예요. 복용 전에는 의사·약사와 꼭 확인해 주세요.")
                    .font(.footnote).foregroundStyle(Palette.textTertiary).padding(.top, 8)
            }
            .padding(.horizontal, Metrics.screenPadding).padding(.top, 8).padding(.bottom, 32)
        }
        .background(Palette.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sizeText: String? {
        let parts = [pill.lengthLong, pill.lengthShort, pill.thickness].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.map { String(format: "%g", $0) }.joined(separator: " × ") + " mm"
    }
}

private struct InfoCard: View {
    let title: String
    let rows: [(String, String?)]

    private var visible: [(String, String)] {
        var out: [(String, String)] = []
        for row in rows {
            if let value = row.1, !value.isEmpty { out.append((row.0, value)) }
        }
        return out
    }

    var body: some View {
        if !visible.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.headline).foregroundStyle(Palette.textPrimary)
                ForEach(Array(visible.enumerated()), id: \.offset) { _, row in
                    if row.0.isEmpty {
                        Text(row.1).font(.subheadline).foregroundStyle(Palette.textPrimary)
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.0).font(.subheadline).foregroundStyle(Palette.textSecondary)
                                .frame(width: 84, alignment: .leading)
                            Text(row.1).font(.subheadline).foregroundStyle(Palette.textPrimary)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
        }
    }
}
