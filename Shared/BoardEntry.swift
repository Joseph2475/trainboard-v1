import Foundation
import WidgetKit

/// Everything one board shows at one moment.
struct BoardEntry: TimelineEntry {
    var date: Date
    var station: Station
    var departures: [Departure] = []
    var tracked: TrackedTrain? = nil
    var trackedLive: DirectTrain? = nil
    var failed = false
    var style = BoardStyle.board

    var trackedArrivesHere: Bool { tracked?.to.code == station.code }

    /// The tracked train stays on this board until two minutes after it gets in.
    var showsTracked: Bool {
        guard trackedArrivesHere, let tracked else { return false }
        let arrival = trackedLive?.arrives.expected ?? tracked.arrives
        return date < arrival.addingTimeInterval(2 * 60)
    }

    func isTracked(_ departure: Departure) -> Bool { departure.train.uid == tracked?.uid }

    /// The live board for a station, plus the tracked train if it's coming here.
    static func load(_ station: Station) async -> BoardEntry {
        var entry = BoardEntry(date: .now, station: station, tracked: TrackedTrain.current)
        async let departures = Trainiac.departures(from: station.code)
        if entry.trackedArrivesHere { entry.trackedLive = try? await entry.tracked?.live() }
        do { entry.departures = try await departures } catch { entry.failed = true }
        return entry
    }

    /// The same board later on, with trains that have gone dropped.
    func at(_ later: Date) -> BoardEntry {
        var entry = self
        entry.date = later
        entry.departures = departures.filter { $0.departs.expected >= later }
        return entry
    }
}
