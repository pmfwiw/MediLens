import SwiftUI

struct FinderFlowView: View {
    @State private var model: FinderViewModel
    @Environment(\.dismiss) private var dismiss

    init(container: AppContainer, initial: PillQuery = PillQuery()) {
        _model = State(initialValue: FinderViewModel(container: container, initial: initial))
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.step != .results {
                StepProgress(current: model.step.rawValue, total: 3)
                    .padding(.horizontal, Metrics.screenPadding).padding(.top, 8)
            }
            ZStack {
                switch model.step {
                case .shape: ShapeStep(model: model)
                case .color: ColorStep(model: model)
                case .imprint: ImprintStep(model: model)
                case .results: ResultsStep(model: model)
                }
            }
            .id(model.step)
            .transition(.asymmetric(
                insertion: .move(edge: model.movingForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: model.movingForward ? .leading : .trailing).combined(with: .opacity)))
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !model.back() { dismiss() }
                } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(Palette.textPrimary)
                }
                .accessibilityLabel("뒤로")
            }
        }
        .task { model.load() }
    }
}

// MARK: - 1. 모양

private struct ShapeStep: View {
    let model: FinderViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        StepScaffold(title: "알약의 모양을\n골라주세요", subtitle: "가장 비슷한 모양 하나를 선택해요") {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(model.shapes, id: \.self) { shape in
                    let selected = model.query.shape == shape
                    SelectTile(isSelected: selected, action: { model.toggleShape(shape) }) {
                        VStack(spacing: 10) {
                            ShapeGlyph(name: shape, tint: selected ? Palette.primary : Palette.textTertiary)
                            Text(shape).font(.footnote.weight(.medium))
                                .foregroundStyle(selected ? Palette.primary : Palette.textPrimary)
                        }
                    }
                }
            }
        } bottom: {
            MatchCountCaption(count: model.matchCount)
            PrimaryButton(title: "다음", action: model.next)
            TextButton(title: "잘 모르겠어요", action: model.skip)
        }
    }
}

// MARK: - 2. 색

private struct ColorStep: View {
    let model: FinderViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        StepScaffold(title: "무슨 색인가요?", subtitle: "투명 캡슐처럼 두 가지 색이면 최대 2개까지 고를 수 있어요") {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(model.colors, id: \.self) { color in
                    let selected = model.query.colors.contains(color)
                    SelectTile(isSelected: selected, action: { model.toggleColor(color) }) {
                        VStack(spacing: 10) {
                            ColorDot(name: color)
                            Text(color).font(.footnote.weight(.medium))
                                .foregroundStyle(selected ? Palette.primary : Palette.textPrimary)
                        }
                    }
                }
            }
        } bottom: {
            MatchCountCaption(count: model.matchCount)
            PrimaryButton(title: "다음", action: model.next)
            TextButton(title: "잘 모르겠어요", action: model.skip)
        }
    }
}

// MARK: - 3. 각인

private struct ImprintStep: View {
    let model: FinderViewModel
    @FocusState private var focused: Bool

    var body: some View {
        StepScaffold(title: "새겨진 글자가\n있나요?", subtitle: "알약 앞면이나 뒷면에 새겨진 문자·숫자를 입력해요") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("예: YH", text: Binding(get: { model.query.imprint }, set: model.setImprint))
                    .font(.system(size: 32, weight: .bold))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .padding(.vertical, 8)
                Rectangle().fill(focused ? Palette.primary : Palette.line).frame(height: 2)
                Text("앞쪽 글자부터 일부만 입력해도 찾을 수 있어요.\n앞면·뒷면은 구분하지 않아도 돼요.")
                    .font(.footnote).foregroundStyle(Palette.textSecondary).padding(.top, 4)
            }
        } bottom: {
            MatchCountCaption(count: model.matchCount)
            PrimaryButton(title: "\(model.matchCount.formatted())개 후보 보기", isEnabled: model.matchCount > 0, action: model.next)
            TextButton(title: "글자가 없어요", action: model.skip)
        }
        .onAppear { focused = true }
    }
}

// MARK: - 4. 결과

private struct ResultsStep: View {
    let model: FinderViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text(model.matchCount == 0 ? "맞는 약을 찾지 못했어요" : "후보 \(model.matchCount.formatted())개를\n찾았어요")
                    .font(.title.weight(.bold)).foregroundStyle(Palette.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ConditionChip(text: model.shapeSummary) { model.edit(.shape) }
                        ConditionChip(text: model.colorSummary) { model.edit(.color) }
                        ConditionChip(text: model.imprintSummary) { model.edit(.imprint) }
                    }
                }
                .padding(.bottom, 8)

                if model.matchCount > model.results.count {
                    Text("이름순으로 상위 \(model.results.count.formatted())개만 보여드려요. 조건을 더하면 더 정확해져요.")
                        .font(.footnote).foregroundStyle(Palette.textSecondary)
                }

                if model.results.isEmpty {
                    EmptyResult { model.edit(.shape) }
                } else {
                    ForEach(model.results) { pill in
                        NavigationLink(value: Route.detail(pill)) { PillCard(pill: pill) }
                            .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(.horizontal, Metrics.screenPadding).padding(.top, 16).padding(.bottom, 32)
        }
    }
}

private struct EmptyResult: View {
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass").font(.largeTitle).foregroundStyle(Palette.textTertiary)
            Text("조건을 조금 줄여보세요.\n색이나 각인을 빼면 더 잘 찾을 수 있어요.")
                .font(.subheadline).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
            PrimaryButton(title: "조건 다시 고르기", action: retry)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

struct PillCard: View {
    let pill: Pill

    private var subtitle: String {
        var parts: [String] = []
        if let shape = pill.shape { parts.append(shape) }
        if !pill.colors.isEmpty { parts.append(pill.colors.joined(separator: "·")) }
        if let print = pill.printFront, !print.isEmpty { parts.append(print) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: pill.imageURL) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit().padding(6)
                case .failure: Image(systemName: "pills").foregroundStyle(Palette.textTertiary)
                default: ProgressView().controlSize(.small)
                }
            }
            .frame(width: 76, height: 76)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(pill.name).font(.headline).foregroundStyle(Palette.textPrimary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.footnote).foregroundStyle(Palette.textSecondary).lineLimit(1)
                if let company = pill.company { Text(company).font(.caption).foregroundStyle(Palette.textTertiary).lineLimit(1) }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}
