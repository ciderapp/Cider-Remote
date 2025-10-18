// Made by Lumaa


import SwiftUI

struct LyricsView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @ObservedObject private var userDevice: UserDevice = .shared

    var device: Device
    @Binding var currentTrack: Track?
    @Binding var currentTime: Double

    @State private var lyrics: [LyricLine] = []
    @State private var lyricCache: [String: [LyricLine]] = [:]
    @State private var lyricsProvider: Parser.LyricProvider?
    @State private var activeLine: LyricLine?

    @State private var isLoading: Bool = false

    private let lineSpacing: CGFloat = 18 // Increased spacing between lines
    public static let lyricAdvanceTime: Double = 0.2 // Advance lyrics 0.2 seconds early

    private var lyricProviderString: String? {
        guard let lyricsProvider else { return nil }

        switch lyricsProvider {
            case .mxm:
                return "Musixmatch"
            case .am:
                return "Apple Music"
            case .cache:
                return "Remote (Cache)"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    if !self.isLoading {
                        if lyrics.isEmpty {
                            ContentUnavailableView("No lyrics available", systemImage: "quote.bubble")
                                .frame(maxHeight: .infinity)
                        } else {
                            ZStack {
                                if userDevice.horizontalOrientation == .portrait || userDevice.isPad {
                                    LyricsScrollView(
                                        lyrics: lyrics,
                                        activeLine: $activeLine,
                                        currentTime: $currentTime,
                                        viewportHeight: geometry.size.height,
                                        lineSpacing: lineSpacing,
                                        changeTime: seekToTime
                                    )
                                } else {
                                    ImmersiveLyricsView(
                                        lyrics: lyrics,
                                        activeLine: $activeLine,
                                        currentTime: $currentTime
                                    )
                                }
                            }
                            .overlay(alignment: .bottom) {
                                if let lyricProviderString {
                                    Text(lyricProviderString)
                                        .font(.callout)
                                        .padding(.horizontal)
                                        .padding(.vertical, 7.5)
                                        .glassEffect(.regular, in: .capsule)
                                        .padding(.bottom, 22.5)
                                }
                            }
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .foregroundStyle(Color.primary)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: geometry.size.width)
            }
        }
        .foregroundStyle(colorScheme == .dark ? .white : .black)
        .task {
            await self.fetchAllLyrics()
        }
        .onChange(of: currentTime) { _, newTime in
            updateCurrentLyric(time: newTime + Self.lyricAdvanceTime)
        }
    }

    // MARK: - Methods

    private func seekToTime(to newTime: Double) async {
        print("Seeking to time: \(newTime)")
        do {
            _ = try await device.sendRequest(endpoint: "playback/seek", method: "POST", body: ["position": newTime])
        } catch {
            print(error)
        }
    }

    private func updateCurrentLyric(time: Double) {
        guard let currentLine = lyrics.last(where: { $0.timestamp <= time }) else {
            activeLine = nil
            return
        }

        withAnimation(.easeInOut.speed(0.85)) {
            activeLine = currentLine
        }
    }


    private func fetchAllLyrics() async {
        defer { self.isLoading = false }
        self.isLoading = true

        let success: Bool = await self.fetchLyricsAm() // apple music
        if !success {
            _ = await self.fetchLyricsMxm() // musixmatch
        }
    }

    /// Returns true if the lyrics were found and fetched
    private func fetchLyricsMxm() async -> Bool {
        guard let currentTrack else { return false }

        print("Current track ID: \(currentTrack.id)")

        if let cachedLyrics = lyricCache[currentTrack.id] {
            print("Using cached lyrics for track: \(currentTrack.id)")
            self.lyricsProvider = .cache
            self.lyrics = cachedLyrics
            return true
        }

        self.lyrics = []
        self.isLoading = true
        guard let lyricsUrl = URL(string: "https://rise.cider.sh/api/v1/lyrics/mxm") else { return false }

        do {
            print("Fetching lyrics ONLINE for track: \(currentTrack.id)")

            let lyricReq: Track.RequestLyrics = .init(track: currentTrack)
            let encoder: JSONEncoder = .init()
            let body: Data = try encoder.encode(lyricReq)

            var req = URLRequest(url: lyricsUrl, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: .infinity)
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")

            req.httpMethod = "POST"
            req.httpBody = body

            let (data, response) = try await URLSession.shared.data(for: req)

            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let decoder: JSONDecoder = .init()
                print(String(data: data, encoding: .utf8) ?? "wtf?")
                let mxm = try decoder.decode(Track.MxmLyrics.self, from: data)

                let lines = mxm.decodeHtml()
                print("Parsed \(lines.count) lyric lines")
                if lines.count > 0 {
                    DispatchQueue.main.async {
                        self.lyricsProvider = .mxm
                        self.lyrics = lines
                        self.lyricCache[currentTrack.id] = self.lyrics
                    }
                    return true
                }
            } else {
                self.lyrics = []
                throw NetworkError.serverError("Couldn't reach server")
            }
        } catch {
            self.lyrics = []
            print(error)
        }
        return false
    }

    /// Returns true if the lyrics were found and fetched
    private func fetchLyricsAm() async -> Bool {
        guard let currentTrack else { return false }

        print("Current track ID: \(currentTrack.id)")

        if let cachedLyrics = lyricCache[currentTrack.id] {
            print("Using cached lyrics for track: \(currentTrack.id)")
            self.lyricsProvider = .cache
            self.lyrics = cachedLyrics
            return true
        }

        do {
            guard let storefront = await self.getStorefront() else { return false }

            print("Fetching lyrics FROM CLIENT for track: \(currentTrack.id)")
            let path: String = "/v1/catalog/\(storefront)/songs/\(currentTrack.catalogId)/lyrics?l=en-US&platform=web&art[url]=f"
            let data = try await device.sendRequest(endpoint: "amapi/run-v3", method: "POST", body: ["path": path])

            print(data)
            if let jsonDict = data as? [String: Any], let data = jsonDict["data"] as? [String: Any], let subdata = data["data"] as? [[String: Any]], let lyricsData = subdata[0]["attributes"] as? [String: Any] {
                guard let lyricsXml = lyricsData["ttml"] as? String, let data = lyricsXml.data(using: .utf8) else {
                    print("-- After fetch decoding error --")
                    throw NetworkError.decodingError
                }

                let xmlParser = XMLParser(data: data)
                let ttmlParser = Parser(provider: .am)
                xmlParser.delegate = ttmlParser
                xmlParser.parse()

                self.lyricsProvider = .am
                self.lyrics = ttmlParser.lyrics
                self.lyricCache[currentTrack.id] = self.lyrics
                return true
            } else {
                throw NetworkError.invalidResponse
            }
        } catch {
            print("Error fetching lyrics: \(error)")
        }
        return false
    }

    private func getStorefront() async -> String? {
        do {
            guard let data: [[String: Any]] = try await device.runAppleMusicAPI(path: "/v1/me/storefront?limit=1") as? [[String: Any]], !data.isEmpty else { return nil }

            if let storefrontId: String = data[0]["id"] as? String {
                return storefrontId
            }
        } catch {
            print("Error fetching storefront: \(error)")
        }

        return nil
    }
}

