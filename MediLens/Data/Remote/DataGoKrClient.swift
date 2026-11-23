import Foundation

enum RemoteError: Error {
    case unauthorized          // 403: 키 오류/미승인
    case api(code: String, message: String)
    case http(Int)
    case invalidResponse
}

/// 식약처 의약품 낱알식별 정보 API 클라이언트.
final class DataGoKrClient: PillRemoteSource {
    private static let endpoint = "https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService03/getMdcinGrnIdntfcInfoList03"
    private let apiKey: String
    private let session: URLSession
    private let maxAttempts: Int

    init(apiKey: String, maxConcurrency: Int = 8, maxAttempts: Int = 3) {
        self.apiKey = apiKey
        self.maxAttempts = maxAttempts
        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpMaximumConnectionsPerHost = maxConcurrency   // 병렬 상한과 맞춰 연결 재사용
        cfg.timeoutIntervalForRequest = 20
        cfg.waitsForConnectivity = false                     // 오프라인이면 즉시 실패 → 기존 DB로 계속 동작
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: cfg)
    }

    func fetchPage(page: Int, rows: Int, imgRegistDate: String?) async throws -> RemotePage {
        let url = try makeURL(page: page, rows: rows, imgRegistDate: imgRegistDate)
        var lastError: Error = RemoteError.invalidResponse
        for attempt in 0..<maxAttempts {
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse else { throw RemoteError.invalidResponse }
                switch http.statusCode {
                case 200: return try Self.decode(data)
                case 401, 403: throw RemoteError.unauthorized          // 재시도해도 소용없음
                case 429, 500...599: throw RemoteError.http(http.statusCode)
                default: throw RemoteError.http(http.statusCode)
                }
            } catch let e as RemoteError {
                if case .unauthorized = e { throw e }
                if case .api = e { throw e }
                lastError = e
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error                                       // 연결 끊김 등 일시적 오류
            }
            if attempt + 1 < maxAttempts {
                try await Task.sleep(nanoseconds: UInt64(400_000_000) << UInt64(attempt))  // 0.4s, 0.8s, ...
            }
        }
        throw lastError
    }

    /// serviceKey는 '+', '/', '=' 가 들어 있을 수 있어 직접 퍼센트 인코딩한다
    /// (URLQueryItem은 '+'를 인코딩하지 않아 서버가 공백으로 해석함).
    private func makeURL(page: Int, rows: Int, imgRegistDate: String?) throws -> URL {
        var parts = [
            "serviceKey=" + Self.encode(apiKey), "type=json",
            "pageNo=\(page)", "numOfRows=\(rows)",
        ]
        if let d = imgRegistDate { parts.append("img_regist_ts=" + Self.encode(d)) }
        guard let url = URL(string: Self.endpoint + "?" + parts.joined(separator: "&")) else {
            throw RemoteError.invalidResponse
        }
        return url
    }

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s
    }

    // MARK: - 디코딩 (결과 0건이면 body에 items 키가 아예 없다)

    private struct Envelope: Decodable {
        struct Header: Decodable { let resultCode: String; let resultMsg: String? }
        struct Body: Decodable {
            let totalCount: Int
            let items: [RemotePill]
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: Keys.self)
                totalCount = (try? c.decode(Int.self, forKey: .totalCount)) ?? 0
                items = (try? c.decode([RemotePill].self, forKey: .items)) ?? []
            }
            enum Keys: String, CodingKey { case totalCount, items }
        }
        let header: Header
        let body: Body?
    }

    static func decode(_ data: Data) throws -> RemotePage {
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        guard env.header.resultCode == "00" else {
            throw RemoteError.api(code: env.header.resultCode, message: env.header.resultMsg ?? "")
        }
        return RemotePage(totalCount: env.body?.totalCount ?? 0, items: env.body?.items ?? [])
    }
}
