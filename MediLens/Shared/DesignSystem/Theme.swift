import SwiftUI
import UIKit

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    /// 라이트/다크 모드 색을 한 번에 정의한다.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}

/// 디자인 토큰. 화면에서는 직접 색 값을 쓰지 않고 항상 여기서 가져온다.
enum Palette {
    static let background = Color(light: 0xF2F4F6, dark: 0x0E0E11)   // 화면 배경 (연회색)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1C22)         // 카드 (흰색)
    static let fill = Color(light: 0xF2F4F6, dark: 0x2A2A32)         // 이미지 배경, 칩
    static let line = Color(light: 0xE5E8EB, dark: 0x2F2F38)
    static let textPrimary = Color(light: 0x191F28, dark: 0xF2F4F6)
    static let textSecondary = Color(light: 0x6B7684, dark: 0x9AA3AF)
    static let textTertiary = Color(light: 0xB0B8C1, dark: 0x5C6470)
    static let primary = Color(hex: 0x3182F6)
    static let primarySoft = Color(light: 0xE8F3FF, dark: 0x1B2B44)
    static let danger = Color(hex: 0xF04452)
}

enum Metrics {
    static let screenPadding: CGFloat = 20
    static let cardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 56
}

extension View {
    func cardBackground(radius: CGFloat = Metrics.cardRadius) -> some View {
        background(Palette.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
