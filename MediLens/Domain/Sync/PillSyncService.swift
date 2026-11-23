import Foundation

/// 앱 실행 시 신규 등록 약을 받아 내장 DB에 반영한다.
///
/// 전략 (API 제약: 날짜 조건은 img_regist_ts "정확 일치"만 가능):
/// - 마지막 동기화일 - overlap ~ 오늘 을 하루씩 병렬 조회 (하루 응답은 1~10건 수준이라 가볍다)
/// - 공백이 dailyThresholdDays를 넘으면 전체를 페이지 단위(500건)로 병렬 수집하는 편이 요청 수가 적다
/// - 마지막 동기화일은 "앞에서부터 연속으로 성공한 날"까지만 전진시킨다 → 실패한 날은 다음 실행에서 재시도
actor PillSyncService {
    struct Config: Sendable {
        var maxConcurrency = 8
        var overlapDays = 3              // 등록이 늦게 반영되는 경우를 대비한 겹침 (upsert라 안전)
        var dailyThresholdDays = 90
        var pageSize = 500               // API 최대치
        var minInterval: TimeInterval = 3600
    }

    enum Outcome: Equatable {
        case skipped
        case upToDate
        case synced(upserted: Int)
        case partial(upserted: Int, failedUnits: Int)
        case failed(String)
    }

    private let remote: PillRemoteSource
    private let store: PillSyncStoring
    private let config: Config
    private let now: @Sendable () -> Date
    private var running = false

    init(remote: PillRemoteSource, store: PillSyncStoring, config: Config = .init(),
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.remote = remote; self.store = store; self.config = config; self.now = now
    }

    func run() async -> Outcome {
        guard !running else { return .skipped }
        running = true; defer { running = false }
        do {
            let current = now()
            if let last = try store.lastSyncAt(), current.timeIntervalSince(last) < config.minInterval {
                return .skipped
            }
            let today = SyncDates.string(from: current)
            guard let base = try store.syncedThrough(),
                  let start = SyncDates.adding(days: -config.overlapDays, to: base) else {
                return try await fullRefresh(today: today, at: current)
            }
            let days = SyncDates.days(from: start, to: today)
            if days.isEmpty { return .upToDate }
            if days.count > config.dailyThresholdDays {
                return try await fullRefresh(today: today, at: current)
            }
            return try await dailySync(days: days, today: today, at: current)
        } catch {
            return .failed(String(describing: error))
        }
    }

    // MARK: - 일자별 증분

    private func dailySync(days: [String], today: String, at date: Date) async throws -> Outcome {
        let remote = self.remote, rows = config.pageSize
        var upserted = 0
        var succeeded = Set<String>()
        var writeError: Error?

        await forEachConcurrent(days, limit: config.maxConcurrency, work: { day in
            await Result { try await Self.fetchDay(remote: remote, day: day, rows: rows) }
        }, onResult: { day, result in
            guard case .success(let items) = result else { return }
            do {
                if !items.isEmpty { try store.upsert(items) }
                upserted += items.count
                succeeded.insert(day)
            } catch { writeError = error }
        })
        if let writeError { throw writeError }

        // 앞에서부터 연속 성공한 마지막 날
        var through: String?
        for d in days { if succeeded.contains(d) { through = d } else { break } }
        if let through { try store.setSyncedThrough(through) }

        let failed = days.count - succeeded.count
        if failed == 0 {
            try store.setLastSyncAt(date)
            return upserted == 0 ? .upToDate : .synced(upserted: upserted)
        }
        return .partial(upserted: upserted, failedUnits: failed)
    }

    private static func fetchDay(remote: PillRemoteSource, day: String, rows: Int) async throws -> [RemotePill] {
        let first = try await remote.fetchPage(page: 1, rows: rows, imgRegistDate: day)
        var items = first.items
        var page = 2
        while items.count < first.totalCount {          // 하루 500건 초과는 사실상 없지만 안전하게 처리
            let p = try await remote.fetchPage(page: page, rows: rows, imgRegistDate: day)
            if p.items.isEmpty { break }
            items += p.items; page += 1
        }
        return items
    }

    // MARK: - 전체 재수집 (공백이 크거나 메타가 없을 때)

    private func fullRefresh(today: String, at date: Date) async throws -> Outcome {
        let remote = self.remote, rows = config.pageSize
        let first = try await remote.fetchPage(page: 1, rows: rows, imgRegistDate: nil)
        var upserted = first.items.count
        try store.upsert(first.items)
        let pageCount = (first.totalCount + rows - 1) / rows
        let pages = pageCount >= 2 ? Array(2...pageCount) : []

        var failed = 0
        var writeError: Error?
        await forEachConcurrent(pages, limit: config.maxConcurrency, work: { page in
            await Result { try await remote.fetchPage(page: page, rows: rows, imgRegistDate: nil) }
        }, onResult: { _, result in
            switch result {
            case .success(let p):
                do { try store.upsert(p.items); upserted += p.items.count } catch { writeError = error }
            case .failure: failed += 1
            }
        })
        if let writeError { throw writeError }
        if failed > 0 { return .partial(upserted: upserted, failedUnits: failed) }
        try store.setSyncedThrough(today)
        try store.setLastSyncAt(date)
        return .synced(upserted: upserted)
    }
}

private extension Result where Failure == Error {
    init(_ body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}
