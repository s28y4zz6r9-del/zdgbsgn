import SwiftUI

@main
struct iMusicApp: App {
    @StateObject private var playerEngine = AudioHapticEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerEngine)
                .preferredColorScheme(.dark)
        }
    }
}
