// Made by Lumaa

import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var viewModel: DeviceListViewModel

    @AppStorage("autoRefresh") private var autoRefresh: Bool = true

    @State private var scannedCode: String?
    @State private var isShowingScanner = false
    @State private var isShowingGuide = false
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header

            List {
                ForEach(viewModel.devices) { device in
                    if device.isActive {
                        NavigationLink(value: device) {
                            DeviceRowView(device: device)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteDevice(device: device)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } else {
                        if autoRefresh {
                            DeviceRowView(device: device)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        viewModel.deleteDevice(device: device)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        } else {
                            Button {
                                Task {
                                    await viewModel.refreshDevice(device)
                                }
                            } label: {
                                HStack {
                                    DeviceRowView(device: device)

                                    Spacer()

                                    Image(systemName: "chevron.forward")
                                        .foregroundStyle(Color(uiColor: UIColor.tertiaryLabel))
                                }
                            }
                            .tint(Color(uiColor: UIColor.label))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteDevice(device: device)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                AddDeviceView(isShowingScanner: $isShowingScanner, scannedCode: $scannedCode, viewModel: viewModel)

                Button(action: {
                    isShowingGuide = true
                }) {
                    Label("Connection Guide", systemImage: "questionmark.circle")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .task {
                await viewModel.refreshDevices()
            }
            .refreshable {
                await viewModel.refreshDevices()
            }
            Label("This software is in BETA.", systemImage: "hammer.circle.fill")
                .foregroundColor(.gray)
                .accessibility(label: Text("Beta software"))
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingSettings.toggle()
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .navigationDestination(for: Device.self) { device in
            LazyView(MusicPlayerView(device: device))
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $isShowingGuide) {
            ConnectionGuideView()
        }
        .onAppear {
            viewModel.startActivityChecking()
        }
        .onDisappear {
            viewModel.stopActivityChecking()
        }
    }

    var header: some View {
        VStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 60)

            Text("Cider Devices")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Material.ultraThick)
    }
}
