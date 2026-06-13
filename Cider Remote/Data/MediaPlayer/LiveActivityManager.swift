// Made by Lumaa

import SwiftUI
import WidgetKit
import ActivityKit

class LiveActivityManager {
    @AppStorage("alertLiveActivity") private var alertLiveActivity: Bool = false

    static let shared: LiveActivityManager = .init()

    var device: Device? = nil

    var lastActivity: Activity<NowPlayingLiveActivity.NowPlayingAttributes>? = nil
    var activity: Activity<NowPlayingLiveActivity.NowPlayingAttributes>? {
        return Activity<NowPlayingLiveActivity.NowPlayingAttributes>.activities.first
    }

    func startActivity(using track: Track) {
        guard let device else { return }

        if activity != nil {
            Task {
                await self.updateActivity(with: track)
            }
            return
        }

        Task {
            let display: DisplayingTrack = Self.DisplayingTrack(from: track)
            let cont: NowPlayingLiveActivity.NowPlayingAttributes.ContentState = .init(
                trackInfo: display
            )
            
            if #available(iOS 16.2, *) {
                self.lastActivity = try Activity
                    .request(
                        attributes: .init(device: device),
                        content: .init(state: cont, staleDate: .now.addingTimeInterval(pow(10, 3) * 900), relevanceScore: 9.0)
                    )
            } else {
                self.lastActivity = try Activity.request(attributes: .init(device: device), contentState: cont)
            }
            print("STARTED LIVE ACTIVITY")
        }
    }

    func updateActivity(with content: NowPlayingLiveActivity.NowPlayingAttributes.ContentState) async {
        guard let activity else { return }

        await activity
            .update(
                .init(state: content, staleDate: nil),
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

        let display: DisplayingTrack = Self.DisplayingTrack(from: track)
        let state: NowPlayingLiveActivity.NowPlayingAttributes.ContentState = .init(
            trackInfo: display
        )

        await activity
            .update(.init(state: state, staleDate: nil),
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

    struct DisplayingTrack: Identifiable, Codable, Equatable {
        let id: String
        let title: String
        let artist: String
        let artworkURL: URL?

        init(title: String, artist: String, artworkURL: URL? = nil) {
            self.id = UUID().uuidString
            self.title = title
            self.artist = artist
            self.artworkURL = artworkURL
        }

        init(from track: Track) {
            self.id = track.id
            self.title = track.title
            self.artist = track.artist
            self.artworkURL = URL(string: track.artwork)
        }

        func getArtworkData() async -> Data? {
            guard let artworkURL else { return nil }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: artworkURL)
                return data
            } catch {
                print("Error loading image: \(error)")
            }
            return nil
        }
    }
}

