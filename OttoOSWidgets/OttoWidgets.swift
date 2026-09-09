import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration

enum OttoSourceChoice: String, AppEnum {
    case all, calendar, reminders, notes

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Source")
    static let caseDisplayRepresentations: [OttoSourceChoice: DisplayRepresentation] = [
        .all: "Everything",
        .calendar: "Calendar",
        .reminders: "Reminders",
        .notes: "Otto notes",
    ]

    var kinds: Set<OttoSourceKind> {
        switch self {
        case .all: return .all
        case .calendar: return [.calendar]
        case .reminders: return [.reminders]
        case .notes: return [.notes]
        }
    }
}

enum OttoTheme: String, AppEnum {
    case ink, midnight, sunrise, paper

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Look")
    static let caseDisplayRepresentations: [OttoTheme: DisplayRepresentation] = [
        .ink: "Ink",
        .midnight: "Midnight",
        .sunrise: "Sunrise",
        .paper: "Paper",
    ]

    var gradient: LinearGradient {
        switch self {
        case .ink: return LinearGradient(colors: [Color(red: 0.11, green: 0.11, blue: 0.13), Color(red: 0.20, green: 0.20, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .midnight: return LinearGradient(colors: [Color(red: 0.05, green: 0.08, blue: 0.22), Color(red: 0.18, green: 0.10, blue: 0.35)], startPoint: .top, endPoint: .bottom)
        case .sunrise: return LinearGradient(colors: [Color(red: 0.98, green: 0.55, blue: 0.25), Color(red: 0.85, green: 0.25, blue: 0.40)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .paper: return LinearGradient(colors: [Color(red: 0.98, green: 0.97, blue: 0.93), Color(red: 0.93, green: 0.91, blue: 0.85)], startPoint: .top, endPoint: .bottom)
        }
    }

    var ink: Color { self == .paper ? .black : .white }
}

struct OttoWidgetConfig: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "OttoOS"
    static let description = IntentDescription("Choose what the widget pulls from.")

    @Parameter(title: "Show", default: .all)
    var source: OttoSourceChoice

    @Parameter(title: "Look", default: .ink)
    var theme: OttoTheme
}

// MARK: - Timeline

struct OttoEntry: TimelineEntry {
    let date: Date
    let agenda: Agenda
    let config: OttoWidgetConfig
}

struct OttoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OttoEntry {
        OttoEntry(date: Date(), agenda: .sample, config: OttoWidgetConfig())
    }

    func snapshot(for configuration: OttoWidgetConfig, in context: Context) async -> OttoEntry {
        if context.isPreview { return placeholder(in: context) }
        let agenda = await OttoSources.fetch(kinds: configuration.source.kinds, days: 2)
        return OttoEntry(date: Date(), agenda: agenda, config: configuration)
    }

    func timeline(for configuration: OttoWidgetConfig, in context: Context) async -> Timeline<OttoEntry> {
        let now = Date()
        let agenda = await OttoSources.fetch(kinds: configuration.source.kinds, days: 2, now: now)

        // One entry now, then one at every event boundary today so "Now / Next"
        // flips on time without waiting for a refresh.
        var dates: [Date] = [now]
        let endOfDay = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        let boundaries = agenda.events.flatMap { [$0.start, $0.end] }.compactMap { $0 }
            .filter { $0 > now && $0 < endOfDay }
        dates += Array(Set(boundaries)).sorted().prefix(12)

        let entries = dates.map { OttoEntry(date: $0, agenda: agenda, config: configuration) }
        let hour = Calendar.current.component(.hour, from: now)
        let awake = (7..<23).contains(hour)
        let refresh = min(endOfDay, now.addingTimeInterval(awake ? 20 * 60 : 60 * 60))
        return Timeline(entries: entries, policy: .after(refresh))
    }
}

extension Agenda {
    static var sample: Agenda {
        let now = Date()
        var a = Agenda(calendarAccess: true, remindersAccess: true)
        a.items = [
            AgendaItem(id: "1", kind: .notes, title: "Ship the lock screen build", start: nil, end: nil, isAllDay: false, color: .orange, listName: "OttoOS", isPinned: true),
            AgendaItem(id: "2", kind: .calendar, title: "Standup", start: now.addingTimeInterval(1800), end: now.addingTimeInterval(3600), isAllDay: false, color: .blue, listName: "Work", isPinned: false),
            AgendaItem(id: "3", kind: .reminders, title: "Call the pharmacy", start: now.addingTimeInterval(7200), end: nil, isAllDay: false, color: .green, listName: "Reminders", isPinned: false),
            AgendaItem(id: "4", kind: .calendar, title: "Gym", start: now.addingTimeInterval(14_400), end: now.addingTimeInterval(18_000), isAllDay: false, color: .red, listName: "Personal", isPinned: false),
        ]
        return a
    }
}

// MARK: - Views

struct OttoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: OttoEntry

    private var items: [AgendaItem] { entry.agenda.ordered(kinds: entry.config.source.kinds, now: entry.date) }
    private var needsAccess: Bool { !entry.agenda.calendarAccess && !entry.agenda.remindersAccess }

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        default: home
        }
    }

