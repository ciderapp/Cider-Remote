// Made by Lumaa

import SwiftUI

struct BrowserTabView: View {
    @EnvironmentObject private var device: Device

    let tab: BrowserTab

    @State private var elms: [LibraryElement] = []
    @State private var offset: Int = 10

    @State private var isLoading: Bool = true
    @State private var isLoadingMore: Bool = false

    private let columns = UserDevice.shared.isPad ? [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ] : [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    init(_ tab: BrowserTab) {
        self.tab = tab
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                library
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: UIColor.systemBackground))
        .task {
            defer { self.isLoading = false }
            self.elms = await self.getLibrary()
        }
    }

    var library: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, alignment: .center) {
                ForEach(self.elms) { elm in
                    NavigationLink(value: elm) {
                        switch elm {
                            case .album(let a):
                                LibraryRow(from: a)
                            case .playlist(let p):
                                LibraryRow(from: p)
                            default:
                                EmptyView()
                        }

                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Button {
                self.isLoadingMore = true

                Task {
                    defer { self.isLoadingMore = false }
                    self.elms.append(contentsOf: await self.getLibrary(offset: offset))
                    offset += 10
                }
            } label: {
                if #available(iOS 26.0, *) {
                    Text("Load 10 more")
                        .padding(.vertical, 10.0)
                        .padding(.horizontal, 25.0)
                        .glassEffect(.regular.interactive())
                } else {
                    Text("Load 10 more")
                        .foregroundStyle(Color.cider)
                        .padding(.vertical, 10.0)
                        .padding(.horizontal, 25.0)
                        .background(Material.ultraThin)
                        .clipShape(RoundedRectangle(cornerRadius: 7.0))
                }
            }
            .disabled(self.isLoadingMore)
            .padding(.top, 15.0)
            .padding(.bottom, 5.0)
        }
        .navigationTitle(Text(tab.localized))
        .navigationBarTitleDisplayMode(.large)
    }
}

extension BrowserTabView {
    func getLibrary(limit: Int = 10, offset: Int = 0) async -> [LibraryElement] {
        switch self.tab {
            case .albums:
                return await self.getAlbums(limit: limit, offset: offset).map { LibraryElement.album($0) }
            case .playlists:
                return await self.getPlaylists(limit: limit, offset: offset).map { LibraryElement.playlist($0) }
        }
    }

    func getAlbums(limit: Int = 10, offset: Int = 0) async -> [LibraryAlbum] {
        do {
            let data = try await device.runAppleMusicAPI(path: "/v1/me/library/albums?limit=\(limit)&offset=\(offset)")
            var libraries: [LibraryAlbum] = []

            if let arrayd = data as? [[String: Any]] {
                for l in arrayd {
                    let type: String = (l["type"] as? String ?? "[UNKNOWN]")
                    if type == "library-albums" {
                        libraries.append(.init(data: l))
                    }
                }
            }

            return libraries
        } catch {
            print("Error getting library: \(error)")
        }

        return []
    }

    func getPlaylists(limit: Int = 10, offset: Int = 0) async -> [LibraryPlaylist] {
        do {
            let data = try await device.runAppleMusicAPI(path: "/v1/me/library/playlists?limit=\(limit)&offset=\(offset)")
            var libraries: [LibraryPlaylist] = []

            if let arrayd = data as? [[String: Any]] {
                for l in arrayd {
                    let type: String = (l["type"] as? String ?? "[UNKNOWN]")
                    if type == "library-playlists" {
                        libraries.append(.init(data: l))
                    }
                }
            }

            return libraries
        } catch {
            print("Error getting library: \(error)")
        }

        return []
    }
}

