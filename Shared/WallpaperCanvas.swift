import SwiftUI

/// The wallpaper itself: photo (or gradient) + dim + the note block.
/// Rendered by ImageRenderer at native pixel size, and shown scaled down as
/// the in-app preview. Uses no materials — ImageRenderer can't draw them.
struct WallpaperCanvas: View {
    let agenda: Agenda
    let style: WallpaperStyle
    let background: UIImage?
    let size: CGSize
    var now = Date()

    private var k: CGFloat { size.width / LockScreenLayout.referenceSize.width }

    private var inkColor: Color {
        switch style.ink {
        case .white: return .white
        case .black: return .black
        case .auto:
            guard let background else { return .white }
            return background.isMostlyBright ? .black : .white
        }
    }

    var body: some View {
        ZStack {
            backgroundLayer
            Color.black.opacity(style.dim)
            noteBlock
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let background {
            Image(uiImage: background)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
                .blur(radius: style.blur * k)
        } else {
            LinearGradient(colors: [Color(red: 0.09, green: 0.10, blue: 0.16), Color(red: 0.16, green: 0.12, blue: 0.30)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    private var noteBlock: some View {
        let items = agenda.ordered(kinds: style.sources, now: now)
        let shown = Array(items.prefix(style.maxItems))
        let font = style.typeface.design
        let base = 17 * k * style.scale

        return VStack(alignment: .leading, spacing: 8 * k) {
            if style.showDate {
                Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.system(size: base * 0.85, weight: .semibold, design: font))
                    .textCase(.uppercase)
                    .tracking(1.5 * k)
                    .opacity(0.8)
            }
            if let pinned = agenda.pinned, style.sources.contains(.notes) {
                Text(pinned.title)
                    .font(.system(size: base * 1.35, weight: .bold, design: font))
                    .lineLimit(3)
                    .padding(.bottom, 4 * k)
            }
            ForEach(shown.filter { !$0.isPinned }) { item in
                HStack(alignment: .firstTextBaseline, spacing: 10 * k) {
                    Image(systemName: item.kind == .calendar ? "circle.fill" : "circle")
                        .font(.system(size: base * 0.5))
                        .foregroundStyle(item.kind == .calendar ? item.color : inkColor)
                        .frame(width: base * 0.6)
                    Text(item.title)
                        .font(.system(size: base, weight: item.isHappening(at: now) ? .bold : .medium, design: font))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    let t = item.timeLabel(relativeTo: now)
                    if !t.isEmpty {
                        Text(t)
                            .font(.system(size: base * 0.8, weight: .medium, design: font))
                            .opacity(item.isOverdue ? 1 : 0.75)
                            .foregroundStyle(item.isOverdue ? Color.orange : inkColor)
                    }
                }
            }
            if items.isEmpty {
                Text(emptyLine)
                    .font(.system(size: base, weight: .medium, design: font))
                    .opacity(0.8)
            }
            if items.count > shown.count {
                Text("+\(items.count - shown.count) more")
                    .font(.system(size: base * 0.8, design: font))
                    .opacity(0.6)
            }
        }
        .foregroundStyle(inkColor)
        .shadow(color: inkColor == .white ? .black.opacity(0.55) : .white.opacity(0.4), radius: 6 * k, y: 1 * k)
        .frame(maxWidth: size.width - LockScreenLayout.sideInset * 2 * k, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: anchor)
        .padding(.top, LockScreenLayout.topInset * k)
        .padding(.bottom, LockScreenLayout.bottomInset * k)
        .padding(.horizontal, LockScreenLayout.sideInset * k)
    }

    private var anchor: Alignment {
        switch style.position {
        case .top: return .topLeading
        case .middle: return .leading
        case .bottom: return .bottomLeading
        }
    }

    private var emptyLine: String {
        if !agenda.calendarAccess && !agenda.remindersAccess { return "Allow Calendar & Reminders in OttoOS" }
        return "Nothing on the board. Enjoy the day."
    }
}

extension UIImage {
    /// Average luminance over a 1×1 downsample — enough to choose ink color.
    var isMostlyBright: Bool {
        guard let cg = cgImage else { return false }
        var pixel = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let lum = 0.299 * Double(pixel[0]) + 0.587 * Double(pixel[1]) + 0.114 * Double(pixel[2])
        return lum > 150
    }
}
