import Foundation

/// 공공데이터 API 응답의 한 행. 필드명은 API 원본(대문자)과 동일하게 매핑한다.
struct RemotePill: Decodable, Sendable, Equatable {
    let itemSeq: String
    let itemName: String
    let itemEngName: String?
    let entpName: String?
    let chart: String?
    let itemImage: String?
    let printFront: String?
    let printBack: String?
    let drugShape: String?
    let colorClass1: String?
    let colorClass2: String?
    let lineFront: String?
    let lineBack: String?
    let lengLong: String?
    let lengShort: String?
    let thick: String?
    let imgRegistTs: String?
    let changeDate: String?
    let className: String?
    let etcOtcName: String?
    let formCodeName: String?

    enum CodingKeys: String, CodingKey {
        case itemSeq = "ITEM_SEQ", itemName = "ITEM_NAME", itemEngName = "ITEM_ENG_NAME"
        case entpName = "ENTP_NAME", chart = "CHART", itemImage = "ITEM_IMAGE"
        case printFront = "PRINT_FRONT", printBack = "PRINT_BACK", drugShape = "DRUG_SHAPE"
        case colorClass1 = "COLOR_CLASS1", colorClass2 = "COLOR_CLASS2"
        case lineFront = "LINE_FRONT", lineBack = "LINE_BACK"
        case lengLong = "LENG_LONG", lengShort = "LENG_SHORT", thick = "THICK"
        case imgRegistTs = "IMG_REGIST_TS", changeDate = "CHANGE_DATE"
        case className = "CLASS_NAME", etcOtcName = "ETC_OTC_NAME", formCodeName = "FORM_CODE_NAME"
    }
}

struct RemotePage: Sendable {
    let totalCount: Int
    let items: [RemotePill]
}
