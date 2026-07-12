import SwiftUI

@main
struct FatLossTrackerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .defaultSize(width: 1280, height: 900)
    }
}
