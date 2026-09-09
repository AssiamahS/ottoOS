import Foundation
import SwiftUI

/// Where an agenda line came from. Every source is a real Apple store
/// (Calendar / Reminders), so the widget extension can read the same data
/// without an app group.
enum OttoSourceKind: String, CaseIterable, Codable, Identifiable {
    case calendar, reminders, notes
    var id: String { rawValue }

    var label: String {
        switch self {
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .notes: return "Otto notes"
        }
    }

    var symbol: String {
        switch self {
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        case .notes: return "note.text"
        }
    }
}

struct AgendaItem: Identifiable, Hashable {
    let id: String
    let kind: OttoSourceKind
    let title: String
    let start: Date?
    let end: Date?
    let isAllDay: Bool
    let color: Color
    let listName: String
    let isPinned: Bool

    var isOverdue: Bool {
        guard kind != .calendar, let start else { return false }
        return start < Date()
    }

    /// True while a calendar event is in progress.
    func isHappening(at now: Date) -> Bool {
        guard kind == .calendar, let start, let end else { return false }
        return start <= now && end > now
    }

    /// "9:30 AM", "All day", "Tue 2:00 PM", "" for undated notes.
    func timeLabel(relativeTo now: Date = Date()) -> String {
        guard let start else { return "" }
        if isAllDay { return Calendar.current.isDateInToday(start) ? "All day" : Self.dayFormatter.string(from: start) }
        if Calendar.current.isDateInToday(start) { return Self.timeFormatter.string(from: start) }
        return Self.dayTimeFormatter.string(from: start)
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    static let dayTimeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE h:mm a"; return f
    }()
}

struct Agenda {
    var items: [AgendaItem] = []
    var generated = Date()
    var calendarAccess = false
    var remindersAccess = false

    var events: [AgendaItem] { items.filter { $0.kind == .calendar } }
    var reminders: [AgendaItem] { items.filter { $0.kind == .reminders } }
    var notes: [AgendaItem] { items.filter { $0.kind == .notes } }
    var pinned: AgendaItem? { notes.first { $0.isPinned } }

    /// The event happening now, else the next one to start.
    func current(at now: Date = Date()) -> AgendaItem? {
        events.first { ($0.end ?? .distantPast) > now }
    }

    var openTaskCount: Int { items.filter { $0.kind != .calendar }.count }

    /// Sorted for display: pinned note, live/next events by start, then dated
    /// tasks by due date, then undated tasks and notes.
    func ordered(kinds: Set<OttoSourceKind>, now: Date = Date()) -> [AgendaItem] {
        let wanted = items.filter { kinds.contains($0.kind) && !($0.kind == .calendar && ($0.end ?? .distantFuture) < now) }
        return wanted.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            switch (a.start, b.start) {
            case let (x?, y?): return x < y
            case (nil, _?): return false
            case (_?, nil): return true
            default: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
    }
}

extension Set where Element == OttoSourceKind {
    static let all: Set<OttoSourceKind> = [.calendar, .reminders, .notes]
}
