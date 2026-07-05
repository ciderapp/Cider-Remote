// Made by Lumaa

import SwiftUI

struct PlayerControlsView: View {
    @Environment(\.colorScheme) var systemColorScheme

    @EnvironmentObject var colorScheme: ColorSchemeManager

    @ObservedObject var viewModel: MusicPlayerViewModel

    @State private var isDragging: Bool = false

    let buttonSize: ElementSize
    let geometry: GeometryProxy

    var body: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let safeZone: CGFloat = UserDevice.shared.horizontalOrientation == .portrait ? geometry.size.width * 0.85 : geometry.size.width * 0.45

        VStack(spacing: 12) {  // Increased spacing between main elements
            VStack(spacing: 0) {  // Increased spacing between slider and timestamps
                CustomSlider(value: $viewModel.currentTime, // playback
                             bounds: 0...viewModel.duration,
                             isDragging: $isDragging,
                             onEditingChanged: { editing in
                    if !editing {
                        Task {
                            await viewModel.seekToTime()
                        }
                    }
                })
                .tint(Color.white)

                // Timestamps
                HStack {
                    Text(formatTime(viewModel.currentTime))
                    Spacer()
                    Text(formatTime(viewModel.duration))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(width: safeZone)

            HStack(spacing: 0) {
                Button(action: {
                    Task {
                        await viewModel.toggleLike()
                    }
                }) {
                    Image(systemName: viewModel.isLiked ? "star.fill" : "star")
                        .foregroundStyle(viewModel.isLiked ? Color(hex: "#fa2f48") : Color.white.opacity(0.6))
                        .frame(width: buttonSize.dimension, height: buttonSize.dimension)
                }
                .buttonStyle(SpringyButtonStyle())

                Spacer()

                HStack(alignment: .center, spacing: calculateButtonSpacing()) {
                    Button(action: {
                        Task {
                            await viewModel.previousTrack()
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: buttonSize.fontSize * 1.2))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(width: buttonSize.dimension * 1.2, height: buttonSize.dimension * 1.2)
                    }
                    .buttonStyle(SpringyButtonStyle())

                    Button(action: {
                        Task {
                            await viewModel.togglePlayPause()
                        }
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: buttonSize.fontSize * 2.5))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(width: buttonSize.dimension * 1.8, height: buttonSize.dimension * 1.8)
                    }
                    .buttonStyle(SpringyButtonStyle())

                    Button(action: {
                        Task {
                            await viewModel.nextTrack()
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: buttonSize.fontSize * 1.2))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(width: buttonSize.dimension * 1.2, height: buttonSize.dimension * 1.2)
                    }
                    .buttonStyle(SpringyButtonStyle())
                }

                Spacer()

                AdditionalControls(viewModel: viewModel, lightDarkColor: lightDarkColor, buttonSize: buttonSize)
            }
            .font(.system(size: isIPad ? 22 : 20))  // Slightly reduced font size for iPad
        }
        .padding(.top, isIPad ? 20 : 0)  // Add padding at the top
    }

    private func calculateButtonSpacing() -> CGFloat {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let totalWidth = min(geometry.size.width * (isIPad ? 0.5 : 0.6), 300)
        let buttonWidths = buttonSize.dimension * 1.2 * 2 + buttonSize.dimension * 1.8
        let remainingSpace = totalWidth - buttonWidths

        return remainingSpace / 4 // Divide by 4 to create 3 equal spaces between buttons
    }

    private var lightDarkColor: Color {
        systemColorScheme == .dark ? .white : .black
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct AdditionalControls: View {
    let viewModel: MusicPlayerViewModel
    let lightDarkColor: Color
    let buttonSize: ElementSize

    @State private var isSharing: Bool = false

    init(viewModel: MusicPlayerViewModel, lightDarkColor: Color, buttonSize: ElementSize) {
        self.viewModel = viewModel
        self.lightDarkColor = lightDarkColor
        self.buttonSize = buttonSize
    }

    var body: some View {
        Menu {
            Button {
                Task {
                    await viewModel.toggleAddToLibrary()
                }
            } label: {
                Label(viewModel.isInLibrary ? "Remove from Library" : "Add to Library", systemImage: viewModel.isInLibrary ? "minus" : "plus")
            }

            Button {
                Task {
                    await viewModel.toggleLike()
                }
            } label: {
                Label(viewModel.isLiked ? "Unfavorite" : "Favorite", systemImage: viewModel.isLiked ? "star.fill" : "star")
            }

            Button {
                self.isSharing.toggle()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(Color.white.opacity(0.6))
                .padding(8)
                .frame(width: buttonSize.dimension * (UIDevice.current.userInterfaceIdiom == .pad ? 1.1 : 1.0), height: buttonSize.dimension * (UIDevice.current.userInterfaceIdiom == .pad ? 1.1 : 1.0))
        }
        .buttonStyle(SpringyButtonStyle())
        .tint(Color.white)
        .sheet(isPresented: $isSharing) {
            if let currentTrack = viewModel.currentTrack {
                ActivityViewController(item: .track(track: currentTrack))
                    .presentationDetents([.medium, .large])
            } else {
                Text("Nothing to share")
                    .font(.title2)
                    .foregroundStyle(Color.secondary)
                    .onAppear {
                        isSharing = false
                    }
            }
        }
    }
}

struct VolumeControlView: View {
    @ObservedObject var viewModel: MusicPlayerViewModel
    @State private var isDragging = false

    let geometry: GeometryProxy

    var body: some View {
        let safeZone: CGFloat = UserDevice.shared.horizontalOrientation == .portrait ? geometry.size.width * 0.85 : geometry.size.width * 0.45
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.secondary)
            CustomSlider(value: $viewModel.volume,
                         bounds: 0...1,
                         isDragging: $isDragging,
                         onEditingChanged: { editing in
                if !editing {
                    Task {
                        viewModel.adjustVolume()
                    }
                }
            })
            .accentColor(.red)
            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.secondary)
        }
        .frame(width: safeZone, height: 30)  // Set a fixed height for the volume control
    }
}

struct AdditionalControlsView: View {
    @Environment(\.colorScheme) var colorScheme

    @Binding var showLyrics: Bool
    @Binding var showQueue: Bool

    let buttonSize: ElementSize
    let geometry: GeometryProxy

    var body: some View {
        HStack(spacing: 30) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showLyrics.toggle()
                }
            }) {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 40)

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showQueue.toggle()
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
    }
}
