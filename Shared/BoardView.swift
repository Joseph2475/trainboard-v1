import SwiftUI
import WidgetKit

/// A station departure board, in system colours so it sits with Apple's widgets.
/// macOS applies its own glass and tinted looks on top (System Settings, Desktop and Dock).
struct BoardView: View {
    var entry: BoardEntry
    var compact = false  // small widget: three-letter station codes so every column fits

    private let ink = Color.primary
    private let good = Color.green
    private let warning = Color.orange
    private var timeWidth: CGFloat { clockIsTwelveHour ? 50 : 36 }  // "11:14 pm" needs more room than "23:14"

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
                WholeRows(spacing: 3) {
                    ForEach(Array(entry.departures.enumerated()), id: \.offset) { index, departure in
                        row(departure, striped: index.isMultiple(of: 2) == false)
                    }
                }
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
        .padding(.horizontal, 8)  // further in than the rows, clear of the widget's rounded top corners
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
        return HStack(spacing: compact ? 5 : 6) {
            Text(ukClock(departure.departs.scheduled)).frame(width: timeWidth, alignment: .leading)
            HStack(spacing: 3) {
                if tracked { Image(systemName: "pin.fill").font(.system(size: 8)).widgetAccentable() }
                Text(compact ? departure.destination.code : departure.destination.name).truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(departure.platform?.number ?? "-").opacity(0.6).frame(width: compact ? 14 : 28)
            Text(text(status)).foregroundStyle(color(status))
                .minimumScaleFactor(0.7)  // "Cancelled" squeezes into the small widget
                .frame(width: compact ? 46 : 62, alignment: .leading)
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
            Text(compact ? "from \(tracked.from.code)" : "\(ukClock(tracked.departs)) from \(tracked.from.name)")
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 8)
            // the small widget has no room for the note, so the arrival time carries its colour
            Text(status == .cancelled ? "--:--" : ukClock(arrival?.expected ?? tracked.arrives)).bold()
                .foregroundStyle(compact ? color(status) : ink)
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

/// Stacks rows from the top and shows as many as fit whole, so a board fills any widget size
/// without a gap at the bottom or a half-cut row.
struct WholeRows: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()  // take all the room offered
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in subviews {
            let height = row.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            let fits = y + height <= bounds.maxY
            // rows that don't fit are placed below the bottom edge, where clipping hides them
            row.place(at: CGPoint(x: bounds.minX, y: fits ? y : bounds.maxY + 1),
                      proposal: ProposedViewSize(width: bounds.width, height: height))
            y = fits ? y + height + spacing : .infinity
        }
    }
}
