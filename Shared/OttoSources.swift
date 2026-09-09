import EventKit
import SwiftUI

/// Single reader/writer for every source OttoOS pulls from.
/// - Calendar events come straight from EventKit.
/// - Reminders come from every reminder list except OttoOS's own.
/// - "Otto notes" are reminders kept in a dedicated "OttoOS" list, which
///   gives us iCloud sync + widget visibility for free (a widget extension
///   can read EventKit once the host app has been granted access).
enum OttoSources {
    static let noteListName = "OttoOS"
    static let store = EKEventStore()

    static var hasCalendarAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    static var hasReminderAccess: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }

    /// Main app only — extensions cannot prompt.
    @discardableResult
    static func requestAccess() async -> (calendar: Bool, reminders: Bool) {
        let cal = (try? await store.requestFullAccessToEvents()) ?? false
        let rem = (try? await store.requestFullAccessToReminders()) ?? false
        return (cal, rem)
    }

    // MARK: Fetch

    static func fetch(kinds: Set<OttoSourceKind> = .all, days: Int = 2, now: Date = Date()) async -> Agenda {
        var agenda = Agenda(generated: now,
                            calendarAccess: hasCalendarAccess,
                            remindersAccess: hasReminderAccess)
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: now)
        let horizon = cal.date(byAdding: .day, value: max(1, days), to: dayStart) ?? dayStart.addingTimeInterval(86_400)

        if kinds.contains(.calendar), agenda.calendarAccess {
            let predicate = store.predicateForEvents(withStart: dayStart, end: horizon, calendars: nil)
            let events = store.events(matching: predicate)
                .filter { $0.status != .canceled }
                .sorted { $0.startDate < $1.startDate }
            agenda.items += events.map { e in
                AgendaItem(id: "ev:" + (e.eventIdentifier ?? UUID().uuidString) + ":" + String(Int(e.startDate.timeIntervalSince1970)),
                           kind: .calendar,
                           title: e.title ?? "Untitled",
                           start: e.startDate,
                           end: e.endDate,
                           isAllDay: e.isAllDay,
                           color: Color(cgColor: e.calendar.cgColor),
                           listName: e.calendar.title,
                           isPinned: false)
            }
        }

        if (kinds.contains(.reminders) || kinds.contains(.notes)), agenda.remindersAccess {
            let ottoList = try? noteList(create: false)
            let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
            let reminders = await fetchReminders(matching: predicate)
            for r in reminders {
                let isNote = ottoList.map { r.calendar.calendarIdentifier == $0.calendarIdentifier } ?? false
                let kind: OttoSourceKind = isNote ? .notes : .reminders
                guard kinds.contains(kind) else { continue }
                let due = r.dueDateComponents.flatMap { cal.date(from: $0) }
                // Reminders due past the horizon stay off the lock screen; undated ones are shown.
                if let due, due >= horizon { continue }
                agenda.items.append(AgendaItem(id: "rm:" + r.calendarItemIdentifier,
                                               kind: kind,
                                               title: r.title ?? "Untitled",
                                               start: due,
                                               end: nil,
                                               isAllDay: due != nil && r.dueDateComponents?.hour == nil,
                                               color: Color(cgColor: r.calendar.cgColor),
                                               listName: r.calendar.title,
                                               isPinned: isNote && r.priority == 1))
            }
        }
        return agenda
    }

    private static func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { cont.resume(returning: $0 ?? []) }
        }
    }

    // MARK: Otto notes (reminders in the OttoOS list)

    static func noteList(create: Bool) throws -> EKCalendar? {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == noteListName }) {
            return existing
        }
        guard create else { return nil }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = noteListName
        list.cgColor = UIColor.systemOrange.cgColor
        guard let source = store.defaultCalendarForNewReminders()?.source
                ?? store.sources.first(where: { $0.sourceType == .calDAV })
                ?? store.sources.first(where: { $0.sourceType == .local })
                ?? store.sources.first else {
            throw OttoError.noReminderSource
        }
        list.source = source
        try store.saveCalendar(list, commit: true)
        return list
    }

    @discardableResult
    static func addNote(_ text: String, pinned: Bool = false, due: Date? = nil) throws -> EKReminder {
        guard let list = try noteList(create: true) else { throw OttoError.noReminderSource }
        let r = EKReminder(eventStore: store)
        r.title = text
        r.calendar = list
        r.priority = pinned ? 1 : 0
        if let due {
            r.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        }
        try store.save(r, commit: true)
        return r
    }

    static func setPinned(_ pinned: Bool, id: String) throws {
        guard let r = reminder(for: id) else { return }
        r.priority = pinned ? 1 : 0
        try store.save(r, commit: true)
    }

    static func complete(id: String) throws {
        guard let r = reminder(for: id) else { return }
        r.isCompleted = true
        try store.save(r, commit: true)
    }

    static func delete(id: String) throws {
        guard let r = reminder(for: id) else { return }
        try store.remove(r, commit: true)
    }

    private static func reminder(for agendaID: String) -> EKReminder? {
        let raw = agendaID.hasPrefix("rm:") ? String(agendaID.dropFirst(3)) : agendaID
        return store.calendarItem(withIdentifier: raw) as? EKReminder
    }

    enum OttoError: LocalizedError {
        case noReminderSource
        var errorDescription: String? { "No Reminders account is available to hold the OttoOS list." }
    }
}
