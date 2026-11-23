import Foundation

struct SearchPillsUseCase {
    let repository: PillRepositoryProtocol

    func callAsFunction(_ query: PillQuery) throws -> [Pill] {
        guard !query.isEmpty else { return [] }
        return try repository.search(query)
    }
}
