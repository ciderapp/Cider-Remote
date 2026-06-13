// Made by Lumaa

import AVKit
import UIKit
import SwiftUI

struct UninteractableVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func updateUIViewController(_ uiViewController: UninteractableAVVideoPlayer, context: Context) {}

    func makeUIViewController(context: Context) -> UninteractableAVVideoPlayer {
        let customPlayerVC = UninteractableAVVideoPlayer()
        customPlayerVC.player = player // Set the AVPlayer
        customPlayerVC.showsPlaybackControls = false
        customPlayerVC.showsTimecodes = false
        return customPlayerVC
    }
}

class UninteractableAVVideoPlayer: AVPlayerViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.showsPlaybackControls = false
        self.showsTimecodes = false
    }
}
