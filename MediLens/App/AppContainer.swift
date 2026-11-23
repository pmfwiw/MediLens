import Foundation

/// 의존성 조립. 테스트에서는 대체 구현을 주입한다.
final class AppContainer {
    let repository: PillRepositoryProtocol
    let searchPills: SearchPillsUseCase
    let syncService: PillSyncService?
    @MainActor let syncStatus = SyncStatusModel()

    init(repository: PillRepositoryProtocol, syncService: PillSyncService? = nil) {
        self.repository = repository
        self.searchPills = SearchPillsUseCase(repository: repository)
        self.syncService = syncService
    }

    static func live() throws -> AppContainer {
        let db = try PillDatabase.openBundled()
        var sync: PillSyncService?
        if let key = apiKey() {   // 키가 없으면 동기화만 비활성화, 내장 DB로 정상 동작
            sync = PillSyncService(remote: DataGoKrClient(apiKey: key), store: PillSyncStore(db: db))
        }
        return AppContainer(repository: PillRepository(db: db), syncService: sync)
    }

    /// Config/Secrets.xcconfig 의 DATA_GO_KR_KEY 가 Info.plist(DataGoKrKey)로 주입된다.
    private static func apiKey() -> String? {
        let v = Bundle.main.object(forInfoDictionaryKey: "DataGoKrKey") as? String
        guard let v, !v.isEmpty, !v.hasPrefix("$(") else { return nil }
        return v
    }

    /// 앱 실행 직후 백그라운드로 호출. UI는 기존 DB로 즉시 사용 가능하다.
    @MainActor func startSync() async {
        guard let syncService else { return }
        syncStatus.state = .syncing
        let outcome = await syncService.run()
        switch outcome {
        case .synced(let n):
            syncStatus.state = .finished(added: n); syncStatus.revision += 1
        case .partial(let n, _):
            syncStatus.state = .failed
            if n > 0 { syncStatus.revision += 1 }
        case .failed: syncStatus.state = .failed
        case .skipped, .upToDate: syncStatus.state = .idle
        }
    }
}
