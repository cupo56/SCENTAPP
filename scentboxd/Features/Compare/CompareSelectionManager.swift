import Foundation
import Observation

@Observable
@MainActor
final class CompareSelectionManager {
    var selectedPerfumes: [Perfume] = []
    let maxCount = 3

    var canAdd: Bool {
        selectedPerfumes.count < maxCount
    }
    
    var canCompare: Bool {
        selectedPerfumes.count >= 2
    }

    /// Fügt ein Parfum hinzu oder entfernt es, wenn es bereits ausgewählt ist
    func toggle(_ perfume: Perfume) {
        if let index = selectedPerfumes.firstIndex(where: { $0.id == perfume.id }) {
            selectedPerfumes.remove(at: index)
        } else {
            if canAdd {
                selectedPerfumes.append(perfume)
            }
        }
    }

    func isSelected(_ perfume: Perfume) -> Bool {
        selectedPerfumes.contains(where: { $0.id == perfume.id })
    }

    func clear() {
        selectedPerfumes.removeAll()
    }
}
