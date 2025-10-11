//
//  MusicPlayerView.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//

import SwiftUI
import UIKit
import WidgetKit
import SocketIO
import Combine

struct MusicPlayerView: View {
    @Environment(\.colorScheme) private var systemColorScheme

    let device: Device

    @StateObject private var userDevice: UserDevice = .shared

    @State private var hasPlayed = false
    @State private var librarySheet = false

    @State private var isLoading = true
    @State private var isCompact = false

    // Live Activity
    @State private var liveActivity: LiveActivityManager = LiveActivityManager.shared

    // Queue & Playing
    @State private var queueItems: [Track] = []
    @State private var sourceQueue: Queue?
    @State private var currentTrack: Track?
    @State private var trackUrl: URL? = nil

    // Playback Data
    @State private var isPlaying: Bool = false
    @State private var isVoluming: Bool = false
    @State private var stopTimeSlider: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var volume: Double = 0.5

    // AM data
    @State private var isLiked: Bool = false
    @State private var isInLibrary: Bool = false
    @State private var animatedArtwork: Bool = false
    @State private var backgroundColors: [Color] = []

    // Popups
    @State private var showLibraryPopup = false
    @State private var showFavoritePopup = false

    // Showing UIs
    @State private var showingLyrics = false
    @State private var showingQueue = false

    // Error
    @State private var errorMessage: String?

    // Lyrics
//    @State var lyrics: [LyricLine]? = nil
//    @State var lyricsProvider: Parser.LyricProvider? = nil

    // Socket.IO
    @State private var manager: SocketManager?
    @State private var socket: SocketIOClient?
    @State private var cancellables = Set<AnyCancellable>()

    // Cache
    @State private var imageCache = NSCache<NSString, UIImage>()
//    @State private var lyricCache: [String: [LyricLine]] = [:]
    @State private var storefrontCache: String? = nil

    init(device: Device) {
        self.device = device
        _liveActivity = State(wrappedValue: LiveActivityManager.shared)
        self.liveActivity.device = device
    }

    // MARK: - View

