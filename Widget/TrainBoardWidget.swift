import WidgetKit
import SwiftUI
import AppIntents

@main
struct TrainBoardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TrainBoardV1", intent: PickStation.self, provider: Provider()) { entry in
            WidgetBoard(entry: entry)
        }
        // String(...) picks the plain-string overload; the interpolated one crashes WidgetKit
        .configurationDisplayName(String("TrainBoard"))
        .description(String("Live departures, with your tracked train picked out."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()  // the board sets its own, narrower margins
    }
}

struct WidgetBoard: View {
    var entry: BoardEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        BoardView(entry: entry, compact: family == .systemSmall)
            .padding(.horizontal, 10)  // tighter than the system margin so rows run nearly edge to edge
            .padding(.vertical, 14)  // keeps the header clear of the rounded corners
            .containerBackground(.background, for: .widget)
    }
}

// MARK: - Timeline

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BoardEntry {
        BoardEntry(date: .now, station: .fratton)
    }

    func snapshot(for config: PickStation, in context: Context) async -> BoardEntry {
        await load(config)
    }

    func timeline(for config: PickStation, in context: Context) async -> Timeline<BoardEntry> {
        let entry = await load(config)
        // one fetch, then an entry each minute so the clock ticks and departed trains drop off;
        // macOS lets a widget refetch roughly every 5 minutes
        let nextMinute = Calendar.current.nextDate(after: .now, matching: DateComponents(second: 0),
                                                   matchingPolicy: .nextTime) ?? .now.addingTimeInterval(60)
        let later = (0..<6).map { entry.at(nextMinute.addingTimeInterval(Double($0) * 60)) }
        return Timeline(entries: [entry] + later, policy: .after(nextMinute.addingTimeInterval(300)))
    }

    /// A train picked in the widget beats one tracked from the app.
    /// An unset widget shows wherever the tracked train is heading, else Fratton.
    private func load(_ config: PickStation) async -> BoardEntry {
        let tracked = config.train?.train ?? TrackedTrain.current
        return await BoardEntry.load(config.station?.station ?? tracked?.to ?? .fratton, tracking: tracked)
    }
}

// MARK: - Right-click, Edit: the station, and optionally a train to track

struct PickStation: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Station"
    static let description = IntentDescription("Choose the station, and a train coming to it to track.")

    @Parameter(title: "Station")
    var station: StationEntity?

    @Parameter(title: "Track a train from")
    var trackFrom: StationEntity?

    @Parameter(title: "Train")
    var train: TrainEntity?
}

struct TrainEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Train"
    static let defaultQuery = TrainQuery()

    let id: String  // the whole tracked train as JSON, so loading a widget needs no lookup

    init(id: String) { self.id = id }
    init(_ train: TrackedTrain) {
        id = (try? JSONEncoder().encode(train)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    var train: TrackedTrain? { try? JSONDecoder().decode(TrackedTrain.self, from: Data(id.utf8)) }

    var displayRepresentation: DisplayRepresentation {
        guard let train else { return "Train" }
        return DisplayRepresentation(title: "\(ukClock(train.departs)), arrives \(ukClock(train.arrives))")
    }
}

/// Today's direct trains from the "Track a train from" station to this widget's station.
struct TrainQuery: EntityQuery {
    @IntentParameterDependency<PickStation>(\.$station, \.$trackFrom) var config

    func entities(for identifiers: [String]) async throws -> [TrainEntity] {
        identifiers.map(TrainEntity.init(id:))
    }

    func suggestedEntities() async throws -> [TrainEntity] {
        // config is only filled in once both stations are set
        guard let from = config?.trackFrom.station, let to = config?.station.station else { return [] }
        return try await Trainiac.directTrains(from: from.code, to: to.code, limit: 12)
            .map { TrainEntity(TrackedTrain($0, from: from, to: to)) }
    }
}

struct StationEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Station"
    static let defaultQuery = StationQuery()

    let id: String  // "FTN|Fratton": the name rides along so loading a widget needs no lookup

    init(id: String) { self.id = id }
    init(_ station: Station) { id = "\(station.code)|\(station.name)" }

    var station: Station {
        let parts = id.split(separator: "|", maxSplits: 1).map(String.init)
        return parts.count == 2 ? Station(code: parts[0], name: parts[1]) : .fratton
    }

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(station.name)") }
}

struct StationQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [StationEntity] {
        identifiers.map(StationEntity.init(id:))
    }

    func entities(matching string: String) async throws -> [StationEntity] {
        try await Trainiac.stations(matching: string).map(StationEntity.init)
    }

    func suggestedEntities() async throws -> [StationEntity] {
        [StationEntity(.fratton)]
    }
}
