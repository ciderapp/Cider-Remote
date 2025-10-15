// Made by Lumaa

import SwiftUI
import AVFoundation

struct AddDeviceView: View {
    @Binding var isShowingScanner: Bool
    @Binding var scannedCode: String?

    @State private var jsonTxt: String = ""

    var fetchAction: (String) -> Void

    var body: some View {
        Button {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            var isAuthorized = status == .authorized

            if isAuthorized {
                isShowingScanner = true
            } else {
                if status == .notDetermined {
                    Task {
                        isAuthorized = await AVCaptureDevice.requestAccess(for: .video)

                        if isAuthorized {
                            isShowingScanner = true
                        }
                    }
                } else {
                    AppPrompt.shared.showingPrompt = .accesCamera
                }
            }
        } label: {
            Label("Add New Cider Device", systemImage: "plus.circle")
                .foregroundStyle(Color.cider)
        }
        .sheet(isPresented: $isShowingScanner) {
#if targetEnvironment(simulator)
            VStack {
                Text(String("Enter the JSON below:"))
                TextField(String("{\"address\":\"123.456.7.89\",\"token\":\"abcdefghijklmnopqrstuvwx\",\"method\":\"lan\",\"initialData\":{\"version\":\"2.0.3\",\"platform\":\"genten\",\"os\":\"darwin\"}}"), text: $jsonTxt)
                    .padding()
                    .textFieldStyle(.roundedBorder)

                Button {
                    fetchAction(jsonTxt)
                    isShowingScanner = false
                } label: {
                    Text(String("Fetch device"))
                }
                .buttonStyle(.borderedProminent)
            }
#else
            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                QRScannerView(scannedCode: $scannedCode)
                    .overlay(alignment: .top) {
                        if #available(iOS 26.0, *) {
                            Text("Scan the Remote QR code")
                                .font(.caption)
                                .padding(.horizontal)
                                .padding(.vertical, 7.5)
                                .glassEffect()
                                .padding(.top, 22.5)
                        } else {
                            Text("Scan the Remote QR code")
                                .font(.caption)
                                .padding(.horizontal)
                                .padding(.vertical, 7.5)
                                .background(Material.thin)
                                .clipShape(.rect(cornerRadius: 15.5))
                                .padding(.top, 22.5)
                        }
                    }
            } else {
                Text("Cider Remote cannot access the camera")
                    .font(.title2.bold())
                    .padding(.horizontal)
            }
#endif
        }
        .onChange(of: scannedCode) { _, newValue in
            if let code = newValue {
                fetchAction(code)
                isShowingScanner = false
            }
        }
    }
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: QRScannerViewControllerDelegate?

    private let supportedCodeTypes: [AVMetadataObject.ObjectType] = [.qr]
    private var highlightView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCaptureSession()
        setupPreviewLayer()
        setupHighlightView()
        setupCloseButton()
        startRunning()
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = supportedCodeTypes
        } else {
            failed()
            return
        }
    }

    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    private func setupHighlightView() {
        highlightView = UIView()
        highlightView?.layer.borderColor = UIColor.green.cgColor
        highlightView?.layer.borderWidth = 3
        highlightView?.backgroundColor = UIColor.clear
        if let highlightView = highlightView {
            view.addSubview(highlightView)
            view.bringSubviewToFront(highlightView)
        }
    }

    private func setupCloseButton() {
        let closeButtonSize: CGFloat = 44
        let padding: CGFloat = 16

        // Create a backdrop view
        var backdropView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        if #available(iOS 26.0, *) {
            backdropView = UIVisualEffectView(effect: UIGlassEffect())
        }

        backdropView.layer.cornerRadius = closeButtonSize / 2
        backdropView.clipsToBounds = true
        view.addSubview(backdropView)

        // Create the close button
        let closeButton = UIButton(type: .custom)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

        // Add the close button to the backdrop
        backdropView.contentView.addSubview(closeButton)

        // Setup constraints
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: padding),
            backdropView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -padding),
            backdropView.widthAnchor.constraint(equalToConstant: closeButtonSize),
            backdropView.heightAnchor.constraint(equalToConstant: closeButtonSize),

            closeButton.centerXAnchor.constraint(equalTo: backdropView.centerXAnchor),
            closeButton.centerYAnchor.constraint(equalTo: backdropView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: closeButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: closeButtonSize)
        ])
    }

    @objc private func closeButtonTapped() {
        delegate?.qrScanningDidStop()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    private func failed() {
        delegate?.qrScanningDidFail()
        captureSession = nil
    }

    private func startRunning() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject {
            guard supportedCodeTypes.contains(metadataObject.type) else { return }

            if metadataObject.type == .qr {
                if let barCodeObject = previewLayer.transformedMetadataObject(for: metadataObject) {
                    highlightView?.frame = barCodeObject.bounds
                    highlightView?.isHidden = false
                }
                delegate?.qrScanningSucceededWithCode(metadataObject.stringValue)
            }
        } else {
            highlightView?.isHidden = true
        }
    }
}

protocol QRScannerViewControllerDelegate: AnyObject {
    func qrScanningDidFail()
    func qrScanningSucceededWithCode(_ str: String?)
    func qrScanningDidStop()
}

struct QRScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QRScannerViewControllerDelegate {
        var parent: QRScannerView

        init(_ parent: QRScannerView) {
            self.parent = parent
        }

        func qrScanningDidFail() {
            print("Scanning Failed. Please try again.")
        }

        func qrScanningSucceededWithCode(_ str: String?) {
            if let code = str {
                parent.scannedCode = code
                parent.presentationMode.wrappedValue.dismiss()
            }
        }

        func qrScanningDidStop() {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
