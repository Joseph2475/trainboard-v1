import Foundation

/// Client for the traini.ac v1 API: live UK rail data, no key needed.
/// Docs: https://traini.ac/developers
enum Trainiac {
    static let ukTime = TimeZone(identifier: "Europe/London")!
    static let ukCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ukTime
        return calendar
    }()

    /// The next departures from a station, in timetable order like a station screen.
    static func departures(from crs: String, limit: Int = 20) async throws -> [Departure] {
        let rows: [Departure] = try await get("departures/\(crs)", ["limit": "\(limit)"])
        return rows.filter { $0.advertised != false }.sorted { $0.departs.scheduled < $1.departs.scheduled }
    }

    /// Stations whose name or code matches the text.
    static func stations(matching text: String) async throws -> [Station] {
        struct Found: Decodable {
            struct Match: Decodable { let type: String; let crs: String?; let name: String }
            let matches: [Match]
        }
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        let found: Found = try await get("stations", ["q": query])
        return found.matches.compactMap { match in
            guard match.type == "station", let crs = match.crs else { return nil }  // skip depots and junctions
            return Station(code: crs, name: match.name)
        }
    }

    /// Today's direct trains from one station to another, leaving between two times.
    /// No start means from now; no end means until midnight.
    static func directTrains(from: String, to: String, leavingFrom start: Date? = nil, leavingBy end: Date? = nil,
                             limit: Int = 8) async throws -> [DirectTrain] {
        struct Journey: Decodable { let leg: DirectTrain? }
        var query = ["max_changes": "0", "limit": "\(limit)"]
        query["from_time"] = start.map(apiClock.string)
        query["to_time"] = end.map(apiClock.string)
        let journeys: [Journey] = try await get("journey/\(from)/\(to)", query)
        return journeys.compactMap(\.leg)
    }

    // MARK: Plumbing

    private static func get<T: Decodable>(_ path: String, _ query: [String: String]) async throws -> T {
        var url = URLComponents(string: "https://api.traini.ac/v1/\(path)")!
        url.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        let (data, _) = try await URLSession.shared.data(from: url.url!)
        return try decode(data)
    }

    /// Every answer is {type: "ok", data} or {type: "error", error: {message}}.
    private struct Answer<T: Decodable>: Decodable {
        struct Problem: Decodable { let message: String }
        let type: String
        let data: T?
        let error: Problem?
    }

    static func decode<T: Decodable>(_ data: Data) throws -> T {
        let answer = try decoder.decode(Answer<T>.self, from: data)
        guard answer.type == "ok", let value = answer.data else {
            throw APIError(message: answer.error?.message ?? "The API sent no data")
        }
        return value
    }

    /// The API takes times as 24-hour UK clock times ("12:50"), whatever the Mac shows.
    private static let apiClock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = ukTime
        return formatter
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}

// MARK: - What the API sends back

struct Station: Hashable, Codable {
    let code: String  // CRS code, e.g. FTN
    let name: String

    static let fratton = Station(code: "FTN", name: "Fratton")
}

struct Train: Decodable {
    let uid: String  // timetable id; the live id stays null until a train starts running
    let headcode: String?
}

/// When a train is due somewhere, and the railway's latest word on it.
struct TrainTime: Decodable {
    struct Estimate: Decodable {
        let type: String  // forecast, actual, cancelled, delayed_no_estimate or no_information
        let at: Date?
    }

    enum Status: Equatable {
        case onTime, late(expected: Date), delayed, cancelled
    }

    let scheduled: Date
    let estimate: Estimate?

    var expected: Date { estimate?.at ?? scheduled }
    var hasHappened: Bool { estimate?.type == "actual" }
    var minutesLate: Int { Int(expected.timeIntervalSince(scheduled) / 60) }

    var status: Status {
        switch estimate?.type {
        case "cancelled": .cancelled
        case "delayed_no_estimate": .delayed
        default: minutesLate > 0 ? .late(expected: expected) : .onTime
        }
    }
}

struct Departure: Decodable {
    struct Place: Decodable {
        let name: String
        let crs: String?
        var code: String { crs ?? name }  // three-letter code, e.g. PMH
    }
    struct Platform: Decodable { let number: String? }

    let train: Train
    let destination: Place
    let departs: TrainTime
    let platform: Platform?
    let advertised: Bool?
}

struct DirectTrain: Decodable {
    let train: Train
    let departs: TrainTime
    let arrives: TrainTime
}

/// Hours and minutes on the UK clock, whatever the Mac's time zone. 12 or 24 hour follows the
/// Mac's own setting (System Settings, General, Date and Time).
func ukClock(_ date: Date) -> String { ukClockFormatter.string(from: date) }

/// True when the Mac shows 12-hour time ("11:14 pm"), so time columns can be wider.
let clockIsTwelveHour = ukClockFormatter.dateFormat.contains("a")

private let ukClockFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.setLocalizedDateFormatFromTemplate("jmm")  // j: the hour style the Mac is set to
    formatter.timeZone = Trainiac.ukTime
    return formatter
}()
