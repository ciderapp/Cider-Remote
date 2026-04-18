// Made by Lumaa

import SwiftUI

struct GuideStep: View {
    let number: Int
    let text: String
    
    var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 15) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
				.background(Circle().fill(Color.cider))

            Text(text)
				.font(.callout)
        }
    }
}

struct BulletedList: View {
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Text("•")
                    Text(item)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}

extension View {
    /// Use this modifier on a SwiftUI `List` to optimize it for Cider's user interface
    @ViewBuilder
    func ciderOptimized(insets: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .scrollIndicators(.automatic)
            .scrollDismissesKeyboard(.interactively)
            .listStyle(.inset)
            .listSectionSeparator(.hidden)
    }

    /// Use this modifier on any views **inside of a SwiftUI `List`** to optimize it for Cider's user interface
    @ViewBuilder
    func ciderRowOptimized(insets: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) -> some View {
        self
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowInsets(insets)
            .listRowSeparator(.hidden)
    }
}
