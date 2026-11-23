import SwiftUI

struct PillDetailView: View {
    let pill: Pill
    var body: some View {
        List {
            AsyncImage(url: pill.imageURL) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }
                .frame(maxHeight: 220).frame(maxWidth: .infinity)
            row("제품명", pill.name); row("업체", pill.company); row("성상", pill.chart)
            row("모양", pill.shape); row("색", pill.colors.joined(separator: ", "))
            row("제형", pill.form); row("앞면 각인", pill.printFront); row("뒷면 각인", pill.printBack)
            row("분류", pill.className); row("구분", pill.category)
        }
        .navigationTitle("의약품 정보").navigationBarTitleDisplayMode(.inline)
    }
    @ViewBuilder private func row(_ title: String, _ value: String?) -> some View {
        if let v = value, !v.isEmpty { LabeledContent(title, value: v) }
    }
}
