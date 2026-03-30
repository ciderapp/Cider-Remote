// Made by Lumaa

import SwiftUI

struct LibraryPlaylistView: View {
    @EnvironmentObject private var device: Device

    @State var playlist: LibraryPlaylist

    @State private var isLoading: Bool = true

    @State private var sharingTrack: LibraryTrack? = nil
    @State private var sharingImage: UIImage? = nil

    @State private var viewingAlbum: LibraryAlbum? = nil

    init(_ playlist: LibraryPlaylist) {
        self.playlist = playlist
    }

    var body: some View {
        ScrollView(.vertical) {
            header

            if isLoading || self.playlist.tracks == nil {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.top, 100)
            } else {
                LazyVStack {
                    ForEach(self.playlist.tracks!) { track in
                        let idx: Int = (self.playlist.tracks!.firstIndex(of: track) ?? -1) + 1
                        Divider()

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
                                LibraryTrackRow(track, number: idx, showCover: true)
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

                                Divider()

                                Button {
                                    Task {
                                        self.viewingAlbum = await self.getAlbum(of: track)
                                    }
                                } label: {
                                    Label("View Album", image: "BoxNote")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .padding(7.0)
                            }
                            .disabled(track.catalogId == "[UNKNOWN]")
                            .tint(Color(uiColor: UIColor.label))
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                    }
                    Divider()
                }
                .padding(.top)
            }
        }
        .navigationTitle(Text(self.playlist.name))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $viewingAlbum) { album in
            LibraryAlbumView(album)
                .environmentObject(device)
        }
        .task {
            defer { self.isLoading = false }
            self.playlist.tracks = await self.getTracks(from: self.playlist)
        }
        .sheet(item: $sharingTrack) { t in
            ActivityViewController(item: .track(track: .init(from: t)))
                .presentationDetents([.medium, .large])
        }
    }

    var header: some View {
        LazyVStack {
            AsyncImage(url: URL(string: self.playlist.artwork)) { image in
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
                        guard let url = URL(string: self.playlist.artwork),
                              let (data, _) = try? await URLSession.shared.data(from: url),
                              let image = UIImage(data: data) else {
                            return
                        }

                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    }
                } label: {
                    Label("Save artwork", systemImage: "photo.badge.plus")
                }

                Button {
                    Task {
                        guard let url = URL(string: self.playlist.artwork),
                              let (data, _) = try? await URLSession.shared.data(from: url),
                              let image = UIImage(data: data) else {
                            return
                        }
                        self.sharingImage = image
                    }
                } label: {
                    Label("Share artwork", systemImage: "square.and.arrow.up")
                }
            }
            .sheet(item: Binding<UIImage?>(
                get: { sharingImage },
                set: { newValue in sharingImage = newValue }
            )) { image in
                ActivityViewController(item: .image(images: [image]))
                    .presentationDetents([.medium, .large])
            }

            Text(self.playlist.name)
                .font(.body.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 5.0)
    }
}

extension LibraryPlaylistView {
	func playHref(href: String) async {
		do {
			let path: String = device.useV2 ? "playback/play-href" : "playback/play-item-href"
			_ = try await device.sendRequest(endpoint: path, method: "POST", body: ["href": href])
		} catch {
			print("Error playing track: \(error)")
		}
	}

	func clearQueue() async {
		do {
			let path: String = device.useV2 ? "queue" : "playback/queue/clear-queue"
			let method: String = device.useV2 ? "DELETE" : "POST"

			_ = try await device.sendRequest(endpoint: path, method: method)
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
				let path: String = device.useV2 ? "playback/add-later" : "playback/play-later"
				let _ = try await device.sendRequest(endpoint: path, method: "POST", body: ["id": playingTrack.id, "type": "song"])
			} catch {
				print("Error playing next: \(error)")
			}
		}
	}

	func playNext(from playingTrack: LibraryTrack)  {
		Task {
			do {
				let path: String = device.useV2 ? "playback/add-next" : "playback/play-next"
				let _ = try await device.sendRequest(endpoint: path, method: "POST", body: ["id": playingTrack.id, "type": "song"])
			} catch {
				print("Error playing next: \(error)")
			}
		}
	}

    func getTracks(from playlist: LibraryPlaylist) async -> [LibraryTrack] {
        do {
            let data = try await device.runAppleMusicAPI(path: "/v1/me/library/playlists/\(playlist.id)/tracks")
            var libraries: [LibraryTrack] = []

            if let arrayd = data as? [[String: Any]] {
                for l in arrayd {
                    libraries.append(.init(data: l))
                }
            }

            return libraries
        } catch {
            print("Error getting library: \(error)")
        }

        return []
    }

    func getAlbum(of track: LibraryTrack) async -> LibraryAlbum? {
        do {
            guard let data = try await device.runAppleMusicAPI(path: "/v1/me/library/songs/\(track.id)/albums") as? [[String: Any]] else { return nil }
            print(data)

            return LibraryAlbum(data: data[0])
        } catch {
            print("Error getting library: \(error)")
        }

        return nil
    }
}
