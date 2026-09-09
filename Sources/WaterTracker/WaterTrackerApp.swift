import SwiftUI

@main
struct WaterTrackerApp: App {
    @State private var showingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showingSplash ? 0 : 1)

                if showingSplash {
                    SplashView { 
                        withAnimation(.easeOut(duration: 0.45)) { showingSplash = false }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}
