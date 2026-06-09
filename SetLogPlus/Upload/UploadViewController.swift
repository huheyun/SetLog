import AVFoundation
import FirebaseAuth
import UIKit

final class UploadViewController: UIViewController {
    private let maxRecordSeconds: TimeInterval = 3
    private let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let groupRepository = GroupRepository()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var recordedVideoURL: URL?
    private var recordTimer: Timer?
    private var progressTimer: Timer?
    private var recordingStartedAt: Date?
    private var recordingHourKey: String?
    private let cameraStatusLabel = UILabel()
    private let previewView = UIView()
    private let captureButton = UIButton(type: .system)
    private let captureLogoImageView = UIImageView(image: UIImage(named: "CaptureLogo"))
    private let captureStopImageView = UIImageView(image: UIImage(systemName: "stop.fill"))
    private let flashButton = IconCircleButton(systemName: "bolt.slash.fill")
    private let zoomStackView = UIStackView()
    private let progressTrackView = UIView()
    private let progressFillView = UIView()
    private var cameraDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var isTorchOn = false
    private var selectedZoom: CGFloat = 1
    private var progressFillHeightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        view.backgroundColor = AppTheme.background
        AppTheme.applyDarkNavigation(to: navigationController)
        setupLayout()
        requestCameraAccess()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewView.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }

    private func setupLayout() {
        previewView.backgroundColor = AppTheme.cardMuted
        previewView.layer.cornerRadius = 26
        previewView.clipsToBounds = true
        previewView.translatesAutoresizingMaskIntoConstraints = false

        progressTrackView.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        progressTrackView.layer.cornerRadius = 4
        progressTrackView.clipsToBounds = true
        progressTrackView.isHidden = true
        progressTrackView.translatesAutoresizingMaskIntoConstraints = false

        progressFillView.backgroundColor = .systemCyan
        progressFillView.layer.cornerRadius = 4
        progressFillView.translatesAutoresizingMaskIntoConstraints = false

        cameraStatusLabel.text = "카메라를 준비 중입니다"
        cameraStatusLabel.font = .preferredFont(forTextStyle: .subheadline)
        cameraStatusLabel.textColor = AppTheme.secondaryText
        cameraStatusLabel.textAlignment = .center
        cameraStatusLabel.numberOfLines = 0
        cameraStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = IconCircleButton(systemName: "xmark")
        closeButton.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.35)
        closeButton.addTarget(self, action: #selector(showLog), for: .touchUpInside)

        let timeLabel = UILabel()
        timeLabel.text = HourSlot.displayText()
        timeLabel.font = .systemFont(ofSize: 34, weight: .black)
        timeLabel.textColor = .white
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        setupZoomButtons()

        captureButton.configuration = nil
        captureButton.backgroundColor = AppTheme.butter
        captureButton.layer.borderColor = AppTheme.neonPink.cgColor
        captureButton.layer.borderWidth = 5
        captureButton.layer.cornerRadius = 42
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)

        captureLogoImageView.contentMode = .scaleAspectFit
        captureLogoImageView.layer.cornerRadius = 26
        captureLogoImageView.clipsToBounds = true
        captureLogoImageView.isUserInteractionEnabled = false
        captureLogoImageView.translatesAutoresizingMaskIntoConstraints = false

        captureStopImageView.contentMode = .scaleAspectFit
        captureStopImageView.tintColor = .white
        captureStopImageView.isHidden = true
        captureStopImageView.isUserInteractionEnabled = false
        captureStopImageView.translatesAutoresizingMaskIntoConstraints = false

        flashButton.configuration?.baseForegroundColor = AppTheme.secondaryText
        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)

        let modeControl = BottomModeControl(selectedIndex: 0)
        modeControl.onLogTapped = { [weak self] in
            guard let self else { return }
            AppRouter.showLog(from: self)
        }
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        let leftRotateButton = IconCircleButton(systemName: "gobackward")
        let rightRotateButton = IconCircleButton(systemName: "arrow.triangle.2.circlepath.camera")
        rightRotateButton.addTarget(self, action: #selector(switchCameraTapped), for: .touchUpInside)

        view.addSubview(previewView)
        previewView.addSubview(progressTrackView)
        progressTrackView.addSubview(progressFillView)
        previewView.addSubview(cameraStatusLabel)
        previewView.addSubview(closeButton)
        previewView.addSubview(timeLabel)
        previewView.addSubview(zoomStackView)
        previewView.addSubview(captureButton)
        captureButton.addSubview(captureLogoImageView)
        captureButton.addSubview(captureStopImageView)
        previewView.addSubview(flashButton)
        view.addSubview(modeControl)
        view.addSubview(leftRotateButton)
        view.addSubview(rightRotateButton)

        progressFillHeightConstraint = progressFillView.heightAnchor.constraint(equalToConstant: 0)
        progressFillHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            previewView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            previewView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            previewView.bottomAnchor.constraint(equalTo: modeControl.topAnchor, constant: -18),

            progressTrackView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 10),
            progressTrackView.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
            progressTrackView.widthAnchor.constraint(equalToConstant: 8),
            progressTrackView.heightAnchor.constraint(equalTo: previewView.heightAnchor, multiplier: 0.36),

            progressFillView.leadingAnchor.constraint(equalTo: progressTrackView.leadingAnchor),
            progressFillView.trailingAnchor.constraint(equalTo: progressTrackView.trailingAnchor),
            progressFillView.bottomAnchor.constraint(equalTo: progressTrackView.bottomAnchor),

            cameraStatusLabel.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            cameraStatusLabel.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
            cameraStatusLabel.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 28),
            cameraStatusLabel.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -28),

            closeButton.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -16),

            timeLabel.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: previewView.centerYAnchor, constant: -12),

            zoomStackView.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            zoomStackView.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -20),

            captureButton.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: previewView.bottomAnchor, constant: -34),
            captureButton.widthAnchor.constraint(equalToConstant: 84),
            captureButton.heightAnchor.constraint(equalToConstant: 84),

            captureLogoImageView.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            captureLogoImageView.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            captureLogoImageView.widthAnchor.constraint(equalToConstant: 56),
            captureLogoImageView.heightAnchor.constraint(equalToConstant: 56),

            captureStopImageView.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            captureStopImageView.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            captureStopImageView.widthAnchor.constraint(equalToConstant: 30),
            captureStopImageView.heightAnchor.constraint(equalToConstant: 30),

            flashButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            flashButton.trailingAnchor.constraint(equalTo: captureButton.leadingAnchor, constant: -46),

            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            leftRotateButton.centerYAnchor.constraint(equalTo: modeControl.centerYAnchor),
            leftRotateButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),

            rightRotateButton.centerYAnchor.constraint(equalTo: modeControl.centerYAnchor),
            rightRotateButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ])

    }

    private func setupZoomButtons() {
        zoomStackView.axis = .horizontal
        zoomStackView.alignment = .center
        zoomStackView.distribution = .equalSpacing
        zoomStackView.spacing = 28
        zoomStackView.translatesAutoresizingMaskIntoConstraints = false

        [CGFloat(0.5), CGFloat(1), CGFloat(3)].forEach { zoom in
            let button = UIButton(type: .system)
            button.setTitle(zoom == 0.5 ? ".5" : "\(Int(zoom))", for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: zoom == selectedZoom ? .bold : .semibold)
            button.tintColor = zoom == selectedZoom ? AppTheme.mint : UIColor.white.withAlphaComponent(0.85)
            button.tag = Int(zoom * 10)
            button.addTarget(self, action: #selector(zoomTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 34),
                button.heightAnchor.constraint(equalToConstant: 34)
            ])

            zoomStackView.addArrangedSubview(button)
        }
    }

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestMicrophoneAccess()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.requestMicrophoneAccess()
                    } else {
                        self?.showCameraUnavailableMessage("카메라 권한이 필요합니다.\n설정에서 카메라 접근을 허용해주세요.")
                    }
                }
            }
        case .denied, .restricted:
            showCameraUnavailableMessage("카메라 권한이 꺼져 있습니다.\n설정에서 카메라 접근을 허용해주세요.")
        @unknown default:
            showCameraUnavailableMessage("카메라 상태를 확인할 수 없습니다.")
        }
    }

    private func requestMicrophoneAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            configureCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.configureCamera()
                }
            }
        case .denied, .restricted:
            configureCamera()
        @unknown default:
            configureCamera()
        }
    }

    private func configureCamera() {
        guard preferredCamera(position: .back, zoom: selectedZoom) != nil else {
            showCameraUnavailableMessage("이 환경에서는 카메라를 사용할 수 없습니다.\n시뮬레이터 대신 실제 iPhone에서 확인해주세요.")
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        guard let camera = preferredCamera(position: .back, zoom: selectedZoom) else {
            captureSession.commitConfiguration()
            showCameraUnavailableMessage("후면 카메라를 찾을 수 없습니다.")
            return
        }
        cameraDevice = camera

        do {
            let input = try AVCaptureDeviceInput(device: camera)

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                videoInput = input
            }

            if let microphone = AVCaptureDevice.default(for: .audio),
               AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                let audioInput = try AVCaptureDeviceInput(device: microphone)

                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                }
            }
        } catch {
            captureSession.commitConfiguration()
            showCameraUnavailableMessage("카메라를 시작하지 못했습니다.\n\(error.localizedDescription)")
            return
        }

        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            movieOutput.maxRecordedDuration = CMTime(seconds: maxRecordSeconds, preferredTimescale: 600)
        }

        captureSession.commitConfiguration()
        attachPreviewLayer()
        applyZoom(selectedZoom)
        updateFlashButton()
        startCamera()
    }

    private func preferredCamera(position: AVCaptureDevice.Position, zoom: CGFloat) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if position == .front {
            deviceTypes = [.builtInTrueDepthCamera, .builtInWideAngleCamera]
        } else if zoom <= 0.5 {
            deviceTypes = [.builtInUltraWideCamera, .builtInDualWideCamera, .builtInTripleCamera, .builtInWideAngleCamera]
        } else {
            deviceTypes = [.builtInWideAngleCamera, .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera]
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )

        return discoverySession.devices.first
    }

    private func attachPreviewLayer() {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = previewView.bounds
        previewView.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        cameraStatusLabel.isHidden = true
    }

    private func startCamera() {
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    private func stopCamera() {
        recordTimer?.invalidate()
        recordTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        turnTorchOffIfNeeded()

        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func turnTorchOffIfNeeded() {
        guard let cameraDevice, cameraDevice.hasTorch, isTorchOn else { return }

        do {
            try cameraDevice.lockForConfiguration()
            cameraDevice.torchMode = .off
            cameraDevice.unlockForConfiguration()
            isTorchOn = false
            updateFlashButton()
        } catch {
            isTorchOn = false
            updateFlashButton()
        }
    }

    private func showCameraUnavailableMessage(_ message: String) {
        cameraStatusLabel.isHidden = false
        cameraStatusLabel.text = message
    }

    @objc private func zoomTapped(_ sender: UIButton) {
        let zoom = CGFloat(sender.tag) / 10
        let previousZoom = selectedZoom
        selectedZoom = zoom
        if !switchCameraDeviceIfNeeded(position: currentCameraPosition, zoom: zoom) {
            selectedZoom = previousZoom
        }
        updateZoomButtons()
    }

    private func applyZoom(_ zoom: CGFloat) {
        guard let cameraDevice else { return }

        do {
            try cameraDevice.lockForConfiguration()
            let minimumZoom = cameraDevice.minAvailableVideoZoomFactor
            let maximumZoom = min(cameraDevice.maxAvailableVideoZoomFactor, 3)
            let targetZoom = cameraDevice.deviceType == .builtInUltraWideCamera && zoom <= 0.5 ? 1 : zoom
            cameraDevice.videoZoomFactor = min(max(targetZoom, minimumZoom), maximumZoom)
            cameraDevice.unlockForConfiguration()
        } catch {
            showAlert(title: "줌 변경 실패", message: error.localizedDescription)
        }
    }

    @discardableResult
    private func switchCameraDeviceIfNeeded(position: AVCaptureDevice.Position, zoom: CGFloat) -> Bool {
        guard let newCamera = preferredCamera(position: position, zoom: zoom) else {
            showAlert(title: "카메라 변경 실패", message: "선택한 카메라를 사용할 수 없습니다.")
            return false
        }

        guard newCamera.uniqueID != cameraDevice?.uniqueID else {
            applyZoom(zoom)
            return true
        }

        var didBeginConfiguration = false
        let previousInput = videoInput
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            captureSession.beginConfiguration()
            didBeginConfiguration = true

            if let videoInput {
                captureSession.removeInput(videoInput)
            }

            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                videoInput = newInput
                cameraDevice = newCamera
                currentCameraPosition = position
            } else {
                if let previousInput,
                   captureSession.canAddInput(previousInput) {
                    captureSession.addInput(previousInput)
                }
                captureSession.commitConfiguration()
                showAlert(title: "카메라 변경 실패", message: "선택한 카메라 입력을 추가할 수 없습니다.")
                return false
            }

            captureSession.commitConfiguration()
            isTorchOn = false
            applyZoom(zoom)
            updateFlashButton()
            return true
        } catch {
            if let previousInput,
               !captureSession.inputs.contains(where: { $0 === previousInput }),
               captureSession.canAddInput(previousInput) {
                captureSession.addInput(previousInput)
            }
            if didBeginConfiguration {
                captureSession.commitConfiguration()
            }
            showAlert(title: "카메라 변경 실패", message: error.localizedDescription)
            return false
        }
    }

    private func updateZoomButtons() {
        zoomStackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { button in
            let zoom = CGFloat(button.tag) / 10
            let isSelected = zoom == selectedZoom
            button.tintColor = isSelected ? AppTheme.mint : UIColor.white.withAlphaComponent(0.85)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: isSelected ? .bold : .semibold)
        }
    }

    @objc private func flashTapped() {
        guard let cameraDevice, cameraDevice.hasTorch else {
            showAlert(title: "플래시 사용 불가", message: "이 기기에서는 영상 플래시를 사용할 수 없습니다.")
            return
        }

        do {
            try cameraDevice.lockForConfiguration()
            isTorchOn.toggle()
            cameraDevice.torchMode = isTorchOn ? .on : .off
            cameraDevice.unlockForConfiguration()
            updateFlashButton()
        } catch {
            showAlert(title: "플래시 변경 실패", message: error.localizedDescription)
        }
    }

    @objc private func switchCameraTapped() {
        guard !movieOutput.isRecording else { return }

        let previousPosition = currentCameraPosition
        let previousZoom = selectedZoom
        let nextPosition: AVCaptureDevice.Position = currentCameraPosition == .back ? .front : .back
        selectedZoom = 1
        if !switchCameraDeviceIfNeeded(position: nextPosition, zoom: selectedZoom) {
            currentCameraPosition = previousPosition
            selectedZoom = previousZoom
        }
        updateZoomButtons()
    }

    private func updateFlashButton() {
        let imageName = isTorchOn ? "bolt.fill" : "bolt.slash.fill"
        var configuration = flashButton.configuration
        configuration?.image = UIImage(systemName: imageName)
        configuration?.baseForegroundColor = isTorchOn ? AppTheme.mint : AppTheme.secondaryText
        flashButton.configuration = configuration
    }

    @objc private func showLog() {
        AppRouter.showLog(from: self)
    }

    @objc private func captureTapped() {
        guard !movieOutput.isRecording else { return }
        startRecording()
    }

    private func startRecording() {
        guard captureSession.isRunning else {
            showAlert(title: "촬영 실패", message: "카메라가 아직 준비되지 않았습니다.")
            return
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        recordedVideoURL = nil
        recordingHourKey = HourSlot.currentKey()
        captureLogoImageView.isHidden = true
        captureStopImageView.isHidden = false
        captureButton.backgroundColor = .systemRed
        cameraStatusLabel.isHidden = false
        cameraStatusLabel.text = "촬영 중입니다"
        progressTrackView.isHidden = false
        progressFillHeightConstraint?.constant = 0
        previewView.layoutIfNeeded()

        movieOutput.connection(with: .audio)?.isEnabled = true
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        recordingStartedAt = Date()
        startProgressTimer()
        recordTimer?.invalidate()
        recordTimer = Timer.scheduledTimer(withTimeInterval: maxRecordSeconds, repeats: false) { [weak self] _ in
            self?.stopRecording()
        }
    }

    private func stopRecording() {
        recordTimer?.invalidate()
        recordTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil

        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
    }

    private func finishRecording(fileURL: URL) {
        recordedVideoURL = fileURL
        resetCaptureButton()
        cameraStatusLabel.text = "촬영 완료"
        progressTrackView.isHidden = true

        showGroupSelection()
    }

    private func showGroupSelection() {
        guard let user = Auth.auth().currentUser else {
            showAlert(title: "업로드 실패", message: "로그인이 필요합니다.")
            return
        }

        groupRepository.fetchGroups(for: user.uid) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .success(let groups):
                    self.presentGroupSelection(groups)
                case .failure(let error):
                    self.showAlert(title: "그룹 조회 실패", message: error.localizedDescription)
                }
            }
        }
    }

    private func presentGroupSelection(_ groups: [Group]) {
        guard !groups.isEmpty else {
            showAlert(title: "업로드할 그룹 없음", message: "먼저 로그 화면에서 그룹을 만들거나 초대 코드로 참여해주세요.")
            return
        }

        guard let recordedVideoURL else {
            showAlert(title: "업로드 실패", message: "촬영된 영상을 찾을 수 없습니다.")
            return
        }

        let selectionViewController = UploadGroupSelectionViewController(
            fileURL: recordedVideoURL,
            groups: groups,
            hourKey: recordingHourKey ?? HourSlot.currentKey(),
            durationSeconds: Int(maxRecordSeconds)
        )
        present(selectionViewController, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default))
        present(alertController, animated: true)
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self,
                  let recordingStartedAt = self.recordingStartedAt else {
                return
            }

            let elapsed = Date().timeIntervalSince(recordingStartedAt)
            let progress = min(max(elapsed / self.maxRecordSeconds, 0), 1)
            self.progressFillHeightConstraint?.constant = self.progressTrackView.bounds.height * progress
            self.previewView.layoutIfNeeded()
        }
    }

    private func resetCaptureButton() {
        captureLogoImageView.isHidden = false
        captureStopImageView.isHidden = true
        captureButton.backgroundColor = AppTheme.butter
        captureButton.layer.borderColor = AppTheme.neonPink.cgColor
    }

}

extension UploadViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.recordTimer?.invalidate()
            self.recordTimer = nil
            self.progressTimer?.invalidate()
            self.progressTimer = nil

            if let error {
                self.resetCaptureButton()
                self.progressTrackView.isHidden = true
                self.showAlert(title: "촬영 실패", message: error.localizedDescription)
                return
            }

            self.finishRecording(fileURL: outputFileURL)
        }
    }
}
