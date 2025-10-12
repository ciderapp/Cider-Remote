// Made by Lumaa

import SwiftUI

struct QueueView<Content : View>: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    let device: Device

    @Binding var queueItems: [Track]
    @Binding var sourceQueue: Queue?
    @Binding var currentTrack: Track?

    @State private var tappedTrack: Track? = nil
    @State private var fetchingResults: Bool = false

    @State private var librarySheet: Bool = false

    @FocusState private var isSearching: Bool

    var header: () -> Content

    var body: some View {
        ZStack {
            List {
                self.header()
                    .ciderRowOptimized()

                queueView
                    .ciderRowOptimized()
            }
            .contentMargins(.bottom, 20, for: .scrollContent)
            .contentMargins(.top, 10, for: .scrollContent)
            .ciderOptimized()
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var queueView: some View {
        if queueItems.count < 1 || (queueItems.count == 1 && queueItems.first == currentTrack) {
            ContentUnavailableView("Queue empty", systemImage: "list.number", description: Text("Your Cider queue is empty"))
        } else {
            ForEach(queueItems, id: \.id) { track in
                Button {
                    Task {
                        await playFromQueue(track)
                    }
                } label: {
                    trackRow(track, showDuration: true)
                        .ciderRowOptimized()
                }
            }
            .onDelete { set in
                guard var sourceQueue = sourceQueue else { return }

                self.queueItems.remove(atOffsets: set)
                sourceQueue.remove(set: set)

                self.sourceQueue = sourceQueue

                Task {
                    for i in set {
                        await self.removeQueue(index: i)
                    }
                }
            }
            .onMove { from, to in
                guard var sourceQueue = sourceQueue, let firstIndex = from.first else { return }

                self.queueItems.move(fromOffsets: from, toOffset: to)
                sourceQueue.move(from: from, to: to)

                self.sourceQueue = sourceQueue

                Task {
                    await self.moveQueue(from: firstIndex, to: to)
                }
            }
        }
    }

    @ViewBuilder
    private func trackRow(_ track: Track, showDuration: Bool = false) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: track.artwork)) { phase in
                switch phase {
                    case .empty:
                        Color.gray.opacity(0.3)
                    case .success(let image):
                        image.resizable()
                    case .failure:
                        Image(systemName: "music.note")
                            .foregroundStyle(.gray)
                    @unknown default:
                        EmptyView()
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(track.artist)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            if showDuration {
                Spacer()

#if DEBUG
                if let trackIndex = sourceQueue?.firstIndex(of: track), trackIndex >= 0 {
                    Text("\(trackIndex)")
                        .font(.caption.bold())
                }
#endif

                Text(formatDuration(track.duration))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
    }

    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Device functions

    func moveQueue(from startIndex: Int, to destinationIndex: Int) async {
        guard let sourceQueue, startIndex != destinationIndex else { return }
        do {
            _ = try await device.sendRequest(endpoint: "playback/queue/move-to-position", method: "POST", body: ["startIndex" : startIndex + sourceQueue.offset, "destinationIndex": destinationIndex + sourceQueue.offset])
            try? await Task.sleep(nanoseconds: 500_000_000) // we don't wait, then the *fetchQueueItems* will error
            await self.fetchQueueItems()
        } catch {
            print(error)
        }
    }

    func removeQueue(index: Int) async {
        guard let sourceQueue else { return }
        do {
            _ = try await device.sendRequest(endpoint: "playback/queue/remove-by-index", method: "POST", body: ["index": index + sourceQueue.offset])
        } catch {
            print(error)
        }
    }

    func playFromQueue(_ track: Track) async {
        guard let sourceQueue, let index = sourceQueue.tracks.firstIndex(where: { $0.id == track.id }) else { return }
        print("[QUEUE] play from queue")

        do {
            _ = try await device.sendRequest(endpoint: "playback/queue/change-to-index", method: "POST", body: ["index" : index + sourceQueue.offset])
            await self.updateQueue(newTrack: track)
        } catch {
            print(error)
        }
    }

    private func updateQueue(newTrack: Track) async {
        print("[QUEUE] smart update")
        if newTrack.id == queueItems.first?.id { // newTrack is the next playing song in the queue
            queueItems = Array(queueItems.dropFirst())
        } else {
            await self.fetchQueueItems()
        }
    }

    func fetchQueueItems() async {
        guard let currentTrack else { print("[QUEUE] Need currentTrack to get current queue"); return }

        print("Fetching current queue")
        do {
            let data = try await device.sendRequest(endpoint: "playback/queue")
            if let jsonDict = data as? [[String: Any]] {
                let attributes: [[String : Any]] = jsonDict.compactMap { $0["attributes"] as? [String : Any] }
                let queue: [Track] = attributes.map { getTrack(using: $0) }

                var queueItem: Queue = .init(tracks: queue)
                queueItem.defineCurrent(track: currentTrack)

                self.sourceQueue = queueItem // after defining offset
                self.queueItems = queueItem.tracks
            }
        } catch {
            print(error)
        }
    }

    private func getTrack(using info: [String: Any]) -> Track {
        // Extract ID from playParams
        var id: String?
        var amId: String?

        if let playParams = info["playParams"] as? [String: Any] {
            id = playParams["id"] as? String
            amId = playParams["catalogId"] as? String
        }

        let title = info["name"] as? String ?? ""
        let artist = info["artistName"] as? String ?? ""
        let album = info["albumName"] as? String ?? ""
        let duration = info["durationInMillis"] as? Double ?? 0

        if let artwork = info["artwork"] as? [String: Any],
           var artworkUrl = artwork["url"] as? String {
            // Replace placeholders in artwork URL
            artworkUrl = artworkUrl.replacingOccurrences(of: "{w}", with: "1024")
            artworkUrl = artworkUrl.replacingOccurrences(of: "{h}", with: "1024")

            let data: Data? = nil

            return Track(id: id ?? "",
                         catalogId: amId ?? "",
                         title: title,
                         artist: artist,
                         album: album,
                         artwork: artworkUrl,
                         duration: duration / 1000,
                         artworkData: data ?? Data()
            )
        } else {
            return Track(id: id ?? "",
                         catalogId: amId ?? "",
                         title: title,
                         artist: artist,
                         album: album,
                         artwork: "",
                         duration: duration / 1000,
                         artworkData: Data()
            )
        }
    }
}
