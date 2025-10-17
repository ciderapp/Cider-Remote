// Made by Lumaa

import SwiftUI

struct ChangelogsView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @Environment(\.openURL) private var openURL: OpenURLAction

    private static let changelogs: [Changelog] = [.v400, .v311, .v310, .v303, .v302, .v301, .v300]

    @State private var selectedChangelog: Changelog? = nil

    var body: some View {
        List {
            if let first = Self.changelogs.first {
                Button {
                    self.selectedChangelog = first
                } label: {
                    self.banner(changelog: first)
                }
                .listRowInsets(EdgeInsets())
            }

            if Self.changelogs.count > 1 {
                Section(header: Text("Older changelogs")) {
                    ForEach(Self.changelogs[1...Self.changelogs.count - 1]) { chnglg in
                        Button {
                            self.selectedChangelog = chnglg
                        } label: {
                            self.list(changelog: chnglg)
                        }
                        .listRowInsets(EdgeInsets())
                    }
                }
            }
        }
        .navigationTitle(Text("Changelogs"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedChangelog) { log in
            log.view(colorScheme: colorScheme, openURL: openURL) {
                self.selectedChangelog = nil
            }
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private func banner(color: AnyGradient = Color.cider.gradient, changelog: Changelog) -> some View {
        VStack(spacing: 0) {
            Text(changelog.version)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, minHeight: 100)
                .font(
                    .system(size: CGFloat.getFontSize(UIFont.preferredFont(forTextStyle: .largeTitle)) + 25.0, weight: .black)
                    .width(.expanded)
                )
                .lineLimit(1)
                .background(color)
                .foregroundStyle(Color.white)

            Divider()

            HStack(spacing: 8) {
                Text("Remote \(changelog.version)")
                    .foregroundStyle(Color(uiColor: UIColor.label))

                Image(systemName: "chevron.forward")
                    .foregroundStyle(Color.secondary)
            }
            .font(.title2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 10.0)
        }
    }

    @ViewBuilder
    private func list(changelog: Changelog) -> some View {
        HStack(spacing: 8) {
            Text("Remote \(changelog.version)")
                .foregroundStyle(Color(uiColor: UIColor.label))

            Spacer()

            Image(systemName: "chevron.forward")
                .foregroundStyle(Color.secondary)
                .opacity(0.5)
        }
        .font(.body)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10.0)
    }
}

struct Changelog: Hashable, Identifiable {
    var id: String {
        "CiderRemote_v\(self.version.replacing(/\.+/, with: ""))"
    }
    let version: String
    let authors: [String]
    let commitsIds: String? // 2440087...31d0ddf
    var additions: [String] = []
    var modifications: [String] = []
    var removals: [String] = []
    var header: String? = nil
    var footer: String? = nil

    var compareUrl: URL? {
        guard let commitsIds else { return nil }
        return URL(string: "https://github.com/ciderapp/Cider-Remote/compare/\(commitsIds)")
    }

    init(version: String, authors: [String] = [], commits: String? = nil) {
        self.version = version
        self.authors = authors
        self.commitsIds = commits
    }

    mutating func setChanges(additions: [String] = [], modifications: [String] = [], removals: [String] = []) -> Self {
        self.additions = additions
        self.modifications = modifications
        self.removals = removals
        return self
    }

    mutating func setNotes(headerNote: String? = nil, footerNote: String? = nil) -> Self {
        self.header = headerNote
        self.footer = footerNote
        return self
    }

