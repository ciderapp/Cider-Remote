// Made by Lumaa

import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL: OpenURLAction
    @Environment(\.dismiss) private var dismiss: DismissAction

    // advanced
    @AppStorage("alwaysOn") private var alwaysOn: Bool = false
    @AppStorage("alertLiveActivity") private var alertLiveActivity: Bool = false

    // devices
    @AppStorage("deviceDetails") private var deviceDetails: Bool = false
    @AppStorage("refreshInterval") private var refreshInterval: Double = 10.0

	// other
	@State private var onboardingScreen: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Feedback")) {
                    Button {
                        if let url = URL(string: "https://github.com/ciderapp/Cider-Remote/issues/new") {
                            openURL(url)
                        }
                    } label: {
                        Label("Report a Bug", systemImage: "ladybug.fill")
                    }

                    Button {
                        if let url = URL(string: "https://apps.apple.com/app/id6670149407?action=write-review") {
                            openURL(url)
                        }
                    } label: {
                        Label("Review Cider Remote", systemImage: "star.fill")
                    }
                }

                Section(header: Text("Advanced")) {
                    Toggle("Always-on Immersive", isOn: $alwaysOn)

                    Toggle(isOn: $alertLiveActivity) {
                        HStack(spacing: 8.0) {
                            unstablePill

                            Text("Playback Notification")
                        }
                    }
                }

                Section(header: Text("Devices")) {
                    Toggle("Device Information", isOn: $deviceDetails)

                    VStack(alignment: .leading) {
                        HStack(alignment: .center) {
                            Text("Refresh Interval")
                                .foregroundStyle(Color(uiColor: UIColor.label))
                            Spacer()
                            Text("\(Int(refreshInterval)) seconds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $refreshInterval, in: 5...60, step: 5) {
                            Text("Refresh Interval: \(Int(refreshInterval)) seconds")
                        }
                    }
                }

				Section {
					Button {
						self.onboardingScreen = true
					} label: {
						Text("Show Onboarding")
					}
				}
				.fullScreenCover(isPresented: $onboardingScreen) { OnboardingView() }

                Section(header: Text("About")) {
					LabeledContent {
						Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
					} label: {
						Text("Version")
					}

                    NavigationLink {
                        ChangelogsView()
                    } label: {
                        Text("Changelogs")
                    }
                }

                Section {
                    NavigationLink {
                        ContributorsView()
                    } label: {
                        Text("© Cider Collective 2024-2026")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let url = URL(string: "https://apple.co/4k6ISFv") {
                        ShareLink("Share Cider Remote", item: url)
                    }
                }
            }
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private var unstablePill: some View {
        Text("Unstable")
            .font(.caption)
            .padding(.horizontal, 6.0)
            .padding(.vertical, 3.0)
            .background(Color.blue)
            .foregroundStyle(Color.white)
            .clipShape(Capsule())
    }
}
