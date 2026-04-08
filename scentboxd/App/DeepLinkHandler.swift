import Foundation
import Observation

enum AppTab: Int {
    case today = 0
    case catalog = 1
    case favorites = 2
    case owned = 3
    case community = 4
}

enum DeepLinkRoute: Equatable {
    case perfume(UUID)
    case tab(AppTab)
    case compare([UUID])
    case profileSheet
}

@Observable
@MainActor
final class DeepLinkHandler {
    var pendingPerfumeId: UUID?
    var pendingTab: Int?
    var pendingCompareIds: [UUID]?
    var pendingProfileSheet: Bool = false

    func handle(url: URL) {
        guard let route = parse(url: url) else { return }

        switch route {
        case .perfume(let perfumeId):
            pendingPerfumeId = perfumeId
        case .tab(let tab):
            pendingTab = tab.rawValue
        case .compare(let perfumeIds):
            pendingCompareIds = perfumeIds
        case .profileSheet:
            pendingProfileSheet = true
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
            return .profileSheet

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

    func consumePendingProfileSheet() {
        pendingProfileSheet = false
    }
}
