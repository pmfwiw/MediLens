import Foundation

/// 의존성 조립. 테스트에서는 대체 구현을 주입한다.
final class AppContainer {
    let repository: PillRepositoryProtocol
    let searchPills: SearchPillsUseCase
    let syncService: PillSyncService?
    let recognizer: PillRecognizing
    let identifyPills: IdentifyPillsUseCase

    init(repository: PillRepositoryProtocol, syncService: PillSyncService? = nil,
         recognizer: PillRecognizing = UnavailableRecognizer()) {
        self.repository = repository
        self.recognizer = recognizer
        self.identifyPills = IdentifyPillsUseCase(repository: repository)
        self.searchPills = SearchPillsUseCase(repository: repository)
        self.syncService = syncService
    }

    static func live() throws -> AppContainer {
        let db = try PillDatabase.openBundled()
        var sync: PillSyncService?
        if let key = apiKey() {   // 키가 없으면 동기화만 비활성화, 내장 DB로 정상 동작
            sync = PillSyncService(remote: DataGoKrClient(apiKey: key), store: PillSyncStore(db: db))
        }
        #if DEBUG
        let recognizer: PillRecognizing = DemoRecognizer()      // 비전 구현 전: 디버그에서만 데모 결과로 화면 확인
        #else
        let recognizer: PillRecognizing = UnavailableRecognizer()
        #endif
        return AppContainer(repository: PillRepository(db: db), syncService: sync, recognizer: recognizer)
    }

    /// Config/Secrets.xcconfig 의 DATA_GO_KR_KEY 가 Info.plist(DataGoKrKey)로 주입된다.
    private static func apiKey() -> String? {
        let v = Bundle.main.object(forInfoDictionaryKey: "DataGoKrKey") as? String
        guard let v, !v.isEmpty, !v.hasPrefix("$(") else { return nil }
        return v
    }
}
