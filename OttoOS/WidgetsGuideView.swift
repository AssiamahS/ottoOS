import SwiftUI

struct WidgetsGuideView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section {
                    step(1, "Long-press your lock screen and tap Customize → Lock Screen.")
                    step(2, "Tap the widget area under the clock, then pick OttoOS.")
                    step(3, "Add the wide widget for your agenda, the round one for the open count, and the inline one above the clock for what's next.")
                    step(4, "Tap a widget to choose what it pulls from: everything, Calendar, Reminders, or Otto notes.")
                } header: {
                    Text("Lock screen widgets")
                } footer: {
                    Text("Widgets are live — they refresh on their own as the day moves, unlike the wallpaper picture.")
                }

                Section("Home screen & StandBy") {
                    Text("Long-press the home screen → Edit → Add Widget → OttoOS. The same widgets show in StandBy when the phone charges on its side.")
                        .font(.footnote)
                }

                Section("Sources") {
                    sourceRow("Calendar", ok: model.agenda.calendarAccess, symbol: "calendar")
                    sourceRow("Reminders", ok: model.agenda.remindersAccess, symbol: "checklist")
                    sourceRow("Otto notes (Reminders list “OttoOS”)", ok: model.agenda.remindersAccess, symbol: "note.text")
                    Button("Manage in Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }

                Section("Shortcuts") {
                    Text("Say “Add a note to OttoOS” or run **Make OttoOS Wallpaper** in a Shortcuts automation to rebuild the wallpaper each morning.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Widgets")
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(.orange))
                .foregroundStyle(.white)
            Text(text)
        }
    }

    private func sourceRow(_ name: String, ok: Bool, symbol: String) -> some View {
        HStack {
            Label(name, systemImage: symbol)
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ok ? Color.green : Color.secondary)
        }
    }
}