struct LyricsScrollView: View {
    @EnvironmentObject private var device: Device

    let lyrics: [LyricLine]
    @Binding var activeLine: LyricLine?

    @Binding var currentTime: Double

    let viewportHeight: CGFloat
    let lineSpacing: CGFloat

    let changeTime: (Double) async -> Void

    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollView in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: lineSpacing) {
                        Spacer(minLength: 180) // Space for one line above active lyric
                        ForEach(lyrics) { line in
                            Button {
                                Task {
                                    defer {
                                        self.activeLine = line
                                        self.currentTime = line.timestamp + LyricsView.lyricAdvanceTime
                                    }
                                    await self.changeTime(line.timestamp + LyricsView.lyricAdvanceTime)
                                }
                            } label: {
                                LyricLineView(
                                    lyric: line,
                                    isActive: line == activeLine,
                                    maxWidth: geometry.size.width - 20
                                )
                                .frame(maxWidth: .infinity, alignment: line.altVoice ? .trailing : .leading)
                                .padding(.horizontal, 20)
                                .scrollTransition { content, phase in
                                    content
                                        .offset(y: phase.isIdentity ? 0.0 : max(min(phase.value * 17.5, 17.5), -17.5))
                                        .opacity(phase.isIdentity ? 1.0 : 0.85)
                                        .blur(radius: phase.isIdentity ? 0.0 : 8.5)
                                }
                            }
                            .id(line.id)
                        }
                        Spacer(minLength: viewportHeight - 180) // Remaining space below lyrics
                    }
                }
                .scrollClipDisabled()
                .onChange(of: activeLine) { _, newActiveLine in
                    if let newActiveLine = newActiveLine, !isDragging {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            if let index = lyrics.firstIndex(of: newActiveLine), index > 0 {
                                scrollView.scrollTo(lyrics[index - 1].id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: viewportHeight)
    }
}

struct ImmersiveLyricsView: View {
    let lyrics: [LyricLine]
    @Binding var activeLine: LyricLine?
    @Binding var currentTime: Double

    var body: some View {
        if let activeLine {
            Text(activeLine.text)
                .font(.system(size: 52).bold())
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText(countsDown: true))
                .frame(maxHeight: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
    }
}

struct LyricLineView: View {
    let lyric: LyricLine
    let isActive: Bool
    let maxWidth: CGFloat

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(lyric.text)
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(textColor)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .multilineTextAlignment(lyric.altVoice ? .trailing : .leading)
            .frame(maxWidth: maxWidth, alignment: lyric.altVoice ? .trailing : .leading)
            .scaleEffect(isActive ? 1.0 : 0.7, anchor: lyric.altVoice ? .trailing : .leading)
            .animation(.spring(duration: 0.3), value: isActive)
    }

    private var textColor: Color {
        if (isActive) {
            return .white
        } else {
            return .gray.opacity(0.35)
        }
    }
}

// MARK: Lyric Data

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let timestamp: Double
    let isMainLyric: Bool
    let altVoice: Bool

    init(text: String, timestamp: Double, isMainLyric: Bool = false, altVoice: Bool = false) {
        self.text = text
        self.timestamp = timestamp
        self.isMainLyric = isMainLyric
        self.altVoice = altVoice
    }
}
