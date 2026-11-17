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

    var trackedArrivesHere: Bool { tracked?.to.code == station.code }

    /// The tracked train counts until two minutes after it gets in.
    private var trackedIsCurrent: Bool {
        guard let tracked else { return false }
        let arrival = trackedLive?.arrives.expected ?? tracked.arrives
        return date < arrival.addingTimeInterval(2 * 60)
    }

    var showsTracked: Bool { trackedArrivesHere && trackedIsCurrent }

    // timetable ids repeat every day, so an old tracked train mustn't pick out today's run
    func isTracked(_ departure: Departure) -> Bool { trackedIsCurrent && departure.train.uid == tracked?.uid }

    /// The live board for a station, plus the tracked train if it's coming here.
    static func load(_ station: Station, tracking tracked: TrackedTrain? = TrackedTrain.current) async -> BoardEntry {
        var entry = BoardEntry(date: .now, station: station, tracked: tracked)
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
