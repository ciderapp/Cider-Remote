// Made by Lumaa

import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL: OpenURLAction

    @Binding var showingSettings: Bool
    @EnvironmentObject var colorScheme: ColorSchemeManager
    @AppStorage("buttonSize") private var buttonSize: ElementSize = .medium
    @AppStorage("albumArtSize") private var albumArtSize: ElementSize = .large
    @AppStorage("refreshInterval") private var refreshInterval: Double = 10.0
    @AppStorage("useAdaptiveColors") private var useAdaptiveColors: Bool = true
    @AppStorage("alertLiveActivity") private var alertLiveActivity: Bool = true
    @EnvironmentObject var deviceListViewModel: DeviceListViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("TestFlight")) {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.orange)
                        Text("Thank you for testing!")
                            .font(.headline)
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("Feedback")) {
                    Button(action: reportBug) {
                        Label("Report a Bug", systemImage: "ladybug.fill")
                    }
                }

                Section(header: Text("Appearance")) {
                    Toggle("Use Dynamic Colors", isOn: $useAdaptiveColors)

                    Picker(selection: $buttonSize) {
                        ForEach(ElementSize.allCases) { size in
                            Text(size.rawValue.capitalized)
                                .id(size)
                        }
                    } label: {
                        Label("Button Size", systemImage: "button.horizontal.top.press.fill")
                    }
                    .foregroundStyle(Color(uiColor: UIColor.label))
                    .pickerStyle(.menu)

                    Picker(selection: $albumArtSize) {
                        ForEach(ElementSize.allCases) { size in
                            Text(size.rawValue.capitalized)
                                .id(size)
                        }
                    } label: {
                        Label("Album Art Size", systemImage: "photo.fill")
                    }
                    .foregroundStyle(Color(uiColor: UIColor.label))
                    .pickerStyle(.menu)
                }

                Section(header: Text("Advanced")) {
                    Toggle("Playback Notification", isOn: $alertLiveActivity)
                }

                Section(header: Text("Devices")) {
                    Button("Reset All Devices", role: .destructive, action: resetAllDevices)

                    VStack(alignment: .leading) {
                        HStack(alignment: .center) {
                            Text("Refresh Interval")
                            Spacer()
                            Text("\(Int(refreshInterval)) seconds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if #available(iOS 17.0, *) {
                            Slider(value: $refreshInterval, in: 5...60, step: 5) {
                                Text("Refresh Interval: \(Int(refreshInterval)) seconds")
                            }
                            .onChange(of: refreshInterval) { _, _ in
                                let impact = UIImpactFeedbackGenerator(style: .light) //MARK: API is deprecated
                                impact.impactOccurred()
                            }
                        } else {
                            Slider(value: $refreshInterval, in: 5...60, step: 5) {
                                Text("Refresh Interval: \(Int(refreshInterval)) seconds")
                            }
                        }
                    }
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Text("© Cider Collective 2024")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Text("Made with ❤️ by cryptofyre")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    NavigationLink {
                        ContributorsView()
                    } label: {
                        Text("With the help of contributors")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func reportBug() {
        if let url = URL(string: "https://github.com/ciderapp/Cider-Remote/issues/new") {
            openURL(url)
        }
    }

    private func resetAllDevices() {
        //TODO
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showingSettings: .constant(true))
            .environmentObject(ColorSchemeManager())
            .environmentObject(DeviceListViewModel())
    }
}

enum ElementSize: String, Hashable, CaseIterable, Identifiable {
    case small, medium, large
    var id: Self { self }

    var dimension: CGFloat {
        switch self {
            case .small: return 40
            case .medium: return 60  // This was 50 before, now it's 60 to match the original size
            case .large: return 80   // Increased to take up more space
        }
    }

    var fontSize: CGFloat {
        switch self {
            case .small: return 16
            case .medium: return 24  // Increased from 20 to 24
            case .large: return 32   // Increased from 24 to 32
        }
    }

    var padding: CGFloat {
        switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 20   // Increased from 16 to 20
        }
    }
}
