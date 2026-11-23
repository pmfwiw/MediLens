import Foundation

/// 속성 기반 검색 조건. nil/빈 값은 조건 없음.
struct PillQuery: Hashable {
    var shape: String?
    var colors: Set<String> = []
    var imprint: String = ""      // 원본 입력, 정규화는 Repository에서 수행
    var form: String?
    var limit: Int = 100

    var isEmpty: Bool {
        shape == nil && colors.isEmpty && imprint.trimmingCharacters(in: .whitespaces).isEmpty && form == nil
    }
}

enum ImprintNormalizer {
    /// tools/build_db.py 의 norm_imprint 와 동일한 규칙을 유지해야 한다.
    static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "분할선", with: "")
            .replacingOccurrences(of: "마크", with: "")
            .filter { !$0.isWhitespace }
            .uppercased()
    }
}
