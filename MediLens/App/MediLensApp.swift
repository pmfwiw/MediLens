import SwiftUI

@main
struct MediLensApp: App {
    private let container: Result<AppContainer, Error> = Result { try AppContainer.live() }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let c):
                SearchView(model: SearchViewModel(container: c), sync: c.syncStatus)
                    .task { await c.startSync() }
            case .failure(let e): Text("데이터베이스를 열 수 없습니다: \(e.localizedDescription)").padding()
            }
        }
    }
}
