import SwiftUI

@main
struct MediLensApp: App {
    private let container: Result<AppContainer, Error> = Result { try AppContainer.live() }
    @State private var sync = SyncStatusModel()

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let c):
                HomeView(container: c, sync: sync)
                    .task { await sync.run(c.syncService) }   // 앱 실행 직후 백그라운드 동기화
            case .failure(let e):
                Text("데이터베이스를 열 수 없습니다: \(e.localizedDescription)").padding()
            }
        }
    }
}
