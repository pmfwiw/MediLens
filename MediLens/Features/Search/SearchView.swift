import SwiftUI

struct SearchView: View {
    @State var model: SearchViewModel
    var sync: SyncStatusModel

    var body: some View {
        NavigationStack {
            List {
                Section("조건") {
                    TextField("각인 문자 (예: YH)", text: $model.query.imprint)
                        .textInputAutocapitalization(.characters)
                    Picker("모양", selection: $model.query.shape) {
                        Text("전체").tag(String?.none)
                        ForEach(model.shapes, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(model.colors.prefix(14), id: \.self) { c in
                                let on = model.query.colors.contains(c)
                                Button(c) {
                                    if on { model.query.colors.remove(c) } else { model.query.colors.insert(c) }
                                }
                                .buttonStyle(.bordered).tint(on ? .accentColor : .gray)
                            }
                        }
                    }
                }
                Section("결과 \(model.results.count)건") {
                    ForEach(model.results) { pill in
                        NavigationLink(value: pill) { PillRow(pill: pill) }
                    }
                }
            }
            .navigationTitle("MediLens")
            .navigationDestination(for: Pill.self) { PillDetailView(pill: $0) }
            .onAppear { model.loadOptions() }
            .onChange(of: model.query) { model.search() }
            .onChange(of: sync.revision) { model.loadOptions(); model.search() }   // 동기화로 새 데이터 반영
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    switch sync.state {
                    case .syncing: ProgressView()
                    case .finished(let n): Label("\(n)건 업데이트", systemImage: "checkmark.circle").font(.caption)
                    default: EmptyView()
                    }
                }
            }
        }
    }
}

struct PillRow: View {
    let pill: Pill
    var body: some View {
        HStack {
            AsyncImage(url: pill.imageURL) { $0.resizable().scaledToFit() } placeholder: { Color.gray.opacity(0.15) }
                .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading) {
                Text(pill.name).font(.headline).lineLimit(2)
                Text([pill.shape, pill.colors.joined(separator: "/"), pill.printFront]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
