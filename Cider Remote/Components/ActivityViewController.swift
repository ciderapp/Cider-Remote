// Made by Lumaa

import SwiftUI
import UIKit

struct ActivityViewController: UIViewControllerRepresentable {
    let item: ShareItem

    func makeUIViewController(context: Context) -> UIActivityViewController {
        switch self.item {
            case let .track(track):
                if let url: URL = URL(string: "https://music.apple.com/us/song/\(track.catalogId)") {
                    return UIActivityViewController(activityItems: [url], applicationActivities: nil)
                } else {
                    let ui: UIImage = track.getArtworkLocally()
                    return UIActivityViewController(activityItems: [ui], applicationActivities: nil)
                }

            case let .image(images):
                return UIActivityViewController(activityItems: images, applicationActivities: nil)
        }
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

enum ShareItem {
    case track(track: Track)
    case image(images: [UIImage])
}
