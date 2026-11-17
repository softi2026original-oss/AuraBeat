import SwiftUI

@main
struct AuraBeatApp: App {
    @StateObject private var audioEngine = AudioEngine()
    @State private var showSplash: Bool = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                StudioView(audio: audioEngine)
                    .preferredColorScheme(.dark)

                if showSplash {
                    SplashScreenView {
                        showSplash = false
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
