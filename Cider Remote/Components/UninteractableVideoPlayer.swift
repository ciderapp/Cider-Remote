// Made by Lumaa

import AVKit
import UIKit
import SwiftUI

struct UninteractableVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false // Disable all user interactions

        // Create AVPlayerLayer
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect // Equivalent to .aspectRatio(contentMode: .fit)
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)

        // Ensure the layer resizes with the view
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 8 // Match .clipShape(RoundedRectangle(cornerRadius: 8))

        // Store the playerLayer in the coordinator for updates
        context.coordinator.playerLayer = playerLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the playerLayer frame when the view size changes
        if let playerLayer = context.coordinator.playerLayer {
            playerLayer.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}
