import SwiftUI

@main
struct TrainBoardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var tracked = TrackedTrain.current

    var body: some View {
        Form {
            if let tracked {
                TrackedTrainSection(train: tracked) { save(nil) }
            } else {
                TrackTrainSections { save($0) }
            }
            Section {} footer: {
                Text("To add a board, right-click the desktop, choose Edit Widgets and add TrainBoard.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)  // window fits the form, no empty space below
        .scrollDisabled(true)  // so nothing to scroll and no scroll bar
    }

    private func save(_ train: TrackedTrain?) {
        TrackedTrain.current = train
        tracked = train
    }
}

// MARK: - Picking a train to track

struct TrackTrainSections: View {
    var onTrack: (TrackedTrain) -> Void

    enum When: String, CaseIterable {
        case leave = "Leave after"
        case arrive = "Arrive by"
    }

    @State private var from: Station?
    @State private var to: Station? = .fratton
    @State private var when = When.leave
    @State private var time: Date?  // nil means now
    @State private var trains: [DirectTrain] = []
    @State private var message: String?

    var body: some View {
        Section("Track a train") {
            StationField(label: "From", station: $from)
            StationField(label: "To", station: $to)
            Picker("When", selection: $when) {
                ForEach(When.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            Picker("Time", selection: $time) {
                Text("Now").tag(Date?.none)
                ForEach(quarterHoursLeftToday, id: \.self) { Text(ukClock($0)).tag(Date?.some($0)) }
            }
            // search again whenever anything above changes (on a row that's always there)
            .task(id: "\(from?.code ?? "")\(to?.code ?? "")\(when)\(time.map(ukClock) ?? "now")") { await search() }
        }
        Section {
            if let message {
                Text(message).foregroundStyle(.secondary)
            }
            ForEach(trains, id: \.train.uid) { train in
                LabeledContent {
                    Button("Track") { track(train) }
                } label: {
                    Text("\(ukClock(train.departs.scheduled)) to \(ukClock(train.arrives.scheduled))").monospacedDigit()
                    Text(train.train.headcode ?? "")
                }
            }
        }
    }

    // shortcut: today only, because the API only searches today's trains; add dates once it takes one
    private var quarterHoursLeftToday: [Date] {
        let uk = Trainiac.ukCalendar
        let midnight = uk.date(byAdding: .day, value: 1, to: uk.startOfDay(for: .now))!
        let nextQuarter = Date(timeIntervalSinceReferenceDate: (Date.now.timeIntervalSinceReferenceDate / 900).rounded(.up) * 900)
        return Array(stride(from: nextQuarter, to: midnight, by: 900))
    }

    private func search() async {
        trains = []
        guard let from, let to else { message = "Pick both stations to see trains."; return }
        message = "Searching..."
        do {
            switch when {
            case .leave:
                trains = try await Trainiac.directTrains(from: from.code, to: to.code, leavingFrom: time)
                message = trains.isEmpty ? "No direct trains left today." : nil
            case .arrive:
                // the API filters on departure, so search the three hours before and keep trains in on time
                let deadline = time ?? .now
                let earliest = max(deadline.addingTimeInterval(-3 * 3600), Trainiac.ukCalendar.startOfDay(for: deadline))
                let candidates = try await Trainiac.directTrains(from: from.code, to: to.code, leavingFrom: earliest,
                                                                 leavingBy: deadline, limit: 20)
                trains = Array(candidates.filter { $0.arrives.scheduled <= deadline }.suffix(6))
                message = trains.isEmpty ? "No direct trains get in by then." : nil
            }
        } catch {
            message = "Couldn't search: \(error.localizedDescription)"
        }
    }

    private func track(_ train: DirectTrain) {
        guard let from, let to else { return }
        onTrack(TrackedTrain(train, from: from, to: to))
    }
}

/// A search field that suggests stations as you type; picking one sets the station.
struct StationField: View {
    var label: String
    @Binding var station: Station?

    @State private var text = ""
    @State private var matches: [Station] = []

    var body: some View {
        TextField(label, text: $text, prompt: Text("Search stations"))
            .textInputSuggestions(matches, id: \.code) { match in
                Text(match.name).textInputCompletion(match.name)
            }
            .onAppear { text = station?.name ?? "" }
            .task(id: text) {
                guard text != station?.name else { return }
                if let picked = matches.first(where: named(text)) {  // a suggestion was picked
                    station = picked
                    matches = []
                    return
                }
                station = nil
                try? await Task.sleep(for: .milliseconds(250))  // let typing settle before searching
                guard !Task.isCancelled else { return }
                matches = (try? await Trainiac.stations(matching: text)) ?? []
                station = matches.first(where: named(text))  // the full name was typed
            }
    }

    private func named(_ text: String) -> (Station) -> Bool {
        { $0.name.localizedCaseInsensitiveCompare(text) == .orderedSame }
    }
}

// MARK: - The train being tracked

struct TrackedTrainSection: View {
    var train: TrackedTrain
    var onStop: () -> Void

    @State private var board: BoardEntry?

    var body: some View {
        Section("Tracking") {
            LabeledContent("Train", value: "\(ukClock(train.departs)) from \(train.from.name)")
            LabeledContent("Due at \(train.to.name)", value: ukClock(train.arrives))
            if let board {
                BoardView(entry: board)
                    .padding(.vertical, 8)
                    .frame(height: 160)
            }
            Button("Stop tracking", role: .destructive, action: onStop)
        }
        // refresh each minute, and stop tracking once the board has let the train go after it arrives
        .task {
            while !Task.isCancelled {
                board = await BoardEntry.load(train.to)
                if board?.showsTracked == false { return onStop() }
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}
