// Made by Lumaa

import SwiftUI

/// A full-screen Cider prompt
struct Prompt {
    private let symbol: String
    private let title: String
    @ViewBuilder private let content: AnyView
    private let actionLabel: String
    private let action: () -> Void

    private var showCancel: Bool = true

    init(symbol: String, title: String, view: AnyView, actionLabel: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.title = title
        self.content = view
        self.actionLabel = actionLabel
        self.action = action
    }

    mutating func cancellable(_ boolean: Bool = true) -> Prompt {
        var temp: Prompt = self
        temp.showCancel = boolean
        return temp
    }

    @ViewBuilder
    func view(dismiss: @escaping () -> Void) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: self.symbol)
                    .font(.system(size: 50))
                    .foregroundStyle(Color.cider)

                Text(self.title)
                    .font(.title2.bold())
            }
            .padding(.vertical, UserDevice.shared.isBeta ? 16 : 0)

            content

            if #available(iOS 26.0, *) {
                Spacer()

                VStack(spacing: 16) {
                    Button {
                        self.action()
                        dismiss()
                    } label: {
                        Text(self.actionLabel)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .glassEffect(.regular.interactive().tint(Color.cider))
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .foregroundStyle(Color(uiColor: UIColor.label))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .glassEffect(.regular.interactive())
                    }
                }
            } else {
                HStack(spacing: 16) {
                    if showCancel {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    Button(self.actionLabel) {
                        self.action()
                        dismiss()
                    }
                }
            }
        }
        .frame(width: UserDevice.shared.isBeta ? nil : 320)
        .padding(.horizontal, UserDevice.shared.isBeta ? nil : 0)
    }
}

class AppPrompt: ObservableObject {
    static let shared: AppPrompt = .init()

    @Published public var showingPrompt: Prompts?

    init() {
        self.showingPrompt = nil
    }
}

enum Prompts: String, Identifiable {
    case newDevice
    case accesCamera
    case oldDevice
    case update

    var id: String {
        self.rawValue
    }
}
