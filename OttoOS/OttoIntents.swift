import AppIntents
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

/// Shortcuts building block: returns the rendered wallpaper as a PNG so an
/// automation can hand it to "Set Wallpaper" every morning.
struct MakeWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "Make OttoOS Wallpaper"
    static let description = IntentDescription("Builds today's lock screen wallpaper with your calendar, reminders and notes on your chosen photo.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let style = WallpaperStyle.load()
        let agenda = await OttoSources.fetch(kinds: style.sources, days: max(style.days, 2))
        let background = AppModel.loadBackground()
        guard let image = WallpaperRenderer.render(agenda: agenda, style: style, background: background),
              let png = image.pngData() else {
            throw IntentError.renderFailed
        }
        let file = IntentFile(data: png, filename: "OttoOS-wallpaper.png", type: .png)
        return .result(value: file)
    }

    enum IntentError: LocalizedError {
        case renderFailed
        var errorDescription: String? { "OttoOS could not render the wallpaper." }
    }
}

struct AddOttoNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Note to OttoOS"
    static let description = IntentDescription("Puts a note on your lock screen.")
    static let openAppWhenRun = false

    @Parameter(title: "Note", requestValueDialog: "What should the lock screen say?")
    var text: String

    @Parameter(title: "Pin to top", default: false)
    var pinned: Bool

    @Parameter(title: "When")
    var when: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try OttoSources.addNote(text, pinned: pinned, due: when)
        WidgetCenter.shared.reloadAllTimelines()
        if let when {
            return .result(dialog: "On the lock screen for \(when.formatted(date: .omitted, time: .shortened)).")
        }
        return .result(dialog: "On the lock screen.")
    }
}

struct OttoOSShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddOttoNoteIntent(),
            phrases: [
                "Add a note to \(.applicationName)",
                "Put a note on my lock screen with \(.applicationName)",
            ],
            shortTitle: "Add Note",
            systemImageName: "note.text.badge.plus"
        )
        AppShortcut(
            intent: MakeWallpaperIntent(),
            phrases: [
                "Make my \(.applicationName) wallpaper",
                "Refresh my \(.applicationName) lock screen",
            ],
            shortTitle: "Make Wallpaper",
            systemImageName: "photo.on.rectangle.angled"
        )
    }
}
