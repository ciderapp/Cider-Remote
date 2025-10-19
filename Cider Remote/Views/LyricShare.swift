// Made by Lumaa

import SwiftUI

struct LyricShare: View {
    @Environment(\.dismiss) private var dismiss: DismissAction

    @State var track: Track

    @State private var bg: [Color] = []
    @State private var albumCover: UIImage = .init()

    @State private var sharingImage: UIImage? = nil

    private static let width: CGFloat = 300.0

    let lyric: LyricLine
    let showToolbar: Bool

    init(track: Track, lyric: LyricLine, showToolbar: Bool = true) {
        self.track = track
        self.lyric = lyric
        self.showToolbar = showToolbar
    }

    var body: some View {
        NavigationStack {
            self.foreground()
                .toolbar {
                    if showToolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .cancel) {
                                self.dismiss()
                            }
                            .tint(Color.white)
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button {
                                self.imageify()
                            } label: {
                                Label("Share lyric", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
        }
        .task {
            await self.handleColors()
        }
        .sheet(item: $sharingImage) { image in
            ActivityViewController(item: .image(images: [image]))
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func foreground(scalePlate: Double = 1.0) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
                .ignoresSafeArea()

            if bg.count == 25 {
                AnimatedMeshGradientView(colors: $bg, amplify: 0.25)
                    .ignoresSafeArea()
                    .opacity(0.3)
            }

            self.songPlate
                .clipShape(RoundedRectangle(cornerRadius: 15.0, style: .continuous))
                .scaleEffect(scalePlate)
        }
    }

    @ViewBuilder
    private var songPlate: some View {
        VStack(spacing: 0) {
            Text(lyric.text)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .multilineTextAlignment(lyric.altVoice ? .trailing : .leading)
                .frame(width: Self.width, alignment: lyric.altVoice ? .trailing : .leading)
                .padding(15.0)
                .background(Color.black.opacity(0.25))

            HStack {
                Image(uiImage: self.albumCover)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)
                    .clipShape(RoundedRectangle(cornerRadius: 3.0))

                VStack(alignment: .leading) {
                    Text(self.track.title)
                        .foregroundStyle(Color.white)
                        .font(.callout.bold())
                        .lineLimit(1)

                    Text(self.track.artist)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)

                Text("Remote")
                    .font(.callout.bold())
                    .foregroundStyle(Color.white)
            }
            .frame(width: Self.width)
            .padding(15.0)
            .background(Color.black.opacity(0.55))
            .environment(\.colorScheme, ColorScheme.dark)
        }
    }

    private func imageify() {
        let portrait = self.foreground(scalePlate: 2.3)
            .aspectRatio(9 / 16, contentMode: .fit)
            .frame(width: 1080, height: 1920, alignment: .center)

        let image = ImageRenderer(content: portrait)
        self.sharingImage = image.uiImage
    }

    private func handleColors() async {
        if let artwork: UIImage = await self.loadArtwork() {
            self.albumCover = artwork
            let colors: [Color] = artwork.dominantColors(count: 25)
            self.bg = colors.shuffled()
        }
    }

    func loadArtwork() async -> UIImage? {
        let url: URL = URL(string: self.track.artwork)!

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                return image
            }
        } catch {
            print("Error loading image: \(error)")
        }
        return nil
    }
}
