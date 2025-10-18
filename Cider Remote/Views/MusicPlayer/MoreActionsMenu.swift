// Made by Lumaa

import SwiftUI

struct MoreActionsMenu: View {
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
