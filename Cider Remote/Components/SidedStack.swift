// Made by Lumaa

import SwiftUI

public struct SidedStack<LeftContent : View, RightContent: View>: View {
    let side: Self.Side
    let left: LeftContent
    let right: RightContent

    init(side: Side = .left, @ViewBuilder left: () -> LeftContent, @ViewBuilder right: () -> RightContent) {
        self.side = side
        self.left = left()
        self.right = right()
    }

    @ViewBuilder
    public var body: some View {
        HStack {
            l.frame(maxWidth: .infinity, maxHeight: .infinity)

            r.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var l: some View {
        if side == .left {
            left
        } else {
            right
        }
    }

    @ViewBuilder
    private var r: some View {
        if side == .left {
            right
        } else {
            left
        }
    }

    public enum Side {
        case left
        case right
    }
}
