import SwiftUI
import Photos

enum WallpaperRenderer {
    /// Renders the canvas at the device's native pixel size.
    @MainActor
    static func render(agenda: Agenda, style: WallpaperStyle, background: UIImage?) -> UIImage? {
        let px = ScreenInfo.pixelSize
        let scale = ScreenInfo.scale
        let pts = CGSize(width: px.width / scale, height: px.height / scale)
        let canvas = WallpaperCanvas(agenda: agenda, style: style, background: background, size: pts)
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(pts)
        return renderer.uiImage
    }

    /// Adds the image to Photos (add-only permission). Returns an error string on failure.
    static func saveToPhotos(_ image: UIImage) async -> String? {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return "Allow OttoOS to add to Photos in Settings."
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
