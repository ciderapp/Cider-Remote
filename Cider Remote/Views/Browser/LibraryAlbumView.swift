// Made by Lumaa

import AVKit
import SwiftUI

struct LibraryAlbumView: View {
    @EnvironmentObject private var device: Device

    @State var album: LibraryAlbum

    @State private var isLoading: Bool = true

    @State private var multiDisc: Bool = false
    @State private var releaseDate: Date? = nil

    @State private var player: AVPlayer? = nil
    @State private var videoURL: URL? = nil

    @State private var sharingTrack: LibraryTrack? = nil
    @State private var sharingImage: UIImage? = nil

    init(_ album: LibraryAlbum) {
        self.album = album
    }

    var body: some View {
        ScrollView(.vertical) {
            header

            if isLoading || self.album.tracks == nil {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.top, 100)
            } else {
                LazyVStack {
                    releaseEvent
                        .padding(.vertical, 12.0)

                    ForEach(self.album.tracks!) { track in
                        Divider()

                        if track.trackNumber == 1 && self.multiDisc {
                            HStack {
                                Image(.compactDisc)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .padding(.trailing)

                                Text("Disc \(track.discNumber)")
                                    .font(.title2.bold())
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                            Divider()
                        }

                        HStack {
                            Button {
                                Task {
                                    await self.playHref(href: track.href)
//                                    await self.clearQueue()
//                                    self.playNext(from: track)
//
//                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                                        Task {
//                                            await self.skipTrack()
//                                        }
//                                    }
                                }
                            } label: {
                                LibraryTrackRow(track, number: track.trackNumber, showCover: false)
                                    .padding(.vertical, UserDevice.shared.isBeta ? 15.0 : 5.0)
                            }
                            .disabled(track.catalogId == "[UNKNOWN]")
                            .tint(Color(uiColor: UIColor.label))
                            .buttonStyle(PlainButtonStyle())
                            .contentShape(Rectangle())

                            Spacer()

                            Menu {
                                Button {
                                    self.sharingTrack = track
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }

                                Divider()

                                Button {
                                    self.playNext(from: track)
                                } label: {
                                    Label("Play Next", image: "PlayNext")
                                }

                                Button {
                                    self.playLater(from: track)
                                } label: {
                                    Label("Play Later", image: "PlayLater")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                            }
                            .disabled(track.catalogId == "[UNKNOWN]")
                            .tint(Color(uiColor: UIColor.label))
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                    }
                    Divider()
                }
                .padding(.top, videoURL != nil ? 0 : 15.0)
            }
        }
        .padding(.top, videoURL != nil ? -120 : 0)
        .navigationTitle(Text(album.title))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            defer { self.isLoading = false }

            let amData: (URL?, Track.AudioType) = await self.album.getAnimatedCover(using: device, size: .tall)
            self.videoURL = amData.0
            self.album.audioType = amData.1

            self.album.tracks = await self.getTracks(from: self.album)
            self.setupPlayer()

            if let last = self.album.tracks?.map({ $0.discNumber }).last {
                self.multiDisc = last > 1
            }
        }
        .sheet(item: $sharingTrack) { t in
            ActivityViewController(item: .track(track: .init(from: t)))
                .presentationDetents([.medium, .large])
        }
    }

    var header: some View {
        LazyVStack {
            if let player {
                UninteractableVideoPlayer(player: player)
                    .aspectRatio(LibraryAlbum.AnimatedCover.tall.ratio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottom) {
                        VStack {
                            Text(self.album.title)
                                .font(.body.bold())
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            Text(self.album.artist)
                                .font(.body)
                                .lineLimit(1)
                                .foregroundStyle(Color.secondary)

                            if self.album.audioType != .unknown {
                                self.album.audioType.view
                            }
                        }
                        .padding(10.0)
                        .frame(width: 250, alignment: .center)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 15.0))
                        .padding(.vertical, 25.0)
                    }
            } else {
                AsyncImage(url: URL(string: album.artwork)) { image in
                    image
                        .resizable()
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                } placeholder: {
                    ZStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .zIndex(20)

                        Rectangle()
                            .fill(Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .zIndex(10)
                    }
                    .frame(width: 220, height: 220)
                }
                .contextMenu {
                    Button {
                        Task {
                            guard let url = URL(string: album.artwork),
                                  let (data, _) = try? await URLSession.shared.data(from: url),
                                  let image = UIImage(data: data) else {
                                return
                            }
                            self.sharingImage = image
                        }
                    } label: {
                        Label("Share image", systemImage: "square.and.arrow.up")
                    }
                }
                .sheet(item: Binding<UIImage?>(
                    get: { sharingImage },
                    set: { newValue in sharingImage = newValue }
                )) { image in
                    ActivityViewController(item: .image(images: [image]))
                        .presentationDetents([.medium, .large])
                }

                Text(self.album.title)
                    .font(.body.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(self.album.artist)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(Color.secondary)

                if self.album.audioType != .unknown {
                    self.album.audioType.view
                }
            }
        }
        .padding(.horizontal, self.videoURL == nil ? 5.0 : 0.0)
    }

