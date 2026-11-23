import Foundation

protocol PillRepositoryProtocol {
    func search(_ query: PillQuery) throws -> [Pill]
    func pill(id: String) throws -> Pill?
    func distinctShapes() throws -> [String]
    func distinctColors() throws -> [String]
}
