import Foundation
import Observation

@Observable
final class SyncStatusModel {
    enum State: Equatable { case idle, syncing, finished(added: Int), failed }
    var state: State = .idle
    /// 새 데이터가 반영될 때마다 증가 → 화면이 개수/옵션을 다시 불러온다.
    var revision = 0

    @MainActor
    func run(_ service: PillSyncService?) async {
        guard let service else { return }
        state = .syncing
        switch await service.run() {
        case .synced(let n): state = .finished(added: n); revision += 1
        case .partial(let n, _): state = .failed; if n > 0 { revision += 1 }
        case .failed: state = .failed
        case .skipped, .upToDate: state = .idle
        }
    }
}
