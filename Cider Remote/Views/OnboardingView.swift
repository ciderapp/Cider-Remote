// Made by Lumaa

import SwiftUI

struct OnboardingView: View {
	@Environment(\.colorScheme) private var originalScheme: ColorScheme

	@State private var appCover: Bool = false

	var body: some View {
		ZStack {
			Color.ciderBack
				.ignoresSafeArea()

			VStack(spacing: 10.0) {
				Image(.glassIcon)
					.resizable()
					.scaledToFit()
					.frame(width: 100, height: 100)
					.environment(\.colorScheme, self.originalScheme)
					.colorScheme(self.originalScheme)

				self.features
					.padding()

				Spacer()

				Button {
					self.appCover.toggle()
					UserDefaults.standard.set(true, forKey: "onboarded")
				} label: {
					Text("OK")
						.frame(maxWidth: .infinity, minHeight: 30.0, maxHeight: 30.0)
				}
				.padding(.horizontal, 30.0)
				.tint(Color.cider)
				.buttonStyle(.glassProminent)
				.buttonBorderShape(.capsule)
				.buttonSizing(.fitted)
			}
		}
		.environment(\.colorScheme, ColorScheme.dark)
		.colorScheme(ColorScheme.dark)
		.fullScreenCover(isPresented: $appCover) {
			ContentView()
				.environment(\.colorScheme, self.originalScheme)
				.colorScheme(self.originalScheme)
		}
	}

	var features: some View {
		ScrollView(.vertical, showsIndicators: false) {
			VStack(spacing: 20) {
				Text("Welcome to Cider Remote")
					.font(.title2.bold())
					.scrollTransition { content, phase in
						content
							.opacity(phase.isIdentity ? 1 : 0)
							.blur(radius: phase.isIdentity ? 0 : 5)
							.offset(y: phase.isIdentity ? 0 : -15)
					}

				ForEach(Self.Features.allCases, id: \.self) { f in
					self.feature(f.appFeature)
				}

			}
			.frame(maxWidth: .infinity)
		}
		.scrollClipDisabled()
	}

	@ViewBuilder
	private func feature(_ feature: Self.AppFeature) -> some View {
		HStack(alignment: .center) {
			Image(systemName: feature.systemImage)
				.resizable()
				.scaledToFit()
				.frame(width: 40, height: 40)

			VStack(alignment: .leading) {
				Text(feature.title)
					.bold()
					.lineLimit(1)
					.multilineTextAlignment(.leading)
				Text(feature.description)
					.font(.callout)
					.lineLimit(2)
					.multilineTextAlignment(.leading)
			}
			.padding(.leading)

			Spacer()
		}
		.padding(.leading, 20)
		.frame(maxWidth: .infinity)
		.padding(.vertical)
		.background(Color.gray.opacity(0.2))
		.clipShape(.capsule)
		.scrollTransition { content, phase in
			content
				.opacity(phase.isIdentity ? 1 : 0)
				.scaleEffect(x: phase.isIdentity ? 1 : 0.5, y: phase.isIdentity ? 1 : 0.75, anchor: .center)
				.blur(radius: phase.isIdentity ? 0 : 10)
				.offset(y: phase.isIdentity ? 0 : 10)
		}
	}

	private struct AppFeature {
		let title: LocalizedStringKey
		let description: LocalizedStringKey
		let systemImage: String

		init(_ title: LocalizedStringKey, description: LocalizedStringKey, systemImage: String) {
			self.title = title
			self.description = description
			self.systemImage = systemImage
		}
	}

	private enum Features: CaseIterable {
		case liveActivity
		case libraryBrowser
		case horizontalLayout
		case lyrics
		case controlCenter

		var appFeature: AppFeature {
			switch self {
				case .liveActivity:
					return .init("Live Activity", description: "The lock screen has it all, song info, background updates, play/pause...", systemImage: "clock.badge")
				case .libraryBrowser:
					return .init("Library Browser", description: "Browse your Apple Music library, play songs, count down future albums", systemImage: "book")
				case .horizontalLayout:
					return .init("Horizontal Layout", description: "Landscape or portrait, Remote will always have the perfect layout", systemImage: "iphone.landscape")
				case .lyrics:
					return .init("Sing along!", description: "Sing your favorite songs' lyrics at all times, and share them online!", systemImage: "music.microphone")
				case .controlCenter:
					return .init("Control Center actions", description: "Not in Remote? Control Cider through the Control Center", systemImage: "switch.2")
			}
		}
	}
}
