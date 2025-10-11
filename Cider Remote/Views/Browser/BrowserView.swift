// Made by Lumaa

import SwiftUI

struct BrowserView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction

    let device: Device

    @State private var isLoading: Bool = true
    @State private var isLoadingMore: Bool = false
    @State private var offset: Int = 10

    @State private var elms: [LibraryElement] = []

    private let columns = UserDevice.shared.isPad ? [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ] : [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                library
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        NavigationStack {
            ScrollView(.vertical) {
                tabs
                Divider()

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
            .navigationTitle(Text("Recently Added"))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: LibraryElement.self) { elm in
                ZStack {
                    switch elm {
                        case .album(let a):
                            LibraryAlbumView(a)
                        case .playlist(let p):
                            LibraryPlaylistView(p)
                        case .tab(let t):
                            BrowserTabView(t)
                    }
                }
                .environmentObject(device)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(UserDevice.shared.isBeta ? Color(uiColor: UIColor.label) : Color.cider)
                    }
                }
            }
        }
        .tint(Color.cider)
    }

    @ViewBuilder
    private var tabs: some View {
        ForEach(BrowserTab.allCases) { tab in
            Divider()
            NavigationLink(value: LibraryElement.tab(tab)) {
                ZStack(alignment: .leading) {
                    tab.view
                        .padding(.leading)
                        .padding(.vertical, 5.0)
                        .foregroundStyle(Color.cider)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    static func access(_ sheetVisible: Binding<Bool>, background: Color = Color.clear) -> some View {
        Button {
            sheetVisible.wrappedValue.toggle()
        } label: {
            if #available(iOS 26.0, *) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "play.square.stack.fill")
                        .imageScale(.large)
                        .foregroundStyle(Color.white)

                    Text("View Library")
                        .font(.body.bold())
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .glassEffect(.regular.interactive())
            } else {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "play.square.stack.fill")
                        .imageScale(.large)
                        .foregroundStyle(Color.white)

                    Text("View Library")
                        .font(.body.bold())
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background {
                    ZStack {
                        Rectangle()
                            .fill(Material.ultraThin)
                            .zIndex(10)

                        Rectangle()
                            .fill(background.gradient)
                            .opacity(0.6)
                            .zIndex(1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

extension BrowserView {
    func getLibrary(offset: Int = 0) async -> [LibraryElement] {
        do {
            let data = try await device.runAppleMusicAPI(path: "/v1/me/library/recently-added?offset=\(offset)")
            var libraries: [LibraryElement] = []

            if let arrayd = data as? [[String: Any]] {
                for l in arrayd {
                    let type: String = (l["type"] as? String ?? "[UNKNOWN]")
                    if type == "library-albums" {
                        libraries.append(.album(.init(data: l)))
                    } else if type == "library-playlists" {
                        libraries.append(.playlist(.init(data: l)))
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

