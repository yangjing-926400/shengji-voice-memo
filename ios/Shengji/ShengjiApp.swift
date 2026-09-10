import SwiftUI

@main
struct ShengjiApp: App {
    @StateObject private var store = NotesStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .tint(ShengjiTheme.ink)
                .preferredColorScheme(.light)
        }
    }
}