    @ViewBuilder
    var releaseEvent: some View {
        if let releaseDate {
            VStack {
                Text("Releases in...")
                    .foregroundStyle(Color.white)
                    .font(.callout)
                    .lineLimit(1)

                Text(releaseDate, style: .relative)
                    .foregroundStyle(Color.white)
                    .font(.title2.bold())
            }
            .padding()
            .background(Color.cider)
            .clipShape(RoundedRectangle(cornerRadius: 10.0))
        }
    }

    private func setupPlayer() {
        guard player == nil, let videoURL else { return }

        let newPlayer = AVPlayer(url: videoURL)
        self.player = newPlayer

        NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: newPlayer.currentItem, queue: .main) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }

        newPlayer.play()
    }
}

extension UIImage: @retroactive Identifiable {
    public var id: UUID {
        UUID()
    }
}

extension LibraryAlbumView {
    func playHref(href: String) async {
        do {
            _ = try await device.sendRequest(endpoint: "playback/play-item-href", method: "POST", body: ["href": href])
        } catch {
            print("Error playing track: \(error)")
        }
    }

    func clearQueue() async {
        do {
            _ = try await device.sendRequest(endpoint: "playback/queue/clear-queue", method: "POST")
        } catch {
            print("Error clearing queue: \(error)")
        }
    }

    func skipTrack() async {
        do {
            _ = try await device.sendRequest(endpoint: "playback/next", method: "POST")
        } catch {
            print("Error playing next track: \(error)")
        }
    }

    func playLater(from playingTrack: LibraryTrack)  {
        Task {
            do {
                let _ = try await device.sendRequest(endpoint: "playback/play-later", method: "POST", body: ["id": playingTrack.id, "type": "song"])
            } catch {
                print("Error playing next: \(error)")
            }
        }
    }

    func playNext(from playingTrack: LibraryTrack)  {
        Task {
            do {
                let _ = try await device.sendRequest(endpoint: "playback/play-next", method: "POST", body: ["id": playingTrack.id, "type": "song"])
            } catch {
                print("Error playing next: \(error)")
            }
        }
    }

    func getTracks(from album: LibraryAlbum) async -> [LibraryTrack] {
        do {
            let data = try await device.runAppleMusicAPI(path: "/v1/me/library/albums/\(album.id)/tracks")
            var libraries: [LibraryTrack] = []

            if let arrayd = data as? [[String: Any]] {
                for l in arrayd {
                    libraries.append(.init(data: l, from: album))
                }
            }

            if libraries.contains(where: { $0.catalogId == "[UNKNOWN]" }) {
                if let available: LibraryTrack = libraries.first(where: { $0.catalogId != "[UNKNOWN]"}) {
                    await self.getAlbum(using: available)
                }
            }

            return libraries
        } catch {
            print("Error getting library: \(error)")
        }

        return []
    }

    func getAlbum(using track: LibraryTrack) async {
        do {
            guard let data: [[String: Any]] = try await device.runAppleMusicAPI(path: "/v1/catalog/us/songs/\(track.catalogId)/albums") as? [[String: Any]], data.count > 0 else { return }

            if let attributes: [String: Any] = data[0]["attributes"] as? [String: Any], attributes["isPrerelease"] as? Int == 1 {
                let dateFormat: DateFormatter = .init()
                dateFormat.dateFormat = "YYYY-MM-dd"

                if let dateString = attributes["releaseDate"] as? String {
                    self.releaseDate = dateFormat.date(from: dateString)
                }
            }
        } catch {
            print("Error getting album details: \(error)")
        }
    }
}
