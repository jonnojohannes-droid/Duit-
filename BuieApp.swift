import SwiftUI

@main
struct BuieApp: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(state)
        }
    }
}