    // Lock screen — above the clock
    private var inline: some View {
        Group {
            if needsAccess {
                Text("Open OttoOS to allow access")
            } else if let pinned = entry.agenda.pinned, entry.config.source != .calendar {
                Label(pinned.title, systemImage: "pin.fill")
            } else if let next = entry.agenda.current(at: entry.date), entry.config.source != .reminders, entry.config.source != .notes {
                Label("\(next.isHappening(at: entry.date) ? "Now" : next.timeLabel(relativeTo: entry.date)) · \(next.title)", systemImage: "calendar")
            } else if let first = items.first {
                Label(first.title, systemImage: first.kind.symbol)
            } else {
                Label("Clear board", systemImage: "checkmark.circle")
            }
        }
    }

    // Lock screen — round
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: entry.config.source == .calendar ? "calendar" : "checklist")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(items.count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
            .widgetAccentable()
        }
    }

    // Lock screen — wide
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if needsAccess {
                Text("Open OttoOS").font(.headline)
                Text("Allow Calendar & Reminders").font(.caption2)
            } else if items.isEmpty {
                Text("Clear board").font(.headline).widgetAccentable()
                Text("Nothing due. Enjoy it.").font(.caption2)
            } else {
                ForEach(items.prefix(3)) { item in
                    HStack(spacing: 4) {
                        Image(systemName: item.isPinned ? "pin.fill" : (item.kind == .calendar ? "circle.fill" : "circle"))
                            .font(.system(size: 7))
                        Text(item.title)
                            .font(item.id == items.first?.id ? .headline : .caption)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        let t = item.timeLabel(relativeTo: entry.date)
                        if !t.isEmpty {
                            Text(item.isHappening(at: entry.date) ? "Now" : t)
                                .font(.caption2)
                        }
                    }
                    .widgetAccentable(item.id == items.first?.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Home screen + StandBy
    private var home: some View {
        let theme = entry.config.theme
        let limit = family == .systemSmall ? 3 : (family == .systemMedium ? 4 : 9)
        let shown = Array(items.prefix(limit))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.date, format: .dateTime.weekday(.wide).day())
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .opacity(0.7)
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(theme.ink.opacity(0.15)))
                }
            }
            if needsAccess {
                Text("Open OttoOS to allow Calendar & Reminders").font(.footnote)
            } else if shown.isEmpty {
                Text("Clear board.").font(.headline)
                Text("Nothing due today.").font(.footnote).opacity(0.7)
            } else {
                ForEach(shown) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: item.isPinned ? "pin.fill" : (item.kind == .calendar ? "circle.fill" : "circle"))
                            .font(.system(size: 8))
                            .foregroundStyle(item.kind == .calendar ? item.color : theme.ink)
                        Text(item.title)
                            .font(item.isPinned ? .subheadline.weight(.bold) : .subheadline)
                            .lineLimit(family == .systemSmall ? 1 : 2)
                        Spacer(minLength: 0)
                        if family != .systemSmall {
                            let t = item.timeLabel(relativeTo: entry.date)
                            if !t.isEmpty {
                                Text(item.isHappening(at: entry.date) ? "Now" : t)
                                    .font(.caption2)
                                    .opacity(0.75)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.ink)
        .containerBackground(for: .widget) { theme.gradient }
    }
}

// MARK: - Widgets

struct OttoLockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "com.djsly.ottoos.lock", intent: OttoWidgetConfig.self, provider: OttoProvider()) { entry in
            OttoWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Lock Screen Note")
        .description("Calendar, reminders and Otto notes right on your lock screen.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct OttoHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "com.djsly.ottoos.home", intent: OttoWidgetConfig.self, provider: OttoProvider()) { entry in
            OttoWidgetView(entry: entry)
        }
        .configurationDisplayName("Agenda")
        .description("Today's events, reminders and notes on a coloured card.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct OttoOSWidgetBundle: WidgetBundle {
    var body: some Widget {
        OttoLockWidget()
        OttoHomeWidget()
    }
}
