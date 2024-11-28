// Made by Lumaa
// This allows for the app to run without errors, due to the original ``AppDelegate`` class using APIs that aren't accessible in WidgetKit

class AppDelegate {
    static let shared: AppDelegate = .init()
    func scheduleAppRefresh() { print("Life saved *scheduleAppRefresh*") }
}