    var body: some View {
        VStack {
            artwork
                .padding(.top, self.animatedArtwork ? 0.0 : 80.0)
                .padding(.horizontal, self.animatedArtwork ? 0.0 : 10.0)

            Spacer()

            trackData
                .padding(.horizontal, 10.0)

            playbackActions
                .padding(.horizontal, 10.0)

            Spacer()
        }
        .ignoresSafeArea(.container)
        .frame(maxHeight: .infinity)
        .environment(\.colorScheme, ColorScheme.dark)
        .background {
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .ignoresSafeArea()

                if self.backgroundColors.count == 1 {
                    Rectangle()
                        .fill(self.backgroundColors[0])
                        .ignoresSafeArea()
                } else if self.backgroundColors.count == 25 {
                    AnimatedMeshGradientView(colors: $backgroundColors, amplify: 0.25)
                        .ignoresSafeArea()
                        .opacity(0.3)
                }
            }
        }
        .task {
            self.startListening()

            await self.initializePlayer()
            await MainActor.run {
                withAnimation {
                    isLoading = false
                }
            }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let track = self.currentTrack {
            AsyncImage(url: URL(string: track.artwork)) { phase in
                switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(1.0, contentMode: .fit)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "music.note")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(.gray)
                    @unknown default:
                        EmptyView()
                }
            }
            .scaledToFit()
            .frame(maxWidth: .infinity, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 10)
        }
    }

    @ViewBuilder
    private var trackData: some View {
        if let currentTrack {
            GlassEffectContainer {
                HStack {
                    VStack(alignment: .leading) {
                        Text(currentTrack.title)
                            .font(.title2.bold())
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(currentTrack.artist)
                            .font(.title2)
                            .foregroundStyle(Color.secondary)
                            .opacity(0.5)
                            .lineLimit(1)
                    }
                    .padding(10.0)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 15.0))

                    Button {
                        Task {
                            await self.toggleLike()
                        }
                    } label: {
                        Image(systemName: self.isLiked ? "star.fill" : "star")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(Color.primary)
                    }
                    .padding(10)
                    .glassEffect(.regular.interactive(), in: Circle())

                    MoreActionsMenu(
                        currentTrack: currentTrack,
                        toggleAddToLibrary: toggleAddToLibrary,
                        toggleLike: toggleLike,
                        isInLibrary: $isInLibrary,
                        isLiked: $isLiked
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var playbackActions: some View {
        VStack(spacing: 25.0) {
            CustomSlider(value: $currentTime, isDragging: $stopTimeSlider, bounds: 0...duration) { newValue in
                if !newValue {
                    Task {
                        await self.seekToTime(to: self.currentTime)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                HStack {
                    Text(self.formatTime(self.currentTime))
                        .font(.caption.bold(self.stopTimeSlider))
                        .foregroundStyle(self.stopTimeSlider ? Color.white : Color.secondary)
                        .opacity(self.stopTimeSlider ? 1.0 : 0.5)
                        .contentTransition(.identity)

                    Spacer()

                    Text(self.formatTime(self.duration - self.currentTime))
                        .font(.caption.bold(self.stopTimeSlider))
                        .foregroundStyle(self.stopTimeSlider ? Color.white : Color.secondary)
                        .opacity(self.stopTimeSlider ? 1.0 : 0.5)
                        .contentTransition(.identity)
                }
                .offset(y: 3.0 + (self.stopTimeSlider ? 12.0 : 0.0))
            }

            HStack(spacing: 70.0) {
                Button {
                    Task {
                        await self.previousTrack()
                    }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title.bold())
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await self.togglePlayPause()
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(Color.white)
                        .contentTransition(.symbolEffect(.replace.wholeSymbol))
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await self.nextTrack()
                    }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title.bold())
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                    .opacity(0.5)

                CustomSlider(value: $volume, isDragging: $isVoluming, bounds: 0...1) { newValue in
                    if !newValue {
                        Task {
                            await self.adjustVolume(to: self.volume)
                        }
                    }
                }

                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
                    .opacity(0.5)
            }
        }
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Model

    func startListening() {
        print("Attempting to connect to socket")
        let socketURL = device.connectionMethod == "tunnel"
        ? "https://\(device.host)"
        : "http://\(device.host):10767"
        manager = SocketManager(socketURL: URL(string: socketURL)!, config: [.log(false), .compress])
        socket = manager?.defaultSocket

        setupSocketEventHandlers()
        socket?.connect()
    }

    private func setupSocketEventHandlers() {
        socket?.on(clientEvent: .connect) { data, ack in
            print("Socket connected")

            Task {
                await self.getCurrentTrack()

                if let currentTrack = self.currentTrack {
                    self.liveActivity.startActivity(using: currentTrack)
                }

//                AppDelegate.shared.scheduleAppRefresh()
                if #available(iOS 18.0, *) {
                    ControlCenter.shared.reloadControls(ofKind: "sh.cider.CiderRemote.PlayPauseControl")
                }
            }
        }

        socket?.on("API:Playback") { data, ack in
            guard let playbackData = data[0] as? [String: Any],
                  let type = playbackData["type"] as? String else {
                print("Invalid playback data received")
                return
            }

            //            print("Received playback event: \(type)")

            DispatchQueue.main.async {
                switch type {
                    case "playbackStatus.nowPlayingStatusDidChange":
                        if let info = playbackData["data"] as? [String: Any] {
                            self.setAdaptiveData(info)
                        }
                    case "playbackStatus.nowPlayingItemDidChange":
                        if let info = playbackData["data"] as? [String: Any] {
                            self.updateTrackInfo(info)
                            if let currentTrack = self.currentTrack {
                                self.liveActivity.startActivity(using: currentTrack)
                            }
                        }
                    case "playbackStatus.playbackStateDidChange":
                        if let info = playbackData["data"] as? [String: Any] {
                            self.setPlaybackStatus(info)
                        }
                    case "playbackStatus.playbackTimeDidChange":
                        if let info = playbackData["data"] as? [String: Any],
                           let isPlaying = info["isPlaying"] as? Int,
                           let currentPlaybackTime = info["currentPlaybackTime"] as? Double {
                            self.isPlaying = isPlaying == 1 ? true : false
                            if !self.stopTimeSlider {
                                self.currentTime = currentPlaybackTime
                            }
                        }
                    default:
                        print("Unhandled event type: \(type)")
                }
            }
        }
    }

    func stopListening() {
        print("Disconnecting socket")
        socket?.disconnect()
    }

    func initializePlayer() async {
        await getCurrentTrack()
        await getCurrentVolume()
        await fetchQueueItems()
    }

    func refreshCurrentTrack() {
        Task {
            await getCurrentTrack()
            await getCurrentVolume()

            if let currentTrack, queueItems.first?.id == currentTrack.id {
                queueItems.removeFirst()
            } else {
                await fetchQueueItems()
            }

            reconnectSocketIfNeeded()
        }
    }

    private func reconnectSocketIfNeeded() {
        if socket?.status != .connected {
            print("Socket not connected, reconnecting...")
            socket?.connect()
        }
    }

    func fetchQueueItems() async {
        guard let currentTrack else { print("[QUEUE] Need currentTrack to get current queue"); return }

        print("Fetching current queue")
        do {
            let data = try await sendRequest(endpoint: "playback/queue")
            if let jsonDict = data as? [[String: Any]] {
                let attributes: [[String : Any]] = jsonDict.compactMap { $0["attributes"] as? [String : Any] }
                let queue: [Track] = attributes.map { getTrack(using: $0) }

                var queueItem: Queue = .init(tracks: queue)
                queueItem.defineCurrent(track: currentTrack)

                self.sourceQueue = queueItem // after defining offset
                self.queueItems = queueItem.tracks
            }

            await self.handleColors()
        } catch {
            handleError(error)
        }
    }

    func getCurrentTrack() async {
        print("Fetching current track")
        do {
            let data = try await sendRequest(endpoint: "playback/now-playing", method: "GET")
            if let jsonDict = data as? [String: Any],
               let info = jsonDict["info"] as? [String: Any] {
                updateTrackInfo(info, alt: true)
            } else {
                throw NetworkError.decodingError
            }
        } catch {
            handleError(error)
        }
    }

//    func fetchAllLyrics() async {
//        let success: Bool = await self.fetchLyricsAm() // apple music
//        if !success {
//            _ = await self.fetchLyricsMxm() // musixmatch
//        }
//    }

    /// Returns true if the lyrics were found and fetched
//    func fetchLyricsMxm() async -> Bool {
//        guard let currentTrack else { return false }
//
//        print("Current track ID: \(currentTrack.id)")
//
//        if let cachedLyrics = lyricCache[currentTrack.id] {
//            print("Using cached lyrics for track: \(currentTrack.id)")
//            self.lyricsProvider = .cache
//            self.lyrics = cachedLyrics
//            return true
//        }
//
//        self.lyrics = nil
//        guard let lyricsUrl = URL(string: "https://rise.cider.sh/api/v1/lyrics/mxm") else { return false }
//
//        do {
//            print("Fetching lyrics ONLINE for track: \(currentTrack.id)")
//
//            let lyricReq: Track.RequestLyrics = .init(track: currentTrack)
//            let encoder: JSONEncoder = .init()
//            let body: Data = try encoder.encode(lyricReq)
//
//            var req = URLRequest(url: lyricsUrl, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: .infinity)
//            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
//
//            req.httpMethod = "POST"
//            req.httpBody = body
//
//            let (data, response) = try await URLSession.shared.data(for: req)
//
//            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
//                let decoder: JSONDecoder = .init()
//                print(String(data: data, encoding: .utf8) ?? "wtf?")
//                let mxm = try decoder.decode(Track.MxmLyrics.self, from: data)
//
//                let lines = mxm.decodeHtml()
//                print("Parsed \(lines.count) lyric lines")
//                if lines.count > 0 {
//                    DispatchQueue.main.async {
//                        self.lyricsProvider = .mxm
//                        self.lyrics = lines
//                        self.lyricCache[currentTrack.id] = self.lyrics
//                    }
//                    return true
//                }
//            } else {
//                self.lyrics = []
//                throw NetworkError.serverError("Couldn't reach server")
//            }
//        } catch {
//            self.lyrics = []
//            print(error)
//            handleError(error)
//        }
//        return false
//    }

    /// Returns true if the lyrics were found and fetched
//    func fetchLyricsAm() async -> Bool {
//        guard let currentTrack else { return false }
//
//        print("Current track ID: \(currentTrack.id)")
//
//        if let cachedLyrics = lyricCache[currentTrack.id] {
//            print("Using cached lyrics for track: \(currentTrack.id)")
//            self.lyricsProvider = .cache
//            self.lyrics = cachedLyrics
//            return true
//        }
//
//        do {
//            guard let storefront = await self.getStorefront() else { return false }
//
//            print("Fetching lyrics FROM CLIENT for track: \(currentTrack.id)")
//            let path: String = "/v1/catalog/\(storefront)/songs/\(currentTrack.catalogId)/lyrics?l=en-US&platform=web&art[url]=f"
//            let data = try await sendRequest(endpoint: "amapi/run-v3", method: "POST", body: ["path": path])
//
//            print(data)
//            if let jsonDict = data as? [String: Any], let data = jsonDict["data"] as? [String: Any], let subdata = data["data"] as? [[String: Any]], let lyricsData = subdata[0]["attributes"] as? [String: Any] {
//                guard let lyricsXml = lyricsData["ttml"] as? String, let data = lyricsXml.data(using: .utf8) else {
//                    print("-- After fetch decoding error --")
//                    throw NetworkError.decodingError
//                }
//
//                let xmlParser = XMLParser(data: data)
//                let ttmlParser = Parser(provider: .am)
//                xmlParser.delegate = ttmlParser
//                xmlParser.parse()
//
//                self.lyricsProvider = .am
//                self.lyrics = ttmlParser.lyrics
//                self.lyricCache[currentTrack.id] = self.lyrics
//                return true
//            } else {
//                throw NetworkError.invalidResponse
//            }
//        } catch {
//            print("Error fetching lyrics: \(error)")
//            handleError(error)
//        }
//        return false
//    }

    func getStorefront() async -> String? {
        do {
            let data = try await sendRequest(endpoint: "amapi/run-v3", method: "POST", body: ["path": "/v1/me/storefront?limit=1"])
            print(data)
            if let jsonDict = data as? [String: Any], let data = jsonDict["data"] as? [String: Any], let subdata = data["data"] as? [[String: Any]], let storefrontId = subdata[0]["id"] as? String {
                self.storefrontCache = storefrontId
                return storefrontId
            }
        } catch {
            print("Error fetching storefront: \(error)")
            handleError(error)
        }

        return nil
    }

    func getTrackUrl() async -> URL? {
        guard let currentTrack else { return nil }
        var storefront: String? = self.storefrontCache
        if self.storefrontCache == nil, let newStorefront = await self.getStorefront() {
            storefront = newStorefront
        }

        if let storefront {
            return URL(string: "https://music.apple.com/\(storefront)/song/\(currentTrack.catalogId)")
        } else {
            return nil
        }
    }

    private func setPlaybackStatus(_ info: [String: Any]) {
        print("Setting playback status: \(info)")
        if let state = info["state"] as? String {
            self.isPlaying = (state == "playing")
        }
    }

    private func setAdaptiveData(_ info: [String: Any]) {
        print("Setting adaptive data: \(info)")
        DispatchQueue.main.async {
            if let isLiked = info["inFavorites"] as? Int, isLiked == 1 {
                self.isLiked = true
            } else {
                self.isLiked = false
            }

            if let isInLibrary = info["inLibrary"] as? Int, isInLibrary == 1 {
                self.isInLibrary = true
            } else {
                self.isInLibrary = false
            }

            if let currentPlaybackTime = info["currentPlaybackTime"] as? Double {
                self.currentTime = currentPlaybackTime
            }
            if let durationInMillis = info["durationInMillis"] as? Double {
                self.duration = durationInMillis / 1000
            }
        }
    }

    private func updateTrackInfo(_ info: [String: Any], alt: Bool = false) {
        print("Updating track info: \(info)")

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

            //            Task {
            //                let image = await self.loadImage(for: URL(string: artworkUrl)!)
            //                if let imgData = image?.pngData() {
            //                    data = imgData
            //                }
            //            }

            let newTrack = Track(id: id ?? "",
                                 catalogId: amId ?? "",
                                 title: title,
                                 artist: artist,
                                 album: album,
                                 artwork: artworkUrl,
                                 duration: duration / 1000,
                                 artworkData: data ?? Data()
            )

            if self.currentTrack != newTrack {
                self.currentTrack = newTrack
//                self.lyrics = [] // Clear lyrics when track changes
                Task {
                    await self.updateQueue(newTrack: newTrack)
//                    await self.fetchAllLyrics()
                }
            }
        }

        if alt {
            self.isLiked = info["inFavorites"] as? Bool ?? false
            self.isInLibrary = info["inLibrary"] as? Bool ?? false
        }
        self.duration = duration / 1000

        if let currentPlaybackTime = info["currentPlaybackTime"] as? Double, !self.stopTimeSlider {
            self.currentTime = currentPlaybackTime
        }

        self.isPlaying = false

        print("Updated currentTrack: \(String(describing: self.currentTrack))")
        print("isPlaying: \(self.isPlaying)")
    }


    private func handleColors() async {
        var colors: [Color] = [Color.accentColor.opacity(0.2)]

        if let artwork: UIImage = await self.loadArtwork() {
            colors = artwork.dominantColors(count: 25)
        }

        withAnimation(.linear(duration: 3.5)) {
            self.backgroundColors = colors.shuffled()
        }
    }

    private func updateQueue(newTrack: Track) async {
        print("[QUEUE] smart update")
        if newTrack.id == queueItems.first?.id { // if newTrack is the next playing song in the queue
            queueItems = Array(queueItems.dropFirst())
        } else {
            await fetchQueueItems()
        }
    }

    func playFromQueue(_ track: Track) async {
        guard let sourceQueue, let index = sourceQueue.tracks.firstIndex(where: { $0.id == track.id }) else { return }
        print("[QUEUE] play from queue")

        do {
            _ = try await sendRequest(
                endpoint: "playback/queue/change-to-index",
                method: "POST",
                body: ["index" : index + sourceQueue.offset]
            )
            await updateQueue(newTrack: track)
        } catch {
            handleError(error)
        }
    }

    func moveQueue(from startIndex: Int, to destinationIndex: Int) async {
        guard let sourceQueue, startIndex != destinationIndex else { return }
        do {
            _ = try await sendRequest(endpoint: "playback/queue/move-to-position",
                                      method: "POST",
                                      body: ["startIndex" : startIndex + sourceQueue.offset, "destinationIndex": destinationIndex + sourceQueue.offset]
            )
            try? await Task.sleep(nanoseconds: 500_000_000) // we don't wait, then the *fetchQueueItems* will error
            await fetchQueueItems()
        } catch {
            handleError(error)
        }
    }

    func removeQueue(index: Int) async {
        guard let sourceQueue else { return }
        do {
            _ = try await sendRequest(endpoint: "playback/queue/remove-by-index",
                                      method: "POST",
                                      body: ["index": index + sourceQueue.offset]
            )
        } catch {
            handleError(error)
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

    func getCurrentVolume() async {
        print("Fetching current volume")
        do {
            let data = try await sendRequest(endpoint: "playback/volume", method: "GET")
            if let jsonDict = data as? [String: Any],
               let volume = jsonDict["volume"] as? Double {
                self.volume = volume
                print("Current volume: \(volume)")
            } else {
                throw NetworkError.decodingError
            }
        } catch {
            handleError(error)
        }
    }

    func togglePlayPause() async {
        print("Toggling play/pause")
        withAnimation {
            isPlaying.toggle() // Immediately update UI
        }
        do {
            _ = try await sendRequest(endpoint: "playback/playpause", method: "POST")
            // Server confirmed the change, no need to update UI again
            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadControls(ofKind: "sh.cider.CiderRemote.PlayPauseControl")
            }
        } catch {
            // Revert the UI change if the server request failed
            isPlaying.toggle()
            handleError(error)
        }
    }

    func nextTrack() async {
        print("Skipping to next track")
        do {
            _ = try await sendRequest(endpoint: "playback/next", method: "POST")
            await getCurrentTrack() // Refresh track info after skipping
        } catch {
            handleError(error)
        }
    }

    func previousTrack() async {
        print("Going to previous track")
        do {
            _ = try await sendRequest(endpoint: "playback/previous", method: "POST")
            await getCurrentTrack() // Refresh track info after going to previous track
        } catch {
            handleError(error)
        }
    }

    func seekToTime() async {
        print("Seeking to time: \(currentTime)")
        do {
            _ = try await sendRequest(endpoint: "playback/seek", method: "POST", body: ["position": currentTime])
        } catch {
            handleError(error)
        }
    }

    func toggleLike() async {
        let newRating = isLiked ? 0 : 1
        print("Toggling like status to: \(newRating)")
        do {
            _ = try await sendRequest(endpoint: "playback/set-rating", method: "POST", body: ["rating": newRating])
            isLiked.toggle()

            withAnimation {
                showFavoritePopup = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showFavoritePopup = false
                }
            }
        } catch {
            handleError(error)
        }
    }

    func toggleAddToLibrary() async {
        if !isInLibrary {
            print("Adding to library")
            do {
                _ = try await sendRequest(endpoint: "playback/add-to-library", method: "POST")
                isInLibrary = true

                withAnimation {
                    showLibraryPopup = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showLibraryPopup = false
                    }
                }
            } catch {
                handleError(error)
            }
        }
    }

    private func adjustVolume(to volume: Double) async {
        print("Adjusting volume to: \(volume)")
        do {
            let data = try await sendRequest(endpoint: "playback/volume", method: "POST", body: ["volume": volume])
            if let jsonDict = data as? [String: Any],
               let newVolume = jsonDict["volume"] as? Double {
                self.volume = newVolume
                print("Volume adjusted to: \(newVolume)")
            } else {
                throw NetworkError.decodingError
            }
        } catch {
            handleError(error)
        }
    }

    func searchSong(query: String) async -> [Track] {
        print("Searching for: \(query)")
        do {
            let data = try await sendRequest(endpoint: "amapi/run-v3", method: "POST", body: ["path": "/v1/catalog/us/search?term=\(query)&types=songs"])

            if let jsonDict = data as? [String: Any], let data = jsonDict["data"] as? [String: Any], let _results = data["results"] as? [String: Any] {
                guard let songs = _results["songs"] as? [String: Any], let results = songs["data"] as? [[String: Any]] else {
                    print("Couldn't decrypt stuff")
                    return []
                }

                var searchResults: [Track] = []
                for result in results {
                    guard let attributes = result["attributes"] as? [String: Any], let artwork = attributes["artwork"] as? [String: Any] else {
                        print("Oopsy, couldn't add search result")
                        return []
                    }

                    searchResults
                        .append(
                            .init(
                                id: attributes["isrc"] as! String,
                                catalogId: attributes["isrc"] as! String,
                                title: attributes["name"] as! String,
                                artist: attributes["artistName"] as! String,
                                album: attributes["albumName"] as! String,
                                artwork: String((artwork["url"] as! String).replacing(/{(w|h)}/, with: "500")),
                                duration: (Double(attributes["durationInMillis"] as? String ?? "0") ?? 0.0) / 1000,
                                artworkData: Data(),
                                songHref: (result["href"] as! String)
                            )
                        )
                }

                print("[searchSong] RETURNING \(searchResults.count) results")
                return searchResults
            } else {
                throw NetworkError.decodingError
            }
        } catch {
            handleError(error)
        }

        return []
    }

    func playHref(href: String) async {
        print("Playing song using HREF")

        do {
            _ = try await sendRequest(endpoint: "playback/play-item-href", method: "POST", body: ["href": href])
        } catch {
            handleError(error)
        }
    }

    func playTrackHref(_ track: Track) async {
        guard let href = track.songHref else { fatalError("No HREF in this Track") }
        print("Playing TRACK song using HREF")

        do {
            _ = try await sendRequest(endpoint: "playback/play-item-href", method: "POST", body: ["href": href])
        } catch {
            handleError(error)
        }
    }

    private func seekToTime(to newTime: Double) async {
        print("Seeking to time: \(newTime)")
        do {
            _ = try await sendRequest(endpoint: "playback/seek", method: "POST", body: ["position": newTime])
        } catch {
            handleError(error)
        }
    }

    func loadImage(for url: URL) async -> UIImage? {
        // Check cache first
        if let cachedImage = imageCache.object(forKey: url.absoluteString as NSString) {
            return cachedImage
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                // Cache the image
                imageCache.setObject(image, forKey: url.absoluteString as NSString)
                return image
            }
        } catch {
            print("Error loading image: \(error)")
        }
        return nil
    }

    func loadArtwork() async -> UIImage? {
        guard let artwork = self.currentTrack?.artwork else { return nil }
        let url: URL = URL(string: artwork)!
        return await self.loadImage(for: url)
    }

    private func sendRequest(endpoint: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Any {
        let baseURL = device.connectionMethod == "tunnel"
        ? "https://\(device.host)"
        : "http://\(device.host):10767"
        guard let url = URL(string: "\(baseURL)/api/v1/\(endpoint)") else {
            throw NetworkError.invalidURL
        }

        print("Sending request to: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue(device.token, forHTTPHeaderField: "apptoken")

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            print("Request body: \(body)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        //        print("Response raw: \(String(data: data, encoding: .utf8) ?? "[No data]")")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        print("Response status code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("Server responded with status code \(httpResponse.statusCode)")
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            //            print("Received data: \(json)")
            return json
        } catch {
            print(error)
            throw NetworkError.decodingError
        }
    }

    private func handleError(_ error: Error) {
        if let networkError = error as? NetworkError {
            switch networkError {
                case .invalidURL:
                    errorMessage = "Invalid URL"
                case .invalidResponse:
                    errorMessage = "Invalid response from server"
                case .decodingError:
                    errorMessage = "Error decoding data"
                case .serverError(let message):
                    errorMessage = "Server error: \(message)"
            }
        } else {
            errorMessage = error.localizedDescription
        }
        print("Error: \(errorMessage ?? "Unknown error")")
    }
}

// MARK: - Extensions

fileprivate struct MoreActionsMenu: View {
    var currentTrack: Track

    var toggleAddToLibrary: () async -> Void
    var toggleLike: () async -> Void

    @Binding var isInLibrary: Bool
    @Binding var isLiked: Bool

    @State private var shareSheet: Bool = false

    var body: some View {
        Menu {
            Button {
                Task {
                    await self.toggleAddToLibrary()
                }
            } label: {
                Label(self.isInLibrary ? "Remove from library" : "Add to library", systemImage: self.isInLibrary ? "minus.circle.fill" :  "plus.circle.fill")
            }

            Divider()

            ControlGroup {
                Button {
                    Task {
                        await self.toggleLike()
                    }
                } label: {
                    Label(self.isLiked ? "Unfavorite" : "Favorite", systemImage: self.isLiked ? "star.fill" : "star")
                }

                Button {
                    self.shareSheet.toggle()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(Color.primary)
        }
        .tint(Color.primary)
        .padding(10.0)
        .glassEffect(.regular.interactive(), in: Circle())
        .sheet(isPresented: $shareSheet) {
            ActivityViewController(item: .track(track: currentTrack))
                .presentationDetents([.medium, .large])
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    var brightness: Double {
        let components = UIColor(self).cgColor.components
        return (components?[0] ?? 0.0) * 0.299 + (components?[1] ?? 0.0) * 0.587 + (components?[2] ?? 0.0) * 0.114
    }
}

extension UIImage {
    func dominantColors(count: Int = 3) -> [Color] {
        guard let inputImage = self.cgImage else { return [] }
        let width = inputImage.width
        let height = inputImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        rawData.withUnsafeMutableBytes { ptr in
            if let context = CGContext(data: ptr.baseAddress,
                                       width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: 4 * width,
                                       space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                context.draw(inputImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }
        
        var colors: [Color] = []
        let pixelCount = width * height
        let sampleCount = max(pixelCount / 1000, 1)  // Sample every 1000th pixel or at least 1
        
        for i in stride(from: 0, to: pixelCount * 4, by: sampleCount * 4) {
            let red = Double(rawData[i]) / 255.0
            let green = Double(rawData[i + 1]) / 255.0
            let blue = Double(rawData[i + 2]) / 255.0
            colors.append(Color(red: red, green: green, blue: blue))
        }
        
        // Remove duplicates and limit to the requested count
        return Array(Set(colors)).prefix(count).map { $0 }
    }
}

extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        let view = controller.view

        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    func dominantColors(count: Int = 3) -> [Color] {
        return self.asUIImage()?.dominantColors(count: count) ?? []
    }
}

