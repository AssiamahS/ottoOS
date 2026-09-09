import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            List {
                if model.accessAsked && (!model.agenda.calendarAccess || !model.agenda.remindersAccess) {
                    Section {
                        Label("Calendar or Reminders access is off. OttoOS only shows what it can read.", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.orange)
                        TextField("Quick note for the lock screen", text: $draft)
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit(add)
                    }
                } footer: {
                    Text("Notes live in a Reminders list called “OttoOS”, so they sync with iCloud and show in every widget.")
                }

                let notes = model.agenda.ordered(kinds: [.notes])
                if !notes.isEmpty {
                    Section("Otto notes") {
                        ForEach(notes) { item in
                            row(item)
                                .swipeActions(edge: .leading) {
                                    Button { model.togglePin(item) } label: {
                                        Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                                    }.tint(.orange)
                                }
                        }
                    }
                }

                let events = model.agenda.ordered(kinds: [.calendar])
                Section("Calendar") {
                    if events.isEmpty { Text("No events in the next \(max(model.style.days, 2)) days").foregroundStyle(.secondary) }
                    ForEach(events) { row($0) }
                }

                let reminders = model.agenda.ordered(kinds: [.reminders])
                if !reminders.isEmpty {
                    Section("Reminders") { ForEach(reminders) { row($0) } }
                }

                if let err = model.lastError {
                    Section { Text(err).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Today")
            .refreshable { await model.refresh() }
        }
    }

    private func add() {
        model.addNote(draft)
        draft = ""
        focused = false
    }

    @ViewBuilder
    private func row(_ item: AgendaItem) -> some View {
        HStack(spacing: 12) {
            if item.kind == .calendar {
                RoundedRectangle(cornerRadius: 2).fill(item.color).frame(width: 4, height: 28)
            } else {
                Button {
                    model.complete(item)
                } label: {
                    Image(systemName: "circle").foregroundStyle(item.color)
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if item.isPinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.orange) }
                    Text(item.title).lineLimit(2)
                }
                let parts: [String?] = [item.timeLabel(), item.kind == .notes ? nil : item.listName]
                let sub = parts
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                if !sub.isEmpty {
                    Text(sub).font(.caption).foregroundStyle(item.isOverdue ? Color.orange : Color.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if item.kind != .calendar {
                Button(role: .destructive) { model.delete(item) } label: { Label("Delete", systemImage: "trash") }
                Button { model.complete(item) } label: { Label("Done", systemImage: "checkmark") }.tint(.green)
            }
        }
    }
}
