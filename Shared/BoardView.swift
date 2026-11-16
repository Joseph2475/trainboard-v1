import SwiftUI
import WidgetKit

/// How a board looks in full colour. The system's own glass and tinted modes apply on top of either.
enum BoardStyle: String, CaseIterable {
    case glass  // system text colours, so it sits with Apple's widgets
    case board  // amber on black like a station screen, brown on paper in light mode
}

/// A station departure board.
struct BoardView: View {
    var entry: BoardEntry
    var rows: Int
    var compact = false  // small widget: no platform or expected columns
    var style = BoardStyle.board

    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var amber: Bool { style == .board && renderingMode == .fullColor }
    private var ink: Color { !amber ? .primary : scheme == .dark ? .orange : Color(red: 0.42, green: 0.27, blue: 0.03) }
    private var good: Color { amber && scheme == .light ? Color(red: 0, green: 0.5, blue: 0.18) : .green }
    private var timeWidth: CGFloat { clockIsTwelveHour ? 50 : 36 }  // "11:14 pm" needs more room than "23:14"
    private var warning: Color { amber && scheme == .dark ? .yellow : .orange }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            header
            Rectangle().fill(ink.opacity(0.4)).frame(height: 1)
            if entry.showsTracked, let tracked = entry.tracked {
                trackedBanner(tracked)
            }
            if entry.departures.isEmpty {
                Text(entry.failed ? "No trains available right now" : "No trains due")
                    .opacity(0.7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if !compact { columnTitles }
                let shown = entry.departures.prefix(entry.showsTracked ? rows - 1 : rows)
                VStack(spacing: 3) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { index, departure in
                        row(departure, striped: index.isMultiple(of: 2) == false)
                    }
                }
                // if rows run out of room they're cut off at the bottom instead of squashing the header
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(ink)
    }

    // MARK: Parts

    private var header: some View {
        HStack {
            Text(entry.station.name.uppercased()).lineLimit(1)
            Spacer()
            Text(ukClock(entry.date)).opacity(0.6)
        }
        .font(.system(.caption, design: .monospaced).bold())
    }

    private var columnTitles: some View {
        HStack(spacing: 6) {
            Text("TIME").frame(width: timeWidth, alignment: .leading)
            Text("DESTINATION").frame(maxWidth: .infinity, alignment: .leading)
            Text("PLAT").frame(width: 28)
            Text("EXPECTED").frame(width: 62, alignment: .leading)
        }
        .font(.system(size: 8, design: .monospaced))
        .opacity(0.5)
        .padding(.horizontal, 3)
    }

    private func row(_ departure: Departure, striped: Bool) -> some View {
        let tracked = entry.isTracked(departure)
        let status = departure.departs.status
        return HStack(spacing: 6) {
            // the small widget has no Expected column, so the time carries the status colour
            Text(ukClock(departure.departs.scheduled))
                .foregroundStyle(compact ? color(status) : ink)
                .frame(width: timeWidth, alignment: .leading)
            HStack(spacing: 3) {
                if tracked { Image(systemName: "pin.fill").font(.system(size: 8)).widgetAccentable() }
                Text(departure.destination.name).truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !compact {
                Text(departure.platform?.number ?? "-").opacity(0.6).frame(width: 28)
                Text(text(status)).foregroundStyle(color(status)).frame(width: 62, alignment: .leading)
            }
        }
        .lineLimit(1)
        .padding(.vertical, 1.5)
        .padding(.horizontal, 3)
        .background(tracked ? ink.opacity(0.22) : striped ? ink.opacity(0.06) : .clear,
                    in: RoundedRectangle(cornerRadius: 3))
    }

    /// The tracked train's arrival here, pinned above the departures.
    private func trackedBanner(_ tracked: TrackedTrain) -> some View {
        let arrival = entry.trackedLive?.arrives
        let status = arrival?.status ?? .onTime
        let note = arrival?.hasHappened == true ? "arrived" : arrivalNote(status)
        return HStack(spacing: 6) {
            Image(systemName: "pin.fill").font(.system(size: 8)).widgetAccentable()
            Text(compact ? ukClock(tracked.departs) : "\(ukClock(tracked.departs)) from \(tracked.from.name)")
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 8)
            Text(status == .cancelled ? "--:--" : ukClock(arrival?.expected ?? tracked.arrives)).bold()
            if !compact { Text(note).foregroundStyle(color(status)).padding(.leading, 4) }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(ink.opacity(0.22), in: RoundedRectangle(cornerRadius: 3))
    }

    // MARK: Status wording and colour

    private func text(_ status: TrainTime.Status) -> String {
        switch status {
        case .onTime: "On time"
        case .late(let expected): ukClock(expected)
        case .delayed: "Delayed"
        case .cancelled: "Cancelled"
        }
    }

    private func arrivalNote(_ status: TrainTime.Status) -> String {
        switch status {
        case .onTime: "on time"
        case .late: "\(entry.trackedLive?.arrives.minutesLate ?? 0) min late"
        case .delayed: "delayed"
        case .cancelled: "cancelled"
        }
    }

    private func color(_ status: TrainTime.Status) -> Color {
        switch status {
        case .onTime: good
        case .late, .delayed: warning
        case .cancelled: .red
        }
    }
}
