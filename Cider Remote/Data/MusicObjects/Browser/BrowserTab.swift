// Made by Lumaa

import SwiftUI

enum BrowserTab: String, CaseIterable, Identifiable {
//    case songs
    case albums
    case playlists

    var id: String {
        self.rawValue
    }

    var localized: String {
        switch self {
//            case .songs:
//                "Songs"
            case .albums:
                "Albums"
            case .playlists:
                "Playlists"
        }
    }

    var symbol: String {
        switch self {
//            case .songs:
//                "music.note"
            case .albums:
                "square.stack"
            case .playlists:
                "music.note.list"
        }
    }

    @ViewBuilder
    var view: some View {
        Label(self.localized, systemImage: self.symbol)
            .lineLimit(1)
            .multilineTextAlignment(.leading)
    }
}
