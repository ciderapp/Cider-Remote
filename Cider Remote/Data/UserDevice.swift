// Made by Lumaa

import UIKit

/// The device in-use by the user to run Cider Remote
class UserDevice: ObservableObject {
    static let shared: UserDevice = .init()

    var orientation: UIDeviceOrientation {
        UIDevice.current.orientation
    }

    private var prevOrientation: HorizontalOrientation = .portrait
    private var _horizontalOrientation: HorizontalOrientation = .portrait

    var horizontalOrientation: HorizontalOrientation {
        get {
            prevOrientation = _horizontalOrientation
            switch self.orientation {
                case .unknown, .portrait:
                    _horizontalOrientation = .portrait
                    return .portrait
                case .portraitUpsideDown:
                    _horizontalOrientation = .portraitDown
                    return .portraitDown
                case .landscapeLeft:
                    _horizontalOrientation = .landscapeLeft
                    return .landscapeLeft
                case .landscapeRight:
                    _horizontalOrientation = .landscapeRight
                    return .landscapeRight
                case .faceUp, .faceDown:
                    _horizontalOrientation = self.prevOrientation
                    return self.prevOrientation
                @unknown default:
                    _horizontalOrientation = self.prevOrientation
                    return self.prevOrientation
            }
        }
    }

    var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var isBeta: Bool {
        if #available(iOS 26.0, *) {
            return true
        } else {
            return false
        }
    }

    init() {}

    enum HorizontalOrientation {
        case portrait
        case portraitDown
        case landscapeLeft
        case landscapeRight

        func isPortrait() -> Bool {
            return self == .portrait || self == .portraitDown
        }

        func isLandscape() -> Bool {
            return self == .landscapeLeft || self == .landscapeRight
        }
    }
}
