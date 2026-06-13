// Made by Lumaa

import UIKit
import ActivityKit
import BackgroundTasks

public class AppDelegate: UIResponder, UIApplicationDelegate, ObservableObject {
    static let shared: AppDelegate = .init()

    public func applicationWillTerminate(_ application: UIApplication) {
        print("App terminated")

        // this doesn't work
        if let activity = Activity<NowPlayingLiveActivity.NowPlayingAttributes>.activities.first {
            Task {
                if #available(iOS 16.2, *) {
                    await activity.end(activity.content, dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
                }
            }
        }
    }

//    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        print("registering BG TASKs")
//        BGTaskScheduler.shared.register(forTaskWithIdentifier: BGIdentifier.refreshLiveActivity.fullString, using: nil) { task in
//            guard let task = task as? BGAppRefreshTask else { return }
//            print("EXECUTING BG TASK")
//            self.handleAppRefresh(task: task)
//        }
//
//        #if DEBUG
//        BGTaskScheduler.shared.cancelAllTaskRequests()
//        #endif
//        // manually start BGTask with "e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"sh.cidercollective.Cider-Remote.BGTasks.refreshLiveActivity"]" in lldb
//        BGTaskScheduler.shared.getPendingTaskRequests { tasks in
//            print("\(tasks.count) PENDING task(s)")
//            if tasks.isEmpty {
//                self.scheduleAppRefresh()
//            }
//        }
//
//        return true
//    }
//
//    func scheduleAppRefresh() {
//        do {
//            let request = BGAppRefreshTaskRequest(identifier: BGIdentifier.refreshLiveActivity.fullString)
//            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // every 15 mins (minimum allowed by iOS)
//            try BGTaskScheduler.shared.submit(request)
//            print("SCHEDULED BG TASK")
//        } catch {
//            print("Could not schedule app refresh: \(error)")
//        }
//    }
//
//    func handleAppRefresh(task: BGAppRefreshTask) {
//        print("HANDLED BG TASK")
//        self.scheduleAppRefresh()
//
//        Task {
//            let success = await updateLiveActivity()
//            task.setTaskCompleted(success: success)
//        }
//    }
//
//    func updateLiveActivity() async -> Bool {
//        print("BG TASK OPERATING")
//
//        let liveActivity: LiveActivityManager = .shared
//        if let device = liveActivity.device {
//            let vm: MusicPlayerViewModel = .init(device: device)
//
//            await vm.getCurrentTrack()
//
//            if let track: Track = vm.currentTrack {
//                await liveActivity.updateActivity(with: track)
//                print("UPDATED using BG TASK")
//            }
//        } else {
//            liveActivity.stopActivity()
//            print("No device for BG TASK")
//            return false
//        }
//
//        return true
//    }
//
//    enum BGIdentifier: String {
//        case refreshLiveActivity = "refreshLiveActivity"
//
//        var fullString: String {
//            return "sh.cidercollective.Cider-Remote.BGTasks.\(self.rawValue)"
//        }
//    }
}
