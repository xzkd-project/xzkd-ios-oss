//
//  CurriculumExtensions.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import EventKit
import Foundation
import SwiftUI
import SwiftyJSON

struct CurriculumBehavior {
    var shownTimes: [Int] = []
    var highLightTimes: [Int] = []

    var convertTo: (Int) -> Int = { $0 }
    var convertFrom: (Int) -> Int = { $0 }
}

/// Usage: `class exampleDelegaet: CurriculumProtocolA & CurriculumProtocol`
class CurriculumProtocolA<T>: ManagedRemoteUpdateProtocol<Curriculum> {
    func refreshSemesterList() async throws -> [T] {
        assert(true)
        return []
    }
    func refreshSemester(id: T) async throws -> Semester {
        assert(true)
        return .example
    }

    /// Parrallel refresh the whole curriculum
    override func refresh() async throws -> Curriculum {
        var result = Curriculum(semesters: [])
        let semesterList = try await refreshSemesterList()
        await withTaskGroup(of: Semester?.self) { group in
            for id in semesterList {
                group.addTask { try? await self.refreshSemester(id: id) }
            }

            for await child in group {
                if let child {
                    result.semesters.append(child)
                }
            }
        }
        
        result.semesters = result.semesters
            .filter { !$0.courses.isEmpty }
            .sorted { $0.startDate > $1.startDate }
        
        if result.semesters.isEmpty {
            throw BaseError.runtimeError("No courses found")
        }
        
        return result
    }
}

/// - Note: Useful when semester startDate is not provided in `refreshSemesterList`
class CurriculumProtocolB: ManagedRemoteUpdateProtocol<Curriculum> {
    /// Return more info than just id and name, like start date and end date, but have empty courses
    func refreshSemesterBase() async throws -> [Semester] {
        assert(true)
        return []
    }

    func refreshSemester(inComplete: Semester) async throws -> Semester {
        assert(true)
        return .example
    }

    /// Parrallel refresh the whole curriculum
    override func refresh() async throws -> Curriculum {
        var result = Curriculum(semesters: [])
        let incompleteSemesters = try await refreshSemesterBase()
        await withTaskGroup(of: Semester?.self) { group in
            for semester in incompleteSemesters {
                group.addTask {
                    try? await self.refreshSemester(inComplete: semester)
                }
            }

            for await child in group {
                if let child {
                    result.semesters.append(child)
                }
            }
        }

        // Remove semesters with no courses
        result.semesters = result.semesters
            .filter { !$0.courses.isEmpty }
            .sorted { $0.startDate > $1.startDate }
        
        if result.semesters.isEmpty {
            throw BaseError.runtimeError("No courses found")
        }

        return result
    }
}

struct GeoLocationData: Codable, Equatable, ExampleDataProtocol {
    var name: String
    var latitude: Double
    var longitude: Double

    static let example = GeoLocationData(
        name: "东区体育中心",
        latitude: 31.835946350451458,
        longitude: 117.2660348207498
    )
}

class GeoLocationDelegate: ManagedRemoteUpdateProtocol<[GeoLocationData]> {
    static let shared = GeoLocationDelegate()

    override func refresh() async throws -> [GeoLocationData] {
        let url = SchoolExport.shared.geoLocationDataURL

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSON(data: data)
        return json["locations"].arrayValue
            .map {
                let name = $0["name"].stringValue
                let latitude = $0["latitude"].doubleValue
                let longitude = $0["longitude"].doubleValue
                return GeoLocationData(
                    name: name,
                    latitude: latitude,
                    longitude: longitude
                )
            }
    }
}

extension ManagedDataSource<[GeoLocationData]> {
    static let geoLocation = ManagedDataSource(
        local: ManagedLocalStorage("geoLocation"),
        remote: GeoLocationDelegate.shared
    )
}

struct BuildingImgMappingData: Codable, ExampleDataProtocol {
    struct Mapping: Codable {
        var regex: String
        var path: String
    }
    var data: [Mapping]

    static let example = BuildingImgMappingData(data: [
        Mapping(regex: ".*", path: "https://example.com/default.png")
    ])

    func getURL(baseURL: URL = SchoolExport.shared.buildingimgBaseURL, buildingName: String) -> URL? {
        if let mapping =
            (data.first {
                buildingName.range(of: $0.regex, options: .regularExpression) != nil
            })
        {
            return baseURL.appendingPathComponent(mapping.path)
        }
        return nil
    }
}

class BuildingImgMappingDelegate: ManagedRemoteUpdateProtocol<BuildingImgMappingData> {
    static let shared = BuildingImgMappingDelegate()

    override func refresh() async throws -> BuildingImgMappingData {
        let url = SchoolExport.shared.buildingimgMappingURL

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSON(data: data)
        return BuildingImgMappingData(
            data: json.arrayValue
                .map {
                    let regex = $0["regex"].stringValue
                    let path = $0["path"].stringValue
                    return BuildingImgMappingData.Mapping(regex: regex, path: path)
                }
        )
    }
}

extension ManagedDataSource<BuildingImgMappingData> {
    static let buildingImgMapping = ManagedDataSource(
        local: ManagedLocalStorage("buildingImgMapping"),
        remote: BuildingImgMappingDelegate.shared
    )
}

struct LectureLocationFactory {
    @ManagedData(.geoLocation) var geoLocation: [GeoLocationData]

    func makeEventWithLocation(
        from lectures: [Lecture],
        in store: EKEventStore = EKEventStore()
    ) async throws -> [EKEvent] {
        let locations: [GeoLocationData] = (try? await _geoLocation.retrive()) ?? []

        var result: [EKEvent] = []

        for lecture in lectures {
            let event = EKEvent(eventStore: store)
            event.title = lecture.name
            event.startDate = lecture.startDate
            event.endDate = lecture.endDate

            let locationName = lecture.location
            let location = locations.first {
                locationName.hasPrefix($0.name)
            }
            if let location {
                let ekLocation = EKStructuredLocation(title: locationName)
                ekLocation.geoLocation = CLLocation(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                event.structuredLocation = ekLocation
            } else {
                event.location = locationName
            }

            result.append(event)
        }

        return result
    }
}

extension Curriculum {
    func saveToCalendar() async throws {
        let eventStore = EKEventStore()
        if #available(iOS 17.0, *) {
            if EKEventStore.authorizationStatus(for: .event) != .fullAccess {
                try await eventStore.requestFullAccessToEvents()
            }
        } else {
            // Fallback on earlier versions
            if try await !eventStore.requestAccess(to: .event) {
                throw BaseError.runtimeError("Calendar access problem")
            }
        }

        let calendarName = "Curriculum".localized
        let calendars = eventStore.calendars(for: .event)
            .filter {
                $0.title == calendarName.localized
            }

        // try remove everything with that name in it
        for calendar in calendars {
            try eventStore.removeCalendar(calendar, commit: true)
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarName
        calendar.cgColor = Color.accentColor.cgColor
        calendar.source = eventStore.defaultCalendarForNewEvents?.source
        try eventStore.saveCalendar(calendar, commit: true)

        let lectures = semesters.flatMap(\.courses).flatMap(\.lectures).union()
        let events = try await LectureLocationFactory().makeEventWithLocation(from: lectures, in: eventStore)

        for event in events {
            event.calendar = calendar
            try eventStore.save(
                event,
                span: .thisEvent,
                commit: false
            )
        }
        try eventStore.commit()
    }
}
