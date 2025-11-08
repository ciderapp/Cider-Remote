//
//  MusicPlayerView.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//

import SwiftUI
import Combine
import SocketIO
import WidgetKit
import AVKit

struct MusicPlayerView: View {
    @Environment(\.colorScheme) private var systemColorScheme: ColorScheme
    @Environment(\.scenePhase) private var scenePhase: ScenePhase

    let device: Device

    @StateObject private var userDevice: UserDevice = .shared

    @State private var isLoading = true
    @State private var player: AVPlayer? = nil

    // Live Activity
    @State private var liveActivity: LiveActivityManager = LiveActivityManager.shared

    // Queue & Playing
    @State private var hasPlayed = false
    @State private var queueItems: [Track] = []
    @State private var sourceQueue: Queue?
    @State private var currentTrack: Track?
    @State private var trackUrl: URL? = nil

    // Playback Data
    @State private var isPlaying: Bool = false
    @State private var repeatMode: RepeatMode = .none
    @State private var shuffleMode: ShuffleMode = .none
    @State private var isAutoPlaying: Bool = false
    @State private var isVoluming: Bool = false
    @State private var stopTimeSlider: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var volume: Double = 0.5

    // AM data
    @State private var isLiked: Bool = false
    @State private var isInLibrary: Bool = false
    @State private var videoArtwork: URL? = nil
    @State private var audioFormat: Track.AudioType = .unknown
    @State private var backgroundColors: [Color] = []

    // Popups
    @State private var showLibraryPopup: Bool = false
    @State private var showFavoritePopup: Bool = false

    // Showing UIs
    @State private var showingLyrics: Bool = false
    @State private var showingQueue: Bool = false
    @State private var showingLibrary: Bool = false

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

    private var expandedView: Bool {
        return !self.showingQueue && !self.showingLyrics
    }

    private static let horizontalPadding: CGFloat = 20.0

    init(device: Device) {
        self.device = device
        _liveActivity = State(wrappedValue: LiveActivityManager.shared)
        self.liveActivity.device = device
    }

    // MARK: - View

