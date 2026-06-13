// Made by Lumaa

import UIKit

extension UIFont {
    func getSize() -> CGFloat {
        return self.pointSize
    }
}

extension CGFloat {
    static func getFontSize(_ uiFont: UIFont) -> Self {
        return uiFont.getSize()
    }
}
