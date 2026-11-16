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
        VStack(alignment: .leading, spacing: 16) {
            Text("TrainBoard").font(.title2.bold())
            Text("Right-click the desktop, choose Edit Widgets and add a TrainBoard. Right-click a widget and choose Edit to pick its station.")
                .foregroundStyle(.secondary)
            Divider()
            if let tracked {
                TrackedTrainCard(train: tracked) { save(nil) }
            } else {
                TrackTrainForm { save($0) }
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func save(_ train: TrackedTrain?) {
        TrackedTrain.current = train
        tracked = train
    }
}

// MARK: - Picking a train to track

struct TrackTrainForm: View {
    var onTrack: (TrackedTrain) -> Void

    @State private var from: Station?
    @State private var to: Station? = .fratton
    @State private var time = ""
    @State private var trains: [DirectTrain] = []
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Track a train").font(.headline)
            StationField(label: "From", station: $from)
            StationField(label: "To", station: $to)
            HStack {
                TextField("Leaves at, e.g. 12:50 (blank for now)", text: $time)
                Button("Find trains") { Task { await search() } }
                    .disabled(from == nil || to == nil)
                    .keyboardShortcut(.defaultAction)
            }
            if let message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            ForEach(trains, id: \.train.uid) { train in
                HStack {
                    Text("\(ukClock(train.departs.scheduled)) to \(ukClock(train.arrives.scheduled))").monospacedDigit()
                    Text(train.train.headcode ?? "").foregroundStyle(.secondary)
                    Spacer()
                    Button("Track") { track(train) }
                }
            }
        }
    }

    private func search() async {
        guard let from, let to else { return }
        message = "Searching..."
        trains = []
        do {
            trains = try await Trainiac.directTrains(from: from.code, to: to.code,
                                                     leavingFrom: time.trimmingCharacters(in: .whitespaces))
            message = trains.isEmpty ? "No direct trains found today." : nil
        } catch {
            message = "Couldn't search: \(error.localizedDescription)"
        }
    }

    private func track(_ train: DirectTrain) {
        guard let from, let to else { return }
        onTrack(TrackedTrain(uid: train.train.uid, from: from, to: to,
                             departs: train.departs.scheduled, arrives: train.arrives.scheduled))
    }
}

/// Type part of a name, then pick the station from the matches.
struct StationField: View {
    var label: String
    @Binding var station: Station?

    @State private var text = ""
    @State private var matches: [Station] = []

    var body: some View {
        if let station {
            HStack {
                Text("\(label): \(station.name)")
                Spacer()
                Button("Change") { self.station = nil }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                TextField(label, text: $text)
                    .task(id: text) {
                        try? await Task.sleep(for: .milliseconds(250))  // let typing settle before searching
                        guard !Task.isCancelled else { return }
                        matches = (try? await Trainiac.stations(matching: text)) ?? []
                    }
                ForEach(matches.prefix(5), id: \.code) { match in
                    Button("\(match.name) (\(match.code))") { station = match }
                        .buttonStyle(.link)
                }
            }
        }
    }
}

// MARK: - The train being tracked

struct TrackedTrainCard: View {
    var train: TrackedTrain
    var onStop: () -> Void

    @State private var board: BoardEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tracking the \(ukClock(train.departs)) from \(train.from.name)").font(.headline)
            Text("Due at \(train.to.name) at \(ukClock(train.arrives)). Your \(train.to.name) widgets pick it out.")
                .foregroundStyle(.secondary)
            if let board {
                BoardView(entry: board, rows: 6)
                    .padding(12)
                    .frame(height: 170)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
            }
            Button("Stop tracking", action: onStop)
        }
        .task { board = await BoardEntry.load(train.to) }
    }
}
