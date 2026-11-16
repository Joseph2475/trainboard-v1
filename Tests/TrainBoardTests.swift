import XCTest
import SwiftUI

/// Runs against saved API answers (Tests/Fixtures), so no network is needed.
final class TrainBoardTests: XCTestCase {
    private func fixture<T: Decodable>(_ name: String) throws -> T {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try Trainiac.decode(Data(contentsOf: url))
    }

    private func frattonBoard() throws -> BoardEntry {
        let departures: [Departure] = try fixture("departures-FTN")
        struct Journey: Decodable { let leg: DirectTrain }
        let journeys: [Journey] = try fixture("journey-WAT-FTN")
        let live = try XCTUnwrap(journeys.first?.leg)
        let tracked = TrackedTrain(uid: live.train.uid, from: Station(code: "WAT", name: "London Waterloo"),
                                   to: .fratton, departs: live.departs.scheduled, arrives: live.arrives.scheduled)
        return BoardEntry(date: departures[0].departs.scheduled, station: .fratton,
                          departures: departures, tracked: tracked, trackedLive: live)
    }

    // Trains not yet running have no live id; the board must still read them.
    func testBoardReadsTrainsThatAreNotRunningYet() throws {
        let departures: [Departure] = try fixture("departures-FTN")
        XCTAssertEqual(departures.count, 20)
        XCTAssert(departures.allSatisfy { !$0.train.uid.isEmpty })
    }

    func testTrackedTrainIsPickedOutOnTheBoard() throws {
        let board = try frattonBoard()
        XCTAssert(board.trackedArrivesHere)
        XCTAssertEqual(board.departures.filter(board.isTracked).count, 1)
    }

    func testStatusReadsCancellationsAndDelays() throws {
        let departures: [Departure] = try fixture("departures-FTN")
        XCTAssert(departures.contains { $0.departs.status == .cancelled })
        let late = TrainTime(scheduled: .distantPast,
                             estimate: .init(type: "forecast", at: .distantPast.addingTimeInterval(240)))
        XCTAssertEqual(late.minutesLate, 4)
        XCTAssertEqual(TrainTime(scheduled: .now, estimate: .init(type: "delayed_no_estimate", at: nil)).status, .delayed)
    }

    func testTrackedTrainLeavesTheBoardTwoMinutesAfterArriving() throws {
        let board = try frattonBoard()
        let arrival = try XCTUnwrap(board.trackedLive?.arrives.expected)
        XCTAssert(board.at(arrival.addingTimeInterval(60)).showsTracked)
        XCTAssertFalse(board.at(arrival.addingTimeInterval(3 * 60)).showsTracked)
    }

    func testDepartedTrainsDropOff() throws {
        let board = try frattonBoard()
        let later = board.at(board.departures[2].departs.expected.addingTimeInterval(1))
        XCTAssertLessThan(later.departures.count, board.departures.count)
        XCTAssert(later.departures.allSatisfy { $0.departs.expected >= later.date })
    }

    func testErrorAnswerThrowsTheAPIMessage() {
        let answer = Data(#"{"type":"error","error":{"message":"No station matches 'ZZZ'"}}"#.utf8)
        XCTAssertThrowsError(try Trainiac.decode(answer) as [Departure]) { error in
            XCTAssertEqual(error.localizedDescription, "No station matches 'ZZZ'")
        }
    }

    /// Saves each widget size as a PNG so the layout can be checked by eye.
    @MainActor
    func testRenderWidgetSizes() throws {
        let board = try frattonBoard()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("trainboard-renders")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // widget sizes measured on a MacBook desktop
        let sizes = [("small", CGSize(width: 160, height: 160), 5, true),
                     ("medium", CGSize(width: 345, height: 160), 5, false),
                     ("large", CGSize(width: 345, height: 362), 15, false)]
        for scheme in [ColorScheme.light, .dark] {
            for (name, size, rows, compact) in sizes {
                let renderer = ImageRenderer(content: BoardView(entry: board, rows: rows, compact: compact)
                    .padding(.horizontal, 10).padding(.vertical, 14)  // same margins as the widget
                    .frame(width: size.width, height: size.height)
                    .background(scheme == .dark ? Color(white: 0.15) : .white)
                    .environment(\.colorScheme, scheme))
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.cgImage)
                let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                try png.write(to: folder.appendingPathComponent("\(name)-\(scheme).png"))
            }
        }
        print("Renders in", folder.path)
    }
}
