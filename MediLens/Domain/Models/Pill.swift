import Foundation

struct Pill: Identifiable, Hashable {
    let id: String            // ITEM_SEQ
    let name: String
    let company: String?
    let chart: String?
    let shape: String?
    let colors: [String]
    let form: String?
    let printFront: String?
    let printBack: String?
    let lineFront: String?
    let lineBack: String?
    let lengthLong: Double?
    let lengthShort: Double?
    let thickness: Double?
    let imageURL: URL?
    let className: String?
    let category: String?     // 전문/일반
}
