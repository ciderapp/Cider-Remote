// Made by Lumaa

import SwiftUI

struct LyricButton: ButtonStyle {
    let lyric: LyricLine

    init(_ lyric: LyricLine) {
        self.lyric = lyric
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.gray.opacity(0.3) : Color.clear)
            .scaleEffect(configuration.isPressed ? 1.05 : 1.0, anchor: lyric.altVoice ? .trailing : .leading)
    }
}
