import SwiftUI
import WidgetKit
import UIKit

@MainActor
@Observable
final class AppModel {
    var agenda = Agenda()
    var style = WallpaperStyle.load() {
        didSet { style.save() }
    }
    var background: UIImage? = AppModel.loadBackground()
    var accessAsked = false
    var lastError: String?

    static let backgroundURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("background.jpg")
    }()

    func bootstrap() async {
        ScreenInfo.remember()
        if !OttoSources.hasCalendarAccess || !OttoSources.hasReminderAccess {
            await OttoSources.requestAccess()
        }
        accessAsked = true
        await refresh()
    }

    func refresh() async {
        agenda = await OttoSources.fetch(kinds: .all, days: max(style.days, 2))
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Notes

    func addNote(_ text: String, pinned: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        run { try OttoSources.addNote(trimmed, pinned: pinned) }
    }

    func complete(_ item: AgendaItem) { run { try OttoSources.complete(id: item.id) } }
    func delete(_ item: AgendaItem) { run { try OttoSources.delete(id: item.id) } }
    func togglePin(_ item: AgendaItem) { run { try OttoSources.setPinned(!item.isPinned, id: item.id) } }

    private func run(_ work: () throws -> Void) {
        do {
            try work()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        Task { await refresh() }
    }

    // MARK: Background photo

    func setBackground(data: Data) {
        guard let image = UIImage(data: data) else { return }
        // Keep at most 2× the screen so ImageRenderer stays quick.
        let target = ScreenInfo.pixelSize
        let scaled = image.downscaled(toFit: CGSize(width: target.width * 1.5, height: target.height * 1.5))
        background = scaled
        if let jpeg = scaled.jpegData(compressionQuality: 0.92) {
            try? jpeg.write(to: Self.backgroundURL, options: .atomic)
        }
    }

    func clearBackground() {
        background = nil
        try? FileManager.default.removeItem(at: Self.backgroundURL)
    }

    static func loadBackground() -> UIImage? {
        UIImage(contentsOfFile: backgroundURL.path)
    }
}

/// The intent that builds wallpapers can run with no window on screen, so the
/// app records the device's native size whenever it is in the foreground.
enum ScreenInfo {
    static let key = "ottoos.screenPixelSize"

    static func remember() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let b = scene.screen.nativeBounds
        UserDefaults.standard.set([Double(b.width), Double(b.height), Double(scene.screen.nativeScale)], forKey: key)
    }

    static var pixelSize: CGSize {
        if let v = UserDefaults.standard.array(forKey: key) as? [Double], v.count == 3 {
            return CGSize(width: v[0], height: v[1])
        }
        return CGSize(width: 1179, height: 2556)
    }

    static var scale: CGFloat {
        if let v = UserDefaults.standard.array(forKey: key) as? [Double], v.count == 3 { return v[2] }
        return 3
    }
}

extension UIImage {
    func downscaled(toFit box: CGSize) -> UIImage {
        let ratio = min(box.width / size.width, box.height / size.height, 1)
        guard ratio < 1 else { return self }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
