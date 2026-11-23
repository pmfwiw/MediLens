import Foundation

protocol PillRemoteSource: Sendable {
    /// imgRegistDate(YYYYMMDD)를 주면 해당 일자에 등록된 건만 (API는 범위 조회 불가).
    func fetchPage(page: Int, rows: Int, imgRegistDate: String?) async throws -> RemotePage
}

protocol PillSyncStoring: Sendable {
    func syncedThrough() throws -> String?     // YYYYMMDD
    func lastSyncAt() throws -> Date?
    func upsert(_ items: [RemotePill]) throws  // 한 번의 트랜잭션
    func setSyncedThrough(_ day: String) throws
    func setLastSyncAt(_ date: Date) throws
}
