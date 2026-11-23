import Foundation
import GRDB

/// 증분 동기화 결과를 DB에 반영한다. 한 번의 upsert 호출 = 하나의 쓰기 트랜잭션.
/// pill 테이블은 ON CONFLICT DO UPDATE 로 rowid를 유지하고, 외부 콘텐츠 FTS는 'delete' 명령 후 재삽입으로 맞춘다.
final class PillSyncStore: PillSyncStoring, @unchecked Sendable {
    private let db: PillDatabase
    init(db: PillDatabase) { self.db = db }

    func syncedThrough() throws -> String? { try meta("last_synced_date") }

    func lastSyncAt() throws -> Date? {
        try meta("last_sync_at").flatMap(Double.init).map { Date(timeIntervalSince1970: $0) }
    }

    func setSyncedThrough(_ day: String) throws { try setMeta("last_synced_date", day) }
    func setLastSyncAt(_ date: Date) throws { try setMeta("last_sync_at", String(date.timeIntervalSince1970)) }

    func upsert(_ items: [RemotePill]) throws {
        guard !items.isEmpty else { return }
        try db.pool.write { conn in
            let upsert = try conn.cachedStatement(sql: Self.upsertSQL)
            let find = try conn.cachedStatement(sql: "SELECT rowid, imprint_front_norm, imprint_back_norm FROM pill WHERE item_seq = ?")
            let ftsDelete = try conn.cachedStatement(sql: "INSERT INTO pill_imprint_fts(pill_imprint_fts, rowid, imprint_front_norm, imprint_back_norm) VALUES('delete', ?, ?, ?)")
            let ftsInsert = try conn.cachedStatement(sql: "INSERT INTO pill_imprint_fts(rowid, imprint_front_norm, imprint_back_norm) VALUES (?, ?, ?)")

            for p in items {
                let front = Self.norm(p.printFront), back = Self.norm(p.printBack)
                let old = try Row.fetchOne(find, arguments: [p.itemSeq])

                try upsert.execute(arguments: [
                    p.itemSeq, p.itemName, p.itemEngName, p.entpName, p.chart, p.drugShape,
                    p.colorClass1, p.colorClass2, p.formCodeName, p.printFront, p.printBack, front, back,
                    p.lineFront, p.lineBack, p.lengLong.flatMap(Double.init), p.lengShort.flatMap(Double.init),
                    p.thick.flatMap(Double.init), p.itemImage, p.imgRegistTs, p.changeDate, p.className, p.etcOtcName,
                ])

                let rowid: Int64 = try Int64.fetchOne(conn, sql: "SELECT rowid FROM pill WHERE item_seq = ?", arguments: [p.itemSeq])!
                let oldFront: String? = old?["imprint_front_norm"], oldBack: String? = old?["imprint_back_norm"]
                if old == nil || oldFront != front || oldBack != back {
                    if old != nil { try ftsDelete.execute(arguments: [rowid, oldFront, oldBack]) }
                    try ftsInsert.execute(arguments: [rowid, front, back])
                }

                try conn.execute(sql: "DELETE FROM pill_color WHERE item_seq = ?", arguments: [p.itemSeq])
                for c in Self.colors(p.colorClass1, p.colorClass2) {
                    try conn.execute(sql: "INSERT INTO pill_color(item_seq, color) VALUES (?, ?)", arguments: [p.itemSeq, c])
                }
            }
        }
    }

    // MARK: - helpers

    private func meta(_ key: String) throws -> String? {
        try db.pool.read { try String.fetchOne($0, sql: "SELECT value FROM sync_meta WHERE key = ?", arguments: [key]) }
    }
    private func setMeta(_ key: String, _ value: String) throws {
        try db.pool.write { try $0.execute(sql: "INSERT INTO sync_meta(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", arguments: [key, value]) }
    }

    /// tools/build_db.py 의 norm_imprint 와 같은 규칙 (빈 원본은 nil).
    static func norm(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return ImprintNormalizer.normalize(s)
    }

    static func colors(_ values: String?...) -> [String] {
        var out: [String] = []
        for v in values {
            for c in (v ?? "").split(separator: ",") {
                let t = c.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty && !out.contains(t) { out.append(t) }
            }
        }
        return out
    }

    private static let upsertSQL = """
    INSERT INTO pill (item_seq,name,eng_name,company,chart,shape,color1,color2,form,print_front,print_back,
        imprint_front_norm,imprint_back_norm,line_front,line_back,len_long,len_short,thick,image_url,
        img_regist_ts,change_date,class_name,etc_otc)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    ON CONFLICT(item_seq) DO UPDATE SET
        name=excluded.name, eng_name=excluded.eng_name, company=excluded.company, chart=excluded.chart,
        shape=excluded.shape, color1=excluded.color1, color2=excluded.color2, form=excluded.form,
        print_front=excluded.print_front, print_back=excluded.print_back,
        imprint_front_norm=excluded.imprint_front_norm, imprint_back_norm=excluded.imprint_back_norm,
        line_front=excluded.line_front, line_back=excluded.line_back,
        len_long=excluded.len_long, len_short=excluded.len_short, thick=excluded.thick,
        image_url=excluded.image_url, img_regist_ts=excluded.img_regist_ts, change_date=excluded.change_date,
        class_name=excluded.class_name, etc_otc=excluded.etc_otc
    """
}
