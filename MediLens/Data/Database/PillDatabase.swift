import Foundation
import GRDB

enum PillDatabaseError: Error { case bundledDatabaseMissing }

/// 번들된 pills.sqlite를 앱 지원 디렉터리로 복사해 연다 (증분 동기화로 쓰기가 필요하므로 복사본 사용).
/// DatabasePool(WAL)이라 동기화 쓰기 중에도 검색(읽기)이 막히지 않는다.
final class PillDatabase: @unchecked Sendable {
    let pool: DatabasePool
    init(pool: DatabasePool) { self.pool = pool }

    static func openBundled() throws -> PillDatabase {
        let fm = FileManager.default
        let dir = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dest = dir.appendingPathComponent("pills.sqlite")
        guard let src = Bundle.main.url(forResource: "pills", withExtension: "sqlite") else {
            throw PillDatabaseError.bundledDatabaseMissing
        }
        // 앱 업데이트로 더 최신 번들 DB가 들어왔으면 교체 (이 DB에는 사용자 데이터가 없다)
        if !fm.fileExists(atPath: dest.path) || (try bundleDate(at: src) ?? "") > (try bundleDate(at: dest) ?? "") {
            for suffix in ["", "-wal", "-shm"] { try? fm.removeItem(atPath: dest.path + suffix) }
            try fm.copyItem(at: src, to: dest)
        }
        return PillDatabase(pool: try DatabasePool(path: dest.path))
    }

    private static func bundleDate(at url: URL) throws -> String? {
        var cfg = Configuration(); cfg.readonly = true
        let q = try DatabaseQueue(path: url.path, configuration: cfg)
        return try q.read { try String.fetchOne($0, sql: "SELECT value FROM sync_meta WHERE key='bundle_date'") }
    }
}
