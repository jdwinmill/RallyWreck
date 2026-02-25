import Foundation

struct Player: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var isHost: Bool
    var isEliminated: Bool

    init(displayName: String, isHost: Bool = false) {
        self.id = UUID().uuidString
        self.displayName = displayName
        self.isHost = isHost
        self.isEliminated = false
    }
}
