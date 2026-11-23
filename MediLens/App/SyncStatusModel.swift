import Foundation
import Observation

@MainActor @Observable
final class SyncStatusModel {
    enum State: Equatable { case idle, syncing, finished(added: Int), failed }
    var state: State = .idle
    /// 새 데이터가 반영될 때마다 증가 → 화면이 옵션/결과를 다시 불러온다.
    var revision = 0
}
