import Foundation
import Observation

enum AppTab: Int {
    case catalog = 0
    case favorites = 1
    case owned = 2
    case profile = 3
}

enum DeepLinkRoute: Equatable {
    case perfume(UUID)
    case tab(AppTab)
    case compare([UUID])
}

@Observable
@MainActor
final class DeepLinkHandler {
    var pendingPerfumeId: UUID?
    var pendingTab: Int?
    var pendingCompareIds: [UUID]?

    func handle(url: URL) {
        guard let route = parse(url: url) else { return }

        switch route {
        case .perfume(let perfumeId):
            pendingPerfumeId = perfumeId
        case .tab(let tab):
            pendingTab = tab.rawValue
        case .compare(let perfumeIds):
            pendingCompareIds = perfumeIds
        }
    }

    func parse(url: URL) -> DeepLinkRoute? {
        guard url.scheme?.lowercased() == "scentboxd" else { return nil }

        let host = url.host?.lowercased() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "perfume":
            guard let perfumeIdString = pathComponents.first,
                  let perfumeId = UUID(uuidString: perfumeIdString) else {
                return nil
            }
            return .perfume(perfumeId)

        case "favorites":
            return .tab(.favorites)

        case "owned":
            return .tab(.owned)

        case "profile":
            return .tab(.profile)

        case "compare":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let idsValue = components.queryItems?.first(where: { $0.name == "ids" })?.value else {
                return nil
            }

            var seenIds = Set<UUID>()
            let perfumeIds = idsValue
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
                .filter { seenIds.insert($0).inserted }

            guard perfumeIds.count >= 2 else { return nil }
            return .compare(perfumeIds)

        default:
            return nil
        }
    }

    func consumePendingPerfumeId() {
        pendingPerfumeId = nil
    }

    func consumePendingTab() {
        pendingTab = nil
    }

    func consumePendingCompareIds() {
        pendingCompareIds = nil
    }
}
