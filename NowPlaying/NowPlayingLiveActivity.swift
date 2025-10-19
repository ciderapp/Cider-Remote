// Made by Lumaa

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct NowPlayingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingAttributes.self) { context in
            expandView(using: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center, priority: 2.0) {
                    expandView(using: context, dynamicIsland: true)
                }

                DynamicIslandExpandedRegion(.leading) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 65, height: 65, alignment: .center)
                        .clipShape(RoundedRectangle(cornerRadius: 3.0))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    playBtn(using: context)
                        .frame(height: 65, alignment: .center)
                }
            } compactLeading: {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
            } compactTrailing: {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(Color.white)
            } minimal: {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
            }
            .keylineTint(Color.pink)
        }
    }

    @ViewBuilder
    private func expandView(using context: ActivityViewContext<NowPlayingAttributes>, dynamicIsland: Bool = false) -> some View {
        HStack {
            if !dynamicIsland {
                ZStack {
                    Image(uiImage: UIImage.logo) // TEMPORARY SOLUTION
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40, alignment: .center)
                        .clipShape(RoundedRectangle(cornerRadius: 3.0))
                }
            }

            VStack(alignment: .leading) {
                Text(context.state.trackInfo.title)
                    .font(.body.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color.white)

                Text(context.state.trackInfo.artist)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color.gray)
            }
            .padding(.horizontal, dynamicIsland ? 0 : nil)
            .frame(maxWidth: .infinity, alignment: .leading)

            if !dynamicIsland {
                playBtn(using: context)
            }
        }
        .padding(.horizontal, dynamicIsland ? 0 : nil)
        .padding(.vertical, dynamicIsland ? 0 : 7.5)
    }

    @ViewBuilder
    private func playBtn(using context: ActivityViewContext<NowPlayingLiveActivity.NowPlayingAttributes>) -> some View {
        Button(intent: TogglePlayButtonIntent(device: .init(from: context.attributes.device))) {
            Image(systemName: "playpause.fill")
                .font(.title)
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
    }

    struct NowPlayingAttributes: ActivityAttributes {
        let device: Device

        public struct ContentState: Codable, Hashable {
            public func hash(into hasher: inout Hasher) {
                hasher.combine(trackInfo.id)
            }

            var trackInfo: Track
        }
    }
}
