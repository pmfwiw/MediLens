import Foundation

/// 의존성 조립. 테스트에서는 PillRepositoryProtocol 대체 구현을 주입한다.
final class AppContainer {
    let repository: PillRepositoryProtocol
    let searchPills: SearchPillsUseCase

    init(repository: PillRepositoryProtocol) {
        self.repository = repository
        self.searchPills = SearchPillsUseCase(repository: repository)
    }

    static func live() throws -> AppContainer {
        AppContainer(repository: PillRepository(db: try PillDatabase.openBundled()))
    }
}
