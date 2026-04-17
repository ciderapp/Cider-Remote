// Made by Lumaa

import SwiftUI
import AVFoundation

struct AddDeviceView: View {
    @Binding var isShowingScanner: Bool
    @Binding var scannedCode: String?

    @State private var jsonTxt: String = ""

	@State private var authenticating: Bool = false
	@State private var hasError: Bool = false
	@State private var errorItem: AuthRequest.Error? = nil

	var fetchAction: (ConnectionInfo) -> Void

    var body: some View {
        Button {
			Task {
				do {
					self.authenticating = true
					let authRes: Any = try await self.sendAuth()
					if authRes is AuthRequest.Error {
						self.authenticating = false
						self.errorItem = (authRes as! AuthRequest.Error)
						self.hasError = true
					} else if let res = authRes as? [String: Any] {
						guard let data: Data = try? JSONSerialization.data(withJSONObject: res), let authAllow: AuthRequest.Result = try? JSONDecoder().decode(AuthRequest.Result.self, from: data) else { throw NetworkError.decodingError }
						self.authenticating = false

						let newInfo: ConnectionInfo = try await authAllow.getConnection()
						return self.fetchAction(newInfo)
					} else {
						throw NetworkError.decodingError
					}
				} catch {
					print(error)

					// if we're here, it probably means that `tryAuth` didn't return an auth error, but threw an http error
					self.authenticating = false
					await self.useScanner()
				}
			}
        } label: {
			if self.authenticating {
				ProgressView()
			} else {
				Label("Add New Cider Device", systemImage: "plus")
					.foregroundStyle(Color.cider)
			}
        }
		.disabled(self.authenticating)
		.alert("Integration Failed", isPresented: $hasError) {
			Button(role: .confirm) {
				Task {
					await self.useScanner()
				}
			} label: {
				Text("Scan a QR code")
			}

			Button(role: .cancel) {}
		} message: {
			if let errorItem {
				Text("Error \(errorItem.code): \(errorItem.description)")
			} else {
				Text("Unknown Error")
			}
		}
        .sheet(isPresented: $isShowingScanner) {
#if targetEnvironment(simulator)
            VStack {
                Text(String("Enter the JSON below:"))
                TextField(String("{\"address\":\"123.456.7.89\",\"token\":\"abcdefghijklmnopqrstuvwx\",\"method\":\"lan\",\"initialData\":{\"version\":\"400\",\"platform\":\"genten\",\"os\":\"darwin\"}}"), text: $jsonTxt)
                    .padding()
                    .textFieldStyle(.roundedBorder)

                Button {
                    self.jsonTxt = "{\"address\":\"\",\"token\":\"\",\"method\":\"lan\",\"initialData\":{\"version\":\"400\",\"platform\":\"genten\",\"os\":\"darwin\"}}"
                } label: {
                    Text(String("Sample Data (add token & address)"))
                }
                .buttonStyle(.bordered)

                Button {
					if let fetched = self.fetchDevices(from: jsonTxt) {
						fetchAction(fetched)
						isShowingScanner = false
					}
                } label: {
                    Text(String("Fetch device"))
                }
                .buttonStyle(.borderedProminent)
            }
#else
            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                QRScannerView(scannedCode: $scannedCode)
            } else {
                Text("Cider Remote cannot access the camera")
                    .font(.title2.bold())
                    .padding(.horizontal)
            }
#endif
        }
        .onChange(of: scannedCode) { _, newValue in
			if let code = newValue, let fetched = self.fetchDevices(from: code) {
				fetchAction(fetched)
                isShowingScanner = false
            }
        }
    }

	private func useScanner() async {
		let status = AVCaptureDevice.authorizationStatus(for: .video)
		var isAuthorized = status == .authorized

		if isAuthorized {
			isShowingScanner = true
		} else {
			if status == .notDetermined {
				isAuthorized = await AVCaptureDevice.requestAccess(for: .video)

				if isAuthorized {
					isShowingScanner = true
				}
			} else {
				AppPrompt.shared.showingPrompt = .accesCamera
			}
		}
	}

	private func sendAuth(authRequest: AuthRequest = .remoteRequest) async throws -> Any {
		guard let url = URL(string: "http://localhost:\(Int.defaultPort)/api/v2/auth/request") else {
			throw NetworkError.invalidURL
		}

		print("Sending request to: \(url.absoluteString)")

		var request = URLRequest(url: url)
		request.httpMethod = "POST"

		if let data = try? JSONEncoder().encode(authRequest), let body = try? JSONSerialization.jsonObject(with: data) {
			request.httpBody = try? JSONSerialization.data(withJSONObject: body)
			request.addValue("application/json", forHTTPHeaderField: "Content-Type")
			print("Request body: \(body)")
		}

		let (data, response) = try await URLSession.shared.data(for: request)
		print("Response raw: \(String(data: data, encoding: .utf8) ?? "[No data]")")

		guard let httpResponse = response as? HTTPURLResponse else {
			throw NetworkError.invalidResponse
		}

		print("Response status code: \(httpResponse.statusCode)")

		guard (200...299).contains(httpResponse.statusCode) else {
			if let authError: AuthRequest.Error = AuthRequest.Error.matchCode(with: httpResponse.statusCode) {
				return authError
			} else {
				throw NetworkError.serverError("Server responded with status code \(httpResponse.statusCode)")
			}
		}

		let json = try JSONSerialization.jsonObject(with: data, options: [])
		let jsonData = (json as! [String: Any])["data"]!
		print(jsonData)
		return jsonData
	}

	func fetchDevices(from jsonString: String) -> ConnectionInfo? {
		print("Received JSON string: \(jsonString)")  // Log the received JSON string

		guard let jsonData = jsonString.data(using: .utf8) else {
			print("Error: Unable to convert JSON string to Data")
			AppPrompt.shared.showingPrompt = .oldDevice
			return nil
		}

		do {
			let connectionInfo = try JSONDecoder().decode(ConnectionInfo.self, from: jsonData)
			return connectionInfo
		} catch {
			print("Error decoding ConnectionInfo: \(error)")
			AppPrompt.shared.showingPrompt = .oldDevice
			return nil
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
            let glass: UIGlassEffect = UIGlassEffect(style: .regular)
            glass.isInteractive = true

            backdropView = UIVisualEffectView(effect: glass)
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
            guard let self else { return }
            self.captureSession.startRunning()
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
