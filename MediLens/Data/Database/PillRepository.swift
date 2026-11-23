import Foundation
import GRDB

final class PillRepository: PillRepositoryProtocol {
    private let db: PillDatabase
    init(db: PillDatabase) { self.db = db }

    func search(_ q: PillQuery) throws -> [Pill] {
        try db.pool.read { conn in
            var sql = "SELECT p.* FROM pill p"
            var args = StatementArguments()
            var wheres: [String] = []

            let imprint = ImprintNormalizer.normalize(q.imprint)
            if !imprint.isEmpty {
                sql += " JOIN pill_imprint_fts f ON f.rowid = p.rowid"
                // 앞/뒤 각인 어느 쪽이든 부분 일치 (접두 검색)
                wheres.append("pill_imprint_fts MATCH ?")
                args += ["\"\(imprint.replacingOccurrences(of: "\"", with: ""))\"*"]
            }
            if let shape = q.shape { wheres.append("p.shape = ?"); args += [shape] }
            if let form = q.form { wheres.append("p.form = ?"); args += [form] }
            for color in q.colors.sorted() {
                wheres.append("EXISTS (SELECT 1 FROM pill_color c WHERE c.item_seq = p.item_seq AND c.color = ?)")
                args += [color]
            }
            if !wheres.isEmpty { sql += " WHERE " + wheres.joined(separator: " AND ") }
            sql += " ORDER BY p.name LIMIT ?"
            args += [q.limit]

            return try Row.fetchAll(conn, sql: sql, arguments: args).map { try self.pill(from: $0, conn) }
        }
    }

    func pill(id: String) throws -> Pill? {
        try db.pool.read { conn in
            try Row.fetchOne(conn, sql: "SELECT * FROM pill WHERE item_seq = ?", arguments: [id])
                .map { try self.pill(from: $0, conn) }
        }
    }

    func distinctShapes() throws -> [String] {
        try db.pool.read { try String.fetchAll($0, sql:
            "SELECT shape FROM pill WHERE shape IS NOT NULL GROUP BY shape ORDER BY COUNT(*) DESC") }
    }

    func distinctColors() throws -> [String] {
        try db.pool.read { try String.fetchAll($0, sql:
            "SELECT color FROM pill_color GROUP BY color ORDER BY COUNT(*) DESC") }
    }

    private func pill(from r: Row, _ conn: Database) throws -> Pill {
        let id: String = r["item_seq"]
        let colors = try String.fetchAll(conn, sql: "SELECT color FROM pill_color WHERE item_seq = ?", arguments: [id])
        let url: String? = r["image_url"]
        return Pill(
            id: id, name: r["name"], company: r["company"], chart: r["chart"], shape: r["shape"],
            colors: colors, form: r["form"], printFront: r["print_front"], printBack: r["print_back"],
            lineFront: r["line_front"], lineBack: r["line_back"],
            lengthLong: r["len_long"], lengthShort: r["len_short"], thickness: r["thick"],
            imageURL: url.flatMap(URL.init(string:)), className: r["class_name"], category: r["etc_otc"])
    }
}
