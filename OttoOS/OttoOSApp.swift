import SwiftUI
import WidgetKit
import EventKit
import Combine

@main
struct OttoOSApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .task { await model.bootstrap() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.refresh() } }
                }
                .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                    Task { await model.refresh() }
                }
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") { TodayView() }
            Tab("Wallpaper", systemImage: "photo.on.rectangle.angled") { WallpaperView() }
            Tab("Widgets", systemImage: "lock.rectangle.stack") { WidgetsGuideView() }
        }
    }
}
