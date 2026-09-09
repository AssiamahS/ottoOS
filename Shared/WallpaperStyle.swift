import SwiftUI

/// Everything about how the note block is laid onto the wallpaper.
struct WallpaperStyle: Codable, Equatable {
    enum Position: String, Codable, CaseIterable, Identifiable {
        case top, middle, bottom
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }
    enum Ink: String, Codable, CaseIterable, Identifiable {
        case auto, white, black
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }
    enum Typeface: String, Codable, CaseIterable, Identifiable {
        case rounded, serif, mono
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var design: Font.Design {
            switch self {
            case .rounded: return .rounded
            case .serif: return .serif
            case .mono: return .monospaced
            }
        }
    }

    var position: Position = .middle
    var ink: Ink = .auto
    var typeface: Typeface = .rounded
    var dim: Double = 0.25          // 0…0.8 dark veil over the photo
    var blur: Double = 0            // 0…20 pt
    var showDate = true
    var sources: Set<OttoSourceKind> = .all
    var days = 2
    var maxItems = 8
    var scale: Double = 1.0         // text size multiplier

    static let key = "ottoos.wallpaperStyle"

    static func load(from defaults: UserDefaults = .standard) -> WallpaperStyle {
        guard let data = defaults.data(forKey: key),
              let s = try? JSONDecoder().decode(WallpaperStyle.self, from: data) else { return WallpaperStyle() }
        return s
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}

/// Lock-screen safe zones in points for a 393×852 canvas, scaled to the
/// real size at render time. Clock + widgets own the top, the flashlight
/// and camera buttons own the bottom.
enum LockScreenLayout {
    static let referenceSize = CGSize(width: 393, height: 852)
    static let topInset: CGFloat = 300
    static let bottomInset: CGFloat = 150
    static let sideInset: CGFloat = 28
}
