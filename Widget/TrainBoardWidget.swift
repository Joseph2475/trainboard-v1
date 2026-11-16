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
    }
}

struct WidgetBoard: View {
    var entry: BoardEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        BoardView(entry: entry, rows: family == .systemLarge ? 17 : 6, compact: family == .systemSmall)
            .containerBackground(scheme == .dark ? Color.black : Color(red: 0.97, green: 0.95, blue: 0.90), for: .widget)
    }
}

// MARK: - Timeline

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BoardEntry {
        BoardEntry(date: .now, station: .fratton)
    }

    func snapshot(for config: PickStation, in context: Context) async -> BoardEntry {
        await BoardEntry.load(station(for: config))
    }

    func timeline(for config: PickStation, in context: Context) async -> Timeline<BoardEntry> {
        let entry = await BoardEntry.load(station(for: config))
        // one fetch, then an entry each minute so the clock ticks and departed trains drop off;
        // macOS lets a widget refetch roughly every 5 minutes
        let nextMinute = Calendar.current.nextDate(after: .now, matching: DateComponents(second: 0),
                                                   matchingPolicy: .nextTime) ?? .now.addingTimeInterval(60)
        let later = (0..<6).map { entry.at(nextMinute.addingTimeInterval(Double($0) * 60)) }
        return Timeline(entries: [entry] + later, policy: .after(nextMinute.addingTimeInterval(300)))
    }

    /// An unset widget shows wherever the tracked train is heading, else Fratton.
    private func station(for config: PickStation) -> Station {
        config.station?.station ?? TrackedTrain.current?.to ?? .fratton
    }
}

// MARK: - Choosing a station per widget

struct PickStation: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Station"
    static let description = IntentDescription("Choose which station this board shows.")

    @Parameter(title: "Station")
    var station: StationEntity?
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