    func view(colorScheme: ColorScheme = .light, openURL: OpenURLAction, dismiss: @escaping () -> Void) -> some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    if let header {
                        Text(header)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 15.0)
                            .padding(.vertical, 10.0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                colorScheme == .light ? Color.gray
                                    .opacity(0.3) : Color(uiColor: UIColor.tertiarySystemBackground)
                                    .opacity(0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 5.0))
                    }

                    if !self.additions.isEmpty {
                        VStack(alignment: .leading, spacing: 8.0) {
                            Text("Added:")
                                .font(.title2.bold())
                                .lineLimit(1)

                            ForEach(self.additions, id: \.self) { added in
                                HStack(alignment: .top) {
                                    Image(systemName: "plus.circle.fill")
                                        .imageScale(.small)
                                        .foregroundStyle(Color.white, Color.green)

                                    Text(added)
                                        .font(.callout)
                                }
                            }
                        }
                        .padding(.vertical)
                    }

                    if !self.modifications.isEmpty {
                        VStack(alignment: .leading, spacing: 8.0) {
                            Text("Changed:")
                                .font(.title2.bold())
                                .lineLimit(1)

                            ForEach(self.modifications, id: \.self) { modified in
                                HStack(alignment: .top) {
                                    Image(systemName: "pencil.circle.fill")
                                        .imageScale(.small)
                                        .foregroundStyle(Color.white, Color.yellow)

                                    Text(modified)
                                        .font(.callout)
                                }
                            }
                        }
                        .padding(.vertical)
                    }

                    if !self.removals.isEmpty {
                        VStack(alignment: .leading, spacing: 8.0) {
                            Text("Removed:")
                                .font(.title2.bold())
                                .lineLimit(1)

                            ForEach(self.removals, id: \.self) { removed in
                                HStack(alignment: .top) {
                                    Image(systemName: "minus.circle.fill")
                                        .imageScale(.small)
                                        .foregroundStyle(Color.white, Color.red)

                                    Text(removed)
                                        .font(.callout)
                                }
                            }
                        }
                        .padding(.vertical)
                    }

                    if let footer {
                        Text(footer)
                            .font(.subheadline)
                            .padding(.horizontal, 15.0)
                            .padding(.vertical, 10.0)
                            .background(
                                colorScheme == .light ? Color.gray
                                    .opacity(0.3) : Color(uiColor: UIColor.tertiarySystemBackground)
                                    .opacity(0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 5.0))
                    }

                    VStack(alignment: .leading, spacing: 8.0) {
                        Text("Contributors for \(self.version):")
                            .font(.title2.bold())
                            .lineLimit(1)

                        HStack {
                            ForEach(self.authors, id: \.self) { author in
                                Text(author)
                                    .font(.callout.width(.expanded))
                                    .padding(.horizontal, 10.0)
                                    .padding(.vertical, 5.0)
                                    .background(
                                        colorScheme == .light ? Color.gray
                                            .opacity(0.3) : Color(uiColor: UIColor.tertiarySystemBackground)
                                            .opacity(0.5)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if let url = self.compareUrl {
                        Button {
                            openURL(url)
                        } label: {
                            HStack(spacing: 8.0) {
                                Text("View changes")
                                    .bold()

                                Image(systemName: "arrow.up.right.square")
                            }
                            .foregroundStyle(Color.white)
                        }
                        .tint(Color.cider)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle(Text("Remote v\(self.version)"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }
            }
        }
    }
}

// MARK: Changelogs are HERE

extension Changelog {
    /// Remote 4.0.0
    static var v400: Changelog {
        var temp = Changelog(version: "4.0.0", authors: ["Lumaa"], commits: "main...v4")
        temp = temp
            .setChanges(additions: [
                "Cider Collective team in the contributors screen",
                "Animated album covers",
                "Shuffle, repeat and autoplay buttons at the top of the queue (thanks gabrielzv1233!)",
                "Slowly moving color gradient in the background",
                "Left-to-right and right-to-left lyrics",
                "New \"Cider Remote\" title integrated in the screen's top bar",
            ], modifications: [
                "Temporary?: iOS 26+ only",
                "The \"Cider Devices\" title has been replaced with \"Cider Remote\"",
                "\"Library Browser\" button is always displayed now",
                "A more Apple Music-like user interface when remote-ing",
                "Unified design in the changelogs screen and connection guide screen",
                "More Liquid Glass",
                "Contributors screen moved in the copyright section",
                "Smaller \"Library Browser\" button to fit its new location",
                "The message about Cider 4 & Remote v4.0.0 will now re-appear with new text"
            ], removals: [
                "Background with blurred song cover",
                "\"Use Dynamic Colors\", \"Button Size\" settings, and contributors text in the settings",
                "View Models"
            ])
        temp = temp.setNotes(headerNote: "Remote v4.0.0 is full redesign of the remote app and goes along with Cider 4's new logistic")
        return temp
    }

    /// Remote 3.1.1
    static var v311: Changelog {
        var temp = Changelog(version: "3.1.1", authors: ["Lumaa"], commits: "2021475...41dc79a")
        temp = temp
            .setChanges(additions: ["A message about Cider 4 & Remote v4.0.0 will now appear"], modifications: ["Fix: Playlists won't crash the app anymore"])
        return temp
    }

    /// Remote 3.1.0
    static var v310: Changelog {
        var temp = Changelog(version: "3.1.0", authors: ["Lumaa"], commits: "7b5dd1...2021475")
        temp = temp
            .setChanges(additions: [
                "iOS 26 support",
                "Liquid Glass design",
                "A brand new Liquid Glass app icon on iOS 26",
                "Access your playlist in the Library Browser",
                "\"Play Next\" and \"Play Later\" in the Library Browser",
                "Library Browser button after a queue finishes (thanks Ambre!)",
                "New setting \"Always-on Immersive\" to keep the device on when using the Horizontal Layout",
                "A \"Close\" button in the queue in Horizontal Layout"
            ], modifications: [
                "The \"View Library\" button is now Liquid Glass on iOS 26",
                "The \"View Library\" button is now pinned at the top of the queue on iOS 26",
                "All prompts are now sheets on iOS 26",
                "Lyric provider is now Liquid Glass on iOS 26",
                "Changed the Finder icon for macOS 26's icon in the Cider Devices list",
                "Share album covers from the Library Browser",
                "Major improvements in Cider devices handling",
                "Fix: Moving tracks in a one-track-long queue will no longer crash",
                "Fix: Local songs won't crash Cider Remote anymore (thanks gabrielzv1233!)",
                "Fix: Queue will appear empty if a single track is played",
                "Fix: Remote now tries Apple Music's lyrics then Musixmatch's lyrics correctly",
                "Fix: Immersive Lyrics don't instantly jump from one lyric to another",
                "Fix: Cider icon would clip through the Live Activity on macOS Tahoe 26"
            ], removals: [
                "All iOS 16 devices are now unsupported by Cider Remote due to the limitations of Swift",
                "\"Auto-refresh\" setting, force enabled now"
            ])
        return temp.setNotes(headerNote: "Cider Remote goes through its Liquid Glass revolution thanks to iOS 26")
    }

    /// Remote 3.0.3
    static var v303: Changelog {
        var temp = Changelog(version: "3.0.3", authors: ["Lumaa"], commits: "bf16446...7b5dd1")
        temp = temp
            .setChanges(additions: [
                "Library Browser!",
                "Play a track from your recently added albums list (more later...)",
                "Track album releases with a countdown",
                "iPad support!"
            ], modifications: [
                "Fix: The queue or lyrics would close when changing vertical orientation, not anymore",
                "Fix: Immersive Lyrics now enables only in landscape mode"
            ], removals: [
                "Track search bar in the queue"
            ])
        return temp
    }

    /// Remote 3.0.2
    static var v302: Changelog {
        var temp = Changelog(version: "3.0.2", authors: ["Lumaa"], commits: "8d052a3...bf16446")
        temp = temp
            .setChanges(additions: [
                "Out-of-app control!",
                "Shortcuts support, 2 actions",
                "Share tracks in the ellipsis menu",
                "Prompt to enable access to the camera when adding a device",
                "iOS 18 users have a \"Play/Pause\" action and a \"Skip/Go back\" action in the Control Center"
            ], modifications: [
                "iOS 17 users can now play or pause in the Live Activity",
                "Unified the sliders' width in the Now Playing view",
                "Fix: Lyrics are now fetched once instead of everytime users tap the \"Lyrics\" button",
                "Fix: The Horizontal Layout would activate when the device is facing towards the ceiling or the floor",
                "Fix: The \"Unstable\" pill is now correctly written in white"
            ])
        return temp.setNotes(headerNote: "The roadmap is already halfway done, out-of-the-app actions are done")
    }

    /// Remote 3.0.1
    static var v301: Changelog {
        var temp = Changelog(version: "3.0.1", authors: ["Lumaa"], commits: "4457253...8d052a3")
        temp = temp
            .setChanges(additions: [
                "App Store release!",
                "Horizontal Layout",
                "Immersive Lyrics (only in Horizontal Layout)",
                "Apple Music lyric provider",
                "\"Device Information\" setting to display advanced info about Cider devices",
                "\"Review Cider Remote\" and \"Share Cider Remote\" buttons in the settings"
            ], modifications: [
                "The lyric provider displays the correct lyric provider, and \"Remote (Cache)\" when the lyrics are obtained from the cache",
                "Added the \"Favorite\" in the additional actions (ellipsis menu)",
                "The \"Cider Devices\" header is now smaller to fit the horizontal layout",
                "Live Activities are now available for iOS 16.1 users",
                "Lyric parser is smarter than ever",
                "Even more optimizations and file organization"
            ], removals: [
                "TestFlight specific label in settings"
            ])
        return temp.setNotes(headerNote: "The Horizontal Layout from the roadmap can already be crossed out")
    }

    /// Remote 3.0.0
    static var v300: Changelog {
        var temp = Changelog(version: "3.0.0", authors: ["Lumaa"], commits: "4a4173a...4457253")
        temp = temp
            .setChanges(additions: [
                "In-app changelogs",
                "Lyrics are back!",
                "Lyrics service is shown at the bottom now"
            ], modifications: [
                "Queue and lyrics appear on the same page",
                "Search results now use the new listing system",
                "Changed play/pause button icon",
                "Time and volume bars grow thicker when dragging",
                "Current track is always displayed in big or small",
                "Darkened current track background for contrast",
                "Better background tasks for Live Activities",
                "Usage of current APIs rather than deprecated ones",
                "Prompts have been simplified",
                "Xcode project organization",
                "Fix: Tapping a search result now plays the right track",
                "Fix: Labels are now always white whatever color scheme in use",
                "Fix: Background tasks are now correctly scheduled and ran",
                "Fix: Tapping a Cider instance will not crash when the queue is at its end"
            ], removals: [
                "Queue track index used for developers",
                "The \"Album Art Size\" setting, defaulted to large"
            ])
        return temp
            .setNotes(headerNote: "Cider Remote 3.0.0 releases along with Cider 3.0.0, this Remote update greatly improves the UI.")
    }
}
