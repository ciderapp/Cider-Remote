// Made by Lumaa

import Foundation

enum LibraryElement: Identifiable, Hashable {
    case tab(_ tab: BrowserTab)
    case album(_ album: LibraryAlbum)
    case playlist(_ playlist: LibraryPlaylist)

    var id: String {
        switch self {
            case .tab(let t):
                return "tab-\(t.id)"
            case .album(let a):
                return "album-\(a.id)"
            case .playlist(let p):
                return "playlist-\(p.id)"
        }
    }
}
