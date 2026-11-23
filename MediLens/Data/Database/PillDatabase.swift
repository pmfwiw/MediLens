import Foundation
import GRDB

enum PillDatabaseError: Error { case bundledDatabaseMissing }

/// 번들된 pills.sqlite를 앱 지원 디렉터리로 복사해 연다.
/// (증분 동기화로 쓰기가 필요하므로 번들 원본이 아닌 복사본을 사용)
final class PillDatabase {
    let queue: DatabaseQueue

    init(queue: DatabaseQueue) { self.queue = queue }

    static func openBundled() throws -> PillDatabase {
        let fm = FileManager.default
        let dir = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                             appropriateFor: nil, create: true)
        let dest = dir.appendingPathComponent("pills.sqlite")
        if !fm.fileExists(atPath: dest.path) {
            guard let src = Bundle.main.url(forResource: "pills", withExtension: "sqlite") else {
                throw PillDatabaseError.bundledDatabaseMissing
            }
            try fm.copyItem(at: src, to: dest)
        }
        return PillDatabase(queue: try DatabaseQueue(path: dest.path))
    }
}
