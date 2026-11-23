import Foundation
import Observation

@Observable
final class SearchViewModel {
    var query = PillQuery()
    var results: [Pill] = []
    var shapes: [String] = []
    var colors: [String] = []
    var errorMessage: String?

    private let container: AppContainer
    init(container: AppContainer) { self.container = container }

    func loadOptions() {
        shapes = (try? container.repository.distinctShapes()) ?? []
        colors = (try? container.repository.distinctColors()) ?? []
    }

    func search() {
        do { results = try container.searchPills(query); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
}
