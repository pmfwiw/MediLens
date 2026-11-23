import UIKit

extension UIImage {
    /// EXIF 방향을 픽셀에 반영(.up)하고, 긴 변이 maxDimension을 넘으면 줄인다.
    /// 이후 비전 처리와 경계 상자 좌표가 화면에 보이는 사진과 항상 일치하도록 한다.
    func normalized(maxDimension: CGFloat = 2048) -> UIImage {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
