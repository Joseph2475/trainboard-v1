import Foundation
import WidgetKit

/// The one train being tracked. The app saves it; every widget reads it.
struct TrackedTrain: Codable, Equatable {
    let uid: String
    let from: Station
    let to: Station
    let departs: Date
    let arrives: Date

    // app group shared by the app and the widget; macOS needs the team ID prefix
    private static let store = UserDefaults(suiteName: "69TCYK37VK.com.josephmoylan.trainboardv1")!
    private static let key = "trackedTrain"

    static var current: TrackedTrain? {
        get {
            guard let data = store.data(forKey: key),
                  let train = try? JSONDecoder().decode(TrackedTrain.self, from: data) else { return nil }
            return train.arrives.addingTimeInterval(3 * 3600) > .now ? train : nil  // boards hide it on arrival; this clears it even if very late
        }
        set {
            store.set(try? newValue.map(JSONEncoder().encode), forKey: key)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    init(uid: String, from: Station, to: Station, departs: Date, arrives: Date) {
        (self.uid, self.from, self.to, self.departs, self.arrives) = (uid, from, to, departs, arrives)
    }

    init(_ train: DirectTrain, from: Station, to: Station) {
        self.init(uid: train.train.uid, from: from, to: to, departs: train.departs.scheduled, arrives: train.arrives.scheduled)
    }

    /// The same train as the railway sees it now, found again by its timetable id.
    func live() async throws -> DirectTrain? {
        try await Trainiac.directTrains(from: from.code, to: to.code, leavingFrom: departs, limit: 5)
            .first { $0.train.uid == uid }
    }
}
