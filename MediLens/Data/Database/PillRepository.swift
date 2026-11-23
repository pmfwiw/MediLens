import Foundation
import GRDB

final class PillRepository: PillRepositoryProtocol {
    private let db: PillDatabase
    init(db: PillDatabase) { self.db = db }

    /// search/count 가 같은 조건 해석을 쓰도록 JOIN/WHERE 를 한곳에서 만든다.
    private func filter(_ q: PillQuery) -> (join: String, where: String, args: StatementArguments) {
        var join = ""
        var args = StatementArguments()
        var wheres: [String] = []

        let imprint = ImprintNormalizer.normalize(q.imprint)
        if !imprint.isEmpty {
            join = " JOIN pill_imprint_fts f ON f.rowid = p.rowid"
            // 앞/뒤 각인 어느 쪽이든 접두 일치. 따옴표는 제거해 FTS 구문 오류를 막는다.
            wheres.append("pill_imprint_fts MATCH ?")
            args += ["\"\(imprint.replacingOccurrences(of: "\"", with: ""))\"*"]
        }
        if let shape = q.shape { wheres.append("p.shape = ?"); args += [shape] }
        if let form = q.form { wheres.append("p.form = ?"); args += [form] }
        for color in q.colors.sorted() {
            wheres.append("EXISTS (SELECT 1 FROM pill_color c WHERE c.item_seq = p.item_seq AND c.color = ?)")
            args += [color]
        }
        return (join, wheres.isEmpty ? "" : " WHERE " + wheres.joined(separator: " AND "), args)
    }

    func search(_ q: PillQuery) throws -> [Pill] {
        try db.pool.read { conn in
            let f = filter(q)
            var args = f.args
            args += [q.limit]
            let sql = "SELECT p.* FROM pill p" + f.join + f.where + " ORDER BY p.name LIMIT ?"
            return try Row.fetchAll(conn, sql: sql, arguments: args).map { try self.pill(from: $0, conn) }
        }
    }

    func count(_ q: PillQuery) throws -> Int {
        try db.pool.read { conn in
            let f = filter(q)
            return try Int.fetchOne(conn, sql: "SELECT COUNT(*) FROM pill p" + f.join + f.where, arguments: f.args) ?? 0
        }
    }

    func candidates(shapes: Set<String>, colors: Set<String>, limit: Int) throws -> [Pill] {
        try db.pool.read { conn in
            var wheres: [String] = []
            var args = StatementArguments()
            if !shapes.isEmpty {
                wheres.append("p.shape IN (\(databaseQuestionMarks(count: shapes.count)))")
                args += StatementArguments(shapes.sorted())
            }
            if !colors.isEmpty {
                wheres.append("EXISTS (SELECT 1 FROM pill_color c WHERE c.item_seq = p.item_seq AND c.color IN (\(databaseQuestionMarks(count: colors.count))))")
                args += StatementArguments(colors.sorted())
            }
            args += [limit]
            // 색을 후보마다 따로 조회하지 않도록 한 번에 가져온다 (수천 건 조회 시 N+1 방지).
            let sql = "SELECT p.*, (SELECT group_concat(color) FROM pill_color c WHERE c.item_seq = p.item_seq) AS colors_csv FROM pill p"
                + (wheres.isEmpty ? "" : " WHERE " + wheres.joined(separator: " AND ")) + " LIMIT ?"
            return try Row.fetchAll(conn, sql: sql, arguments: args).map { row in
                let csv: String? = row["colors_csv"]
                return try self.pill(from: row, conn, colors: csv.map { $0.split(separator: ",").map(String.init) } ?? [])
            }
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

    private func pill(from r: Row, _ conn: Database, colors preloaded: [String]? = nil) throws -> Pill {
        let id: String = r["item_seq"]
        let colors = try preloaded ?? String.fetchAll(conn, sql: "SELECT color FROM pill_color WHERE item_seq = ?", arguments: [id])
        let url: String? = r["image_url"]
        return Pill(
            id: id, name: r["name"], company: r["company"], chart: r["chart"], shape: r["shape"],
            colors: colors, form: r["form"], printFront: r["print_front"], printBack: r["print_back"],
            lineFront: r["line_front"], lineBack: r["line_back"],
            lengthLong: r["len_long"], lengthShort: r["len_short"], thickness: r["thick"],
            imageURL: url.flatMap(URL.init(string:)), className: r["class_name"], category: r["etc_otc"])
    }
}
