// Made by Lumaa

import SwiftUI

struct ConnectionGuideView: View {
    @Environment(\.dismiss) var dismiss: DismissAction

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Prerequisites:")
                        .font(.title2.bold())
                    BulletedList(items: [
                        "Cider 2.5.3+ is installed (... > Updates)",
                        "Cider installed and running on your computer (Windows, macOS, or Linux)",
                        "Your Device and Cider on the same local network (if using LAN)",
                        "Cider's RPC & WebSocket server enabled (Settings > Connectivity)"
                    ])
                    
                    Text("Connection Steps:")
                        .font(.title2.bold())
                    VStack(alignment: .leading, spacing: 15) {
                        GuideStep(number: 1, text: "Launch the Cider Remote app on your iPhone, and tap the plus icon, in the top right corner.")
						GuideStep(number: 2, text: "On Cider on your computer, a consent dialog should have appeared. Allow Cider Remote with all the selected scopes.")
						GuideStep(number: 3, text: "If a QR code scanner appeared, on Cider on your computer, visit 'Help > Connect a Remote app' and create a device.")
                        GuideStep(number: 4, text: "Give a name to your scanned device, make it simple to understand for clarity.")
                        GuideStep(number: 5, text: "Your iPhone should now be paired with Cider.")
                    }
                    
                    Text("Troubleshooting:")
                        .font(.title2.bold())
                    Text("If you can't connect:")
						.font(.callout)
                    BulletedList(items: [
                        "Ensure both devices are on the same network",
                        "Check if Cider's RPC server is running (port 10767)",
                        "Restart both Cider and Cider Remote",
                        "Check firewall settings (see below)"
                    ])
                    
                    Text("Firewall Settings:")
                        .font(.title2.bold())
                    BulletedList(items: [
                        "Windows: Allow Cider through Windows Defender Firewall (Inbound Port 10767)",
                        "macOS: Add Cider to allowed apps in Security & Privacy > Firewall",
                        "Linux: Use your distribution's firewall tool to allow port 10767"
                    ])
                    
                    Text("For QR code scanning issues:")
                        .font(.title2.bold())
                    BulletedList(items: [
                        "Check if Remote has access to your camera",
                        "Ensure the QR code is clearly visible and well-lit",
                        "Try adjusting the distance between your phone and the screen"
                    ])
                    
                    Text("For further assistance, please visit our [Discord server](https://discord.gg/applemusic) or [GitHub issues](https://github.com/ciderapp/Cider-Remote/issues) page.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Connection Guide")
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
}
