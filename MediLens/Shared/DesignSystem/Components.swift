import SwiftUI

// MARK: - 버튼

/// 눌렀을 때 살짝 작아지는 반응. 모든 탭 가능한 요소에 공통 적용.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// 화면 하단 고정 CTA. 한 화면에 주 행동은 하나만 둔다.
struct PrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.buttonHeight)
                .background(Palette.primary.opacity(isEnabled ? 1 : 0.3),
                            in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
    }
}

/// 보조 행동(건너뛰기 등). 배경 없이 텍스트만.
struct TextButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity).frame(height: 44)
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - 선택 타일 / 칩

/// 선택 가능한 큰 타일. 선택되면 파란 테두리 + 연한 파랑 배경.
struct SelectTile<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    let content: Content

    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected; self.action = action; self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(isSelected ? Palette.primarySoft : Palette.card,
                            in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    .strokeBorder(isSelected ? Palette.primary : .clear, lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 조건 요약 칩 (탭하면 해당 조건을 수정).
struct ConditionChip: View {
    let text: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(text).font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .foregroundStyle(Palette.primary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Palette.primarySoft, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

struct Tag: View {
    let text: String
    var body: some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - 단계 레이아웃

/// 한 화면에 질문 하나. 큰 제목 + 내용 + 하단 고정 영역.
struct StepScaffold<Content: View, Bottom: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    let bottom: Bottom

    init(title: String, subtitle: String? = nil,
         @ViewBuilder content: () -> Content, @ViewBuilder bottom: () -> Bottom) {
        self.title = title; self.subtitle = subtitle; self.content = content(); self.bottom = bottom()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.title.weight(.bold)).foregroundStyle(Palette.textPrimary)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(Palette.textSecondary)
                }
                content.padding(.top, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 16).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) { bottom }
                .padding(.horizontal, Metrics.screenPadding).padding(.top, 12).padding(.bottom, 8)
                .background(Palette.background)
        }
    }
}

/// 남은 후보 수. 숫자가 바뀔 때 굴러가는 애니메이션으로 즉각적인 피드백을 준다.
struct MatchCountCaption: View {
    let count: Int
    var body: some View {
        HStack(spacing: 4) {
            Text("조건에 맞는 약").foregroundStyle(Palette.textSecondary)
            Text("\(count.formatted())개").fontWeight(.bold).foregroundStyle(Palette.primary)
                .contentTransition(.numericText())
        }
        .font(.subheadline)
        .animation(.snappy, value: count)
    }
}

struct StepProgress: View {
    let current: Int   // 0-based
    let total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule().fill(i <= current ? Palette.primary : Palette.line).frame(height: 4)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityLabel("\(total)단계 중 \(current + 1)단계")
    }
}
