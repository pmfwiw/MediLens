import XCTest
@testable import MediLens

private func pill(_ seq: String, ts: String) -> RemotePill {
    RemotePill(itemSeq: seq, itemName: "n\(seq)", itemEngName: nil, entpName: nil, chart: nil, itemImage: nil,
               printFront: nil, printBack: nil, drugShape: nil, colorClass1: nil, colorClass2: nil,
               lineFront: nil, lineBack: nil, lengLong: nil, lengShort: nil, thick: nil,
               imgRegistTs: ts, changeDate: nil, className: nil, etcOtcName: nil, formCodeName: nil)
}

private final class FakeStore: PillSyncStoring, @unchecked Sendable {
    private let lock = NSLock()
    var through: String?; var lastAt: Date?; var upserted: [RemotePill] = []
    init(through: String?) { self.through = through }
    func syncedThrough() throws -> String? { lock.withLock { through } }
    func lastSyncAt() throws -> Date? { lock.withLock { lastAt } }
    func upsert(_ items: [RemotePill]) throws { lock.withLock { upserted += items } }
    func setSyncedThrough(_ day: String) throws { lock.withLock { through = day } }
    func setLastSyncAt(_ date: Date) throws { lock.withLock { lastAt = date } }
}

private final class FakeRemote: PillRemoteSource, @unchecked Sendable {
    private let lock = NSLock()
    var byDay: [String: [RemotePill]] = [:]
    var failDays: Set<String> = []
    var calls: [String?] = []
    var all: [RemotePill] = []
    func fetchPage(page: Int, rows: Int, imgRegistDate: String?) async throws -> RemotePage {
        lock.withLock { calls.append(imgRegistDate) }
        if let d = imgRegistDate {
            if failDays.contains(d) { throw URLError(.networkConnectionLost) }
            let items = byDay[d] ?? []
            return RemotePage(totalCount: items.count, items: page == 1 ? items : [])
        }
        let slice = Array(all.dropFirst((page - 1) * rows).prefix(rows))
        return RemotePage(totalCount: all.count, items: slice)
    }
}

final class PillSyncServiceTests: XCTestCase {
    private let kst = SyncDates.date(from: "20261123")!.addingTimeInterval(3600 * 12)

    func testDaysIncludeBothEnds() {
        XCTAssertEqual(SyncDates.days(from: "20261129", to: "20261202"), ["20261129", "20261130", "20261201", "20261202"])
        XCTAssertTrue(SyncDates.days(from: "20261124", to: "20261123").isEmpty)
    }

    func testDailySyncFetchesOverlapThroughToday() async {
        let store = FakeStore(through: "20261120"), remote = FakeRemote()
        remote.byDay["20261122"] = [pill("A", ts: "20261122")]
        let svc = PillSyncService(remote: remote, store: store, now: { [kst] in kst })
        let out = await svc.run()
        XCTAssertEqual(out, .synced(upserted: 1))
        XCTAssertEqual(Set(remote.calls.compactMap { $0 }), ["20261117", "20261118", "20261119", "20261120", "20261121", "20261122", "20261123"])
        XCTAssertEqual(store.through, "20261123")
        XCTAssertNotNil(store.lastAt)
    }

    func testFailedDayHoldsBackSyncedThroughButKeepsOtherData() async {
        let store = FakeStore(through: "20261120"), remote = FakeRemote()
        remote.failDays = ["20261121"]
        remote.byDay["20261122"] = [pill("B", ts: "20261122")]
        let svc = PillSyncService(remote: remote, store: store, config: .init(), now: { [kst] in kst })
        let out = await svc.run()
        XCTAssertEqual(out, .partial(upserted: 1, failedUnits: 1))
        XCTAssertEqual(store.through, "20261120", "실패한 날 이전까지만 전진")
        XCTAssertEqual(store.upserted.map(\.itemSeq), ["B"], "성공한 날의 데이터는 반영")
        XCTAssertNil(store.lastAt, "완전 성공이 아니므로 다음 실행에서 재시도")
    }

    func testSkipsWhenSyncedRecently() async {
        let store = FakeStore(through: "20261123"); store.lastAt = kst.addingTimeInterval(-60)
        let remote = FakeRemote()
        let out = await PillSyncService(remote: remote, store: store, now: { [kst] in kst }).run()
        XCTAssertEqual(out, .skipped); XCTAssertTrue(remote.calls.isEmpty)
    }

    func testLargeGapUsesPagedFullRefresh() async {
        let store = FakeStore(through: "20250101"), remote = FakeRemote()
        remote.all = (0..<1200).map { pill("P\($0)", ts: "20250101") }
        let out = await PillSyncService(remote: remote, store: store, now: { [kst] in kst }).run()
        XCTAssertEqual(out, .synced(upserted: 1200))
        XCTAssertTrue(remote.calls.allSatisfy { $0 == nil }, "일자 조회 없이 페이지 조회만")
        XCTAssertEqual(remote.calls.count, 3)   // 500 + 500 + 200
        XCTAssertEqual(store.through, "20261123")
    }

    func testConcurrencyIsBounded() async {
        actor Probe { var cur = 0, peak = 0
            func enter() { cur += 1; peak = max(peak, cur) }; func leave() { cur -= 1 } }
        let probe = Probe()
        await forEachConcurrent(Array(0..<30), limit: 4, work: { _ in
            await probe.enter(); try? await Task.sleep(nanoseconds: 5_000_000); await probe.leave()
        }, onResult: { _, _ in })
        let peak = await probe.peak
        XCTAssertLessThanOrEqual(peak, 4); XCTAssertGreaterThan(peak, 1)
    }
}
