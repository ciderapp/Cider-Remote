// Made by Lumaa

import SwiftUI
import WidgetKit
import ActivityKit

class LiveActivityManager {
    @AppStorage("alertLiveActivity") private var alertLiveActivity: Bool = true

    static let shared: LiveActivityManager = .init()

    var device: Device? = nil

    var lastActivity: Activity<NowPlayingLiveActivity.NowPlayingAttributes>? = nil
    var activity: Activity<NowPlayingLiveActivity.NowPlayingAttributes>? {
        return Activity<NowPlayingLiveActivity.NowPlayingAttributes>.activities.first
    }

    func startActivity(using track: Track) {
        if activity != nil {
            Task {
                await self.updateActivity(with: track)
            }
            return
        }

        do {
            let cont: NowPlayingLiveActivity.NowPlayingAttributes.ContentState = .init(trackInfo: track)
            if #available(iOS 16.2, *) {
                self.lastActivity = try Activity
                    .request(
                        attributes: .init(),
                        content: .init(state: cont, staleDate: .now.addingTimeInterval(pow(10, 10)), relevanceScore: 9.0)
                    )
            } else {
                self.lastActivity = try Activity.request(attributes: .init(), contentState: cont)
            }
            print("STARTED LIVE ACTIVITY")
        } catch {
            print("Error while starting Live Activity: \(error)")
        }
    }

    func updateActivity(with content: NowPlayingLiveActivity.NowPlayingAttributes.ContentState) async {
        guard let activity else { return }
        await activity
            .update(
                using: content,
                alertConfiguration: alertLiveActivity ? .init(
                    title: "Cider Remote",
                    body: "Now Playing: \(content.trackInfo.title) by \(content.trackInfo.artist)",
                    sound: .default
                ) : nil
            )
        print("UPDATED1 LIVE ACTIVITY")
    }

    func updateActivity(with track: Track) async {
        guard let activity else { return }
        await activity
            .update(
                using: .init(trackInfo: track),
                alertConfiguration: alertLiveActivity ? .init(
                    title: "Cider Remote",
                    body: "Now Playing: \(track.title) by \(track.artist)",
                    sound: .default
                ) : nil
            )
        print("UPDATED2 LIVE ACTIVITY")
    }

    func stopActivity() {
        guard let activity else { return }
        
        Task {
            if #available(iOS 16.2, *) {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
            }
            print("STOPPED LIVE ACTIVITY")
        }
    }
}
