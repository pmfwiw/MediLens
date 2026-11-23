import Foundation

protocol PillRepositoryProtocol {
    func search(_ query: PillQuery) throws -> [Pill]
    func count(_ query: PillQuery) throws -> Int
    /// 사진 인식용 후보 조회. 비어 있는 집합은 해당 조건을 적용하지 않는다.
    func candidates(shapes: Set<String>, colors: Set<String>, limit: Int) throws -> [Pill]
    func pill(id: String) throws -> Pill?
    func distinctShapes() throws -> [String]
    func distinctColors() throws -> [String]
}