    var body: some View {
        ZStack {
            if userDevice.horizontalOrientation.isPortrait() {
                self.portrait
            } else if userDevice.horizontalOrientation.isLandscape() {
                self.landscape(userDevice.horizontalOrientation)
            }
        }
        .fullScreenCover(isPresented: $showingLibrary) {
            BrowserView(device: device)
                .environment(\.colorScheme, systemColorScheme) // restore user's color scheme
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
        .onChange(of: showingQueue) { _, newValue in
            if let player {
                if newValue {
                    player.pause()
                } else {
                    player.play()
                }
            }

            if newValue {
                withAnimation(.easeOut.speed(1.3)) {
                    self.showingLyrics = false
                }
            }
        }
        .onChange(of: showingLyrics) { _, newValue in
            if let player {
                if newValue {
                    player.pause()
                } else {
                    player.play()
                }
            }

            if newValue {
                withAnimation(.easeOut.speed(1.3)) {
                    self.showingQueue = false
                }
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active, let player {
                player.play()
            }
        }
        .environment(\.colorScheme, ColorScheme.dark)
    }

    @ViewBuilder
    private var portrait: some View {
        VStack {
            if expandedView {
                artwork
                    .padding(.top, self.videoArtwork != nil ? 0.0 : 80.0)
                    .padding(.horizontal, self.videoArtwork != nil ? 0.0 : Self.horizontalPadding)
            } else {
                HStack {
                    artwork
                }
                .padding(.top, 80.0)
                .padding(.horizontal, Self.horizontalPadding + 15.0)
            }

            if self.showingQueue {
                QueueView(device: device, queueItems: $queueItems, sourceQueue: $sourceQueue, currentTrack: $currentTrack) {
                    queueActions
                        .padding(.horizontal, Self.horizontalPadding)
                }
                .minimalView()
            } else if self.showingLyrics {
                LyricsView(device: device, currentTrack: $currentTrack, currentTime: $currentTime)
                    .frame(height: 600)
            }

            Spacer()
        }
        .ignoresSafeArea(.container)
        .frame(maxHeight: .infinity)
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
        .overlay(alignment: .bottom) {
            VStack {
                if expandedView {
                    trackData
                        .padding(.horizontal, Self.horizontalPadding)
                }

                if !self.showingLyrics {
                    playbackActions
                        .padding(.horizontal, Self.horizontalPadding)
                        .transition(
                            .move(edge: .bottom)
                            .combined(with: .opacity)
                            .animation(.spring(duration: 0.4))
                        )
                }

                navigationActions
                    .padding(.horizontal, 30.0)
                    .padding(.vertical, 10.0)
            }
            .padding(.bottom, 30.0)
        }
    }

    @ViewBuilder
    private func landscape(_ orientation: UserDevice.HorizontalOrientation) -> some View {
        SidedStack(side: orientation == .landscapeLeft ? SidedStack.Side.left : SidedStack.Side.right) {
            if expandedView {
                artwork
                    .padding(.top, self.videoArtwork != nil ? 0.0 : Self.horizontalPadding)
                    .padding(.horizontal, self.videoArtwork != nil ? 0.0 : 80.0)
            }

            if self.showingQueue {
                QueueView(device: device, queueItems: $queueItems, sourceQueue: $sourceQueue, currentTrack: $currentTrack) {
                    queueActions
                        .padding(.horizontal, Self.horizontalPadding)
                }
                .minimalView()
            }
        } `right`: {
            VStack {
                if !self.showingLyrics {
                    trackData
                        .padding(.horizontal, Self.horizontalPadding)

                    playbackActions
                        .padding(.horizontal, Self.horizontalPadding)
                        .transition(
                            .move(edge: .bottom)
                            .combined(with: .opacity)
                            .animation(.spring(duration: 0.4))
                        )
                } else {
                    Spacer()
                }

                navigationActions
                    .padding(.horizontal, 30.0)
                    .padding(.vertical, 10.0)
            }
            .frame(height: 350)
        }
        .ignoresSafeArea(.container)
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
        .overlay(alignment: .center) {
            if self.showingLyrics {
                LyricsView(device: device, currentTrack: $currentTrack, currentTime: $currentTime)
                    .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
#if !WIDGET
            self.alwaysOn(UserDefaults.standard.bool(forKey: "alwaysOn"))
#endif
        }
        .onDisappear {
#if !WIDGET
            self.alwaysOn(false)
#endif
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let track = self.currentTrack {
            if videoArtwork != nil && expandedView, let player {
                UninteractableVideoPlayer(player: player)
                    .aspectRatio(userDevice.horizontalOrientation.isPortrait() ? LibraryAlbum.AnimatedCover.tall.ratio : LibraryAlbum.AnimatedCover.square.ratio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .mask(alignment: .center) {
                        if userDevice.horizontalOrientation.isPortrait() {
                            LinearGradient(
                                colors: [Color.white, Color.white, Color.white, Color.white.opacity(0.75), Color.white.opacity(0.65), Color.white.opacity(0.5), Color.white.opacity(0.2), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        } else {
                            RadialGradient(
                                colors: [
                                    Color.white,
                                    Color.white,
                                    Color.white,
                                    Color.white.opacity(0.75),
                                    Color.white.opacity(0.65),
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        }
                    }
            } else {
                AsyncImage(url: URL(string: track.artwork)) { phase in
                    switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(maxWidth: expandedView ? .infinity : 40, maxHeight: expandedView ? nil : 40, alignment: .center)
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
                .frame(maxWidth: expandedView ? .infinity : 40, maxHeight: expandedView ? nil : 40, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: expandedView ? 10 : 2))
                .aspectRatio(1.0, contentMode: .fit)
                .shadow(radius: expandedView ? 10 : 0)
            }
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
                        .font(.caption.bold(self.stopTimeSlider).monospacedDigit())
                        .foregroundStyle(self.stopTimeSlider ? Color.white : Color.secondary)
                        .opacity(self.stopTimeSlider ? 1.0 : 0.5)
                        .contentTransition(.identity)

                    if self.audioFormat == .unknown {
                        Spacer()
                    } else {
                        Spacer()

                        self.audioFormat.view
                            .opacity(0.5)

                        Spacer()
                    }

                    Text("-" + self.formatTime(self.duration - self.currentTime))
                        .font(.caption.bold(self.stopTimeSlider).monospacedDigit())
                        .foregroundStyle(self.stopTimeSlider ? Color.white : Color.secondary)
                        .opacity(self.stopTimeSlider ? 1.0 : 0.5)
                        .contentTransition(.identity)
                }
                .offset(y: 5.0 + (self.stopTimeSlider ? 12.0 : 0.0))
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

    @ViewBuilder
    private var navigationActions: some View {
        HStack {
            Button {
                withAnimation(.easeOut.speed(1.3)) {
                    self.showingLyrics.toggle()
                }
            } label: {
                Image(systemName: "quote.bubble")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(self.showingLyrics ? Color.black.opacity(0.5) : Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(7.5)
            .background(self.showingLyrics ? Color.white.opacity(0.5) : Color.clear)
            .clipShape(Circle())

            Spacer()

            BrowserView.access($showingLibrary)

            Spacer()

            Button {
                Task {
                    await self.getAutoplay()
                    await self.getRepeat()
                }

                withAnimation(.easeOut.speed(1.3)) {
                    self.showingQueue.toggle()
                }
            } label: {
                Image(systemName: "list.bullet")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(self.showingQueue ? Color.black.opacity(0.5) : Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(7.5)
            .background(self.showingQueue ? Color.white.opacity(0.5) : Color.clear)
            .clipShape(Circle())
        }
    }

    @ViewBuilder
    private var queueActions: some View {
        GlassEffectContainer {
            HStack {
                Button {
                    Task {
                        await self.toggleAutoplay()
                    }
                } label: {
                    Image(systemName: "infinity")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .buttonBorderShape(.capsule)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive().tint(self.isAutoPlaying ? Color.accentColor : Color.clear), in: Capsule())

                Button {
                    Task {
                        await self.cycleRepeat()
                    }
                } label: {
                    Image(systemName: self.repeatMode.symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                }
                .buttonStyle(.plain)
                .buttonBorderShape(.capsule)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive().tint(self.repeatMode != .none ? Color.accentColor : Color.clear), in: Capsule())

                Button {
                    Task {
                        await self.cycleShuffle()
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                }
                .buttonStyle(.plain)
                .buttonBorderShape(.capsule)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive().tint(self.shuffleMode == .shuffling ? Color.accentColor : Color.clear), in: Capsule())
            }
        }
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func setupAVPlayer() {
        guard player == nil, let videoArtwork else { return }

        let newPlayer = AVPlayer(url: videoArtwork)
        self.player = newPlayer

        NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: newPlayer.currentItem, queue: .main) { _ in
            newPlayer.seek(to: CMTime.zero)
            newPlayer.play()
        }

        newPlayer.play()
    }

    private func alwaysOn(_ bool: Bool) {
#if !WIDGET
        UIApplication.shared.isIdleTimerDisabled = bool
        print("always-\(bool ? "on" : "off")")
#endif
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

    /// it also gets other stuff but shush who cares it works
    func getAnimatedCover(size: LibraryAlbum.AnimatedCover = .tall) async -> URL? {
        guard let currentTrack else { return nil }

        do {
            guard let data = try await device.runAppleMusicAPI(path: "/v1/catalog/us/songs/\(currentTrack.catalogId)?include=albums&extend[albums]=editorialVideo") as? [[String: Any]] else { return nil }

            if let relation: [String: Any] = data[0]["relationships"] as? [String: Any], let album: [String: Any] = relation["albums"] as? [String: Any], let subdata: [[String: Any]] = album["data"] as? [[String: Any]], let attributes = subdata[0]["attributes"] as? [String: Any] {

                if let audioTraits: [String] = attributes["audioTraits"] as? [String] {
                    print(audioTraits)
                    self.audioFormat = Track.AudioType.find(audioTraits)
                }

                if let videos: [String: Any] = attributes["editorialVideo"] as? [String: Any], let squareObj: [String: Any] = videos[size.rawValue] as? [String: Any], let squareStr: String = squareObj["video"] as? String {
                    return URL(string: squareStr)
                }
            }

            return nil
        } catch {
            handleError(error)
            return nil
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

    func getStorefront() async -> String? {
        do {
            guard let data: [[String: Any]] = try await device.runAppleMusicAPI(path: "/v1/me/storefront?limit=1") as? [[String: Any]], !data.isEmpty else { return nil }

            if let storefrontId: String = data[0]["id"] as? String {
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

            var newTrack: Track = Track(id: id ?? "", catalogId: amId ?? "", title: title, artist: artist, album: album, artwork: artworkUrl, duration: duration / 1000)

            if self.currentTrack != newTrack {
                Task {
                    newTrack.artworkData = await newTrack.getArtwork()?.pngData() ?? Data()
                    let isSameAlbum: Bool = self.currentTrack?.album == newTrack.album
                    self.currentTrack = newTrack

                    await self.updateQueue(newTrack: newTrack)

                    if !isSameAlbum {
                        await self.resetAVPlayer()
                    }
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

    private func resetAVPlayer() async {
        self.videoArtwork = nil
        self.player = nil

        self.videoArtwork = await self.getAnimatedCover(size: .tall)
        if self.videoArtwork != nil {
            self.setupAVPlayer()
        }
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

            return Track(id: id ?? "",
                         catalogId: amId ?? "",
                         title: title,
                         artist: artist,
                         album: album,
                         artwork: artworkUrl,
                         duration: duration / 1000,
                         artworkData: Data()
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

    func getArtwork(for url: URL?) async -> Data {
        guard let url else { return Data() }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            print("Error loading image: \(error)")
        }

        return Data()
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

    func getRepeat() async {
        do {
            let result = try await sendRequest(endpoint: "playback/repeat-mode", method: "GET")
            if let data = result as? [String: Any] {
                let val: Int = data["value"] as? Int ?? 0
                self.repeatMode = .init(rawValue: val) ?? .none
            }
        } catch {
            handleError(error)
        }
    }

    func getShuffle() async {
        do {
            let result = try await sendRequest(endpoint: "playback/shuffle-mode", method: "GET")
            if let data = result as? [String: Any] {
                let val: Int = data["value"] as? Int ?? 0
                self.shuffleMode = .init(rawValue: val) ?? .none
            }
        } catch {
            handleError(error)
        }
    }

    func getAutoplay() async {
        do {
            let result = try await sendRequest(endpoint: "playback/autoplay", method: "GET")
            if let data = result as? [String: Any] {
                self.isAutoPlaying = data["value"] as? Bool ?? false
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

    func cycleRepeat() async {
        print("Cycling through repeat")
        let lastRepeat: RepeatMode = self.repeatMode
        withAnimation {
            self.repeatMode = .init(rawValue: self.repeatMode.rawValue + 1) ?? .none
        }
        do {
            _ = try await sendRequest(endpoint: "playback/toggle-repeat", method: "POST")
        } catch {
            self.repeatMode = lastRepeat
            handleError(error)
        }
    }

    func cycleShuffle() async {
        print("Cycling through shuffle")
        let lastShuffle: ShuffleMode = self.shuffleMode
        withAnimation {
            self.shuffleMode = .init(rawValue: self.shuffleMode.rawValue + 1) ?? .none
        }
        do {
            _ = try await sendRequest(endpoint: "playback/toggle-shuffle", method: "POST")
        } catch {
            self.shuffleMode = lastShuffle
            handleError(error)
        }
    }

    func toggleAutoplay() async {
        print("Toggling autoplay")
        withAnimation {
            self.isAutoPlaying.toggle() // Immediately update UI
        }
        do {
            _ = try await sendRequest(endpoint: "playback/toggle-autoplay", method: "POST")
        } catch {
            isAutoPlaying.toggle()
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

    private enum RepeatMode: Int {
        case none = 0
        case queue = 2
        case track = 1

        var symbol: String {
            switch self {
                case .none, .queue:
                    "repeat"
                case .track:
                    "repeat.1"
            }
        }
    }

    private enum ShuffleMode: Int {
        case none = 0
        case shuffling = 1
    }
}

// MARK: - Extensions

private extension View {
    @ViewBuilder
    func minimalView(height: CGFloat? = 450) -> some View {
        self
            .mask(alignment: .center) {
                LinearGradient(
                    colors: [Color.white, Color.white, Color.white, Color.white.opacity(0.9), Color.white.opacity(0.8), Color.white.opacity(0.75), Color.white.opacity(0.65), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: height)
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

