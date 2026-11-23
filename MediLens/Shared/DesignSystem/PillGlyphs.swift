import SwiftUI

struct PolygonShape: Shape {
    let sides: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<sides {
            let a = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(sides)
            let pt = CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct HalfCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY + r / 2), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// 식약처 "의약품 모양" 값을 그림으로 보여준다.
struct ShapeGlyph: View {
    let name: String
    var tint: Color = Palette.textTertiary

    var body: some View {
        Group {
            switch name {
            case "원형": Circle().fill(tint).frame(width: 34, height: 34)
            case "타원형": Ellipse().fill(tint).frame(width: 46, height: 28)
            case "장방형": Capsule().fill(tint).frame(width: 52, height: 22)
            case "사각형": RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint).frame(width: 34, height: 34)
            case "삼각형": PolygonShape(sides: 3).fill(tint).frame(width: 38, height: 38)
            case "마름모형": PolygonShape(sides: 4).fill(tint).frame(width: 40, height: 40)
            case "오각형": PolygonShape(sides: 5).fill(tint).frame(width: 38, height: 38)
            case "육각형": PolygonShape(sides: 6).fill(tint).frame(width: 38, height: 38)
            case "팔각형": PolygonShape(sides: 8).fill(tint).frame(width: 38, height: 38)
            case "반원형": HalfCircleShape().fill(tint).frame(width: 40, height: 36)
            default: Image(systemName: "ellipsis").font(.title2).foregroundStyle(tint)
            }
        }
        .frame(height: 40)
        .accessibilityHidden(true)
    }
}

enum PillColors {
    static func color(for name: String) -> Color {
        switch name {
        case "하양": return Color(hex: 0xFFFFFF)
        case "노랑": return Color(hex: 0xFFD43B)
        case "주황": return Color(hex: 0xFF922B)
        case "분홍": return Color(hex: 0xFFA8C5)
        case "빨강": return Color(hex: 0xF04452)
        case "갈색": return Color(hex: 0xA0673C)
        case "연두": return Color(hex: 0xA9E34B)
        case "초록": return Color(hex: 0x2F9E44)
        case "청록": return Color(hex: 0x12B5B0)
        case "파랑": return Color(hex: 0x3182F6)
        case "남색": return Color(hex: 0x1B3A8A)
        case "자주": return Color(hex: 0xA0306F)
        case "보라": return Color(hex: 0x8B5CF6)
        case "회색": return Color(hex: 0xADB5BD)
        case "검정": return Color(hex: 0x212529)
        default: return Color(hex: 0xDEE2E6)
        }
    }
}

struct ColorDot: View {
    let name: String
    var size: CGFloat = 34
    var body: some View {
        Group {
            if name == "투명" {
                Circle().strokeBorder(Palette.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            } else {
                Circle().fill(PillColors.color(for: name))
                    .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
