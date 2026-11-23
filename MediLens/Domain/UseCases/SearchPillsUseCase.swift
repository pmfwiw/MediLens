import Foundation

struct SearchPillsUseCase {
    let repository: PillRepositoryProtocol

    /// 조건이 비어 있으면 전체에서 이름순 상위 `limit`개를 돌려준다.
    func callAsFunction(_ query: PillQuery) throws -> [Pill] { try repository.search(query) }
    func count(_ query: PillQuery) throws -> Int { try repository.count(query) }
}
