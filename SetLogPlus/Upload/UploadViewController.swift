import AVFoundation
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
    private let previewView = UIView()
    private let topScrimView = CameraScrimView(colors: [UIColor.black.withAlphaComponent(0.55), .clear])
    private let bottomScrimView = CameraScrimView(colors: [.clear, UIColor.black.withAlphaComponent(0.45)])

    // Status (preparing / unavailable)
    private let cameraStatusStackView = UIStackView()
    private let cameraStatusIconView = UIImageView(image: UIImage(systemName: "video.slash.fill"))
    private let cameraStatusLabel = UILabel()
    private let cameraStatusActivityIndicator = UIActivityIndicatorView(style: .medium)
    private let openSettingsButton = UIButton(type: .system)

    // Recording indicator
    private let recordingPillView = UIView()
    private let recordingDotView = UIView()
    private let recordingLabel = UILabel()

    // Controls
    private let captureButton = UIButton(type: .custom)
    private let captureInnerView = UIView()
    private let captureLogoImageView = UIImageView(image: UIImage(named: "CaptureLogo"))
    private let captureProgressLayer = CAShapeLayer()
    private let flashButton = IconCircleButton(systemName: "bolt.slash.fill", accessibilityLabel: "플래시")
    private let closeButton = IconCircleButton(systemName: "xmark", accessibilityLabel: "닫기")
    private let switchCameraButton = IconCircleButton(systemName: "arrow.triangle.2.circlepath.camera", accessibilityLabel: "카메라 전환")
    private let zoomContainerView = UIView()
    private let zoomStackView = UIStackView()

    private var cameraDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var isTorchOn = false
    private var selectedZoom: CGFloat = 1

    private static let captureButtonSize: CGFloat = 84
    private static let captureInnerSize: CGFloat = 68

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

    // MARK: - Layout

    private func setupLayout() {
        previewView.backgroundColor = AppTheme.cardMuted
        previewView.layer.cornerRadius = 28
        previewView.layer.cornerCurve = .continuous
        previewView.clipsToBounds = true
        previewView.translatesAutoresizingMaskIntoConstraints = false

        topScrimView.isUserInteractionEnabled = false
        topScrimView.translatesAutoresizingMaskIntoConstraints = false
        bottomScrimView.isUserInteractionEnabled = false
        bottomScrimView.translatesAutoresizingMaskIntoConstraints = false

        setupStatusView()
        setupRecordingPill()

        closeButton.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.35)
        closeButton.addTarget(self, action: #selector(showLog), for: .touchUpInside)

        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)

        let timeLabel = UILabel()
        timeLabel.text = HourSlot.displayText()
        timeLabel.font = UIFont.systemFont(ofSize: 28, weight: .heavy).rounded
        timeLabel.textColor = .white
        timeLabel.accessibilityLabel = "현재 시간대 \(HourSlot.displayText())"
        AppTheme.applyTextShadow(to: timeLabel, opacity: 0.35)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        setupZoomButtons()
        setupCaptureButton()

        let modeControl = BottomModeControl(selectedIndex: 0)
        modeControl.onLogTapped = { [weak self] in
            guard let self else { return }
            AppRouter.showLog(from: self)
        }
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        let backButton = IconCircleButton(systemName: "chevron.backward", accessibilityLabel: "뒤로 가기")
        backButton.addTarget(self, action: #selector(showLog), for: .touchUpInside)
        switchCameraButton.addTarget(self, action: #selector(switchCameraTapped), for: .touchUpInside)

        view.addSubview(previewView)
        previewView.addSubview(topScrimView)
        previewView.addSubview(bottomScrimView)
        previewView.addSubview(cameraStatusStackView)
        previewView.addSubview(closeButton)
        previewView.addSubview(timeLabel)
        previewView.addSubview(flashButton)
        previewView.addSubview(recordingPillView)
        previewView.addSubview(zoomContainerView)
        previewView.addSubview(captureButton)
        view.addSubview(modeControl)
        view.addSubview(backButton)
        view.addSubview(switchCameraButton)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppTheme.Spacing.m),
            previewView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Spacing.s),
            previewView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -AppTheme.Spacing.s),
            previewView.bottomAnchor.constraint(equalTo: modeControl.topAnchor, constant: -18),

            topScrimView.topAnchor.constraint(equalTo: previewView.topAnchor),
            topScrimView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            topScrimView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            topScrimView.heightAnchor.constraint(equalToConstant: 140),

            bottomScrimView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            bottomScrimView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            bottomScrimView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            bottomScrimView.heightAnchor.constraint(equalToConstant: 220),

            cameraStatusStackView.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            cameraStatusStackView.centerYAnchor.constraint(equalTo: previewView.centerYAnchor, constant: -24),
            cameraStatusStackView.leadingAnchor.constraint(greaterThanOrEqualTo: previewView.leadingAnchor, constant: 28),
            cameraStatusStackView.trailingAnchor.constraint(lessThanOrEqualTo: previewView.trailingAnchor, constant: -28),

            // Top bar: close · hour · flash
            closeButton.topAnchor.constraint(equalTo: previewView.topAnchor, constant: AppTheme.Spacing.l),
            closeButton.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: AppTheme.Spacing.l),

            timeLabel.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            flashButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            flashButton.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -AppTheme.Spacing.l),

            recordingPillView.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            recordingPillView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: AppTheme.Spacing.m),

            // Bottom: zoom chips above the shutter
            zoomContainerView.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            zoomContainerView.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -20),

            captureButton.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: previewView.bottomAnchor, constant: -30),

            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            backButton.centerYAnchor.constraint(equalTo: modeControl.centerYAnchor),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Spacing.xl),

            switchCameraButton.centerYAnchor.constraint(equalTo: modeControl.centerYAnchor),
            switchCameraButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -AppTheme.Spacing.xl)
        ])

        updateFlashButton()
    }

    private func setupStatusView() {
        cameraStatusIconView.tintColor = AppTheme.tertiaryText
        cameraStatusIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        cameraStatusIconView.contentMode = .scaleAspectFit
        cameraStatusIconView.isHidden = true

        cameraStatusActivityIndicator.color = AppTheme.secondaryText
        cameraStatusActivityIndicator.startAnimating()

        cameraStatusLabel.text = "카메라를 준비 중입니다"
        cameraStatusLabel.font = AppTheme.roundedFont(.subheadline, weight: .semibold)
        cameraStatusLabel.adjustsFontForContentSizeCategory = true
        cameraStatusLabel.textColor = AppTheme.secondaryText
        cameraStatusLabel.textAlignment = .center
        cameraStatusLabel.numberOfLines = 0

        var settingsConfiguration = UIButton.Configuration.filled()
        settingsConfiguration.title = "설정 열기"
        settingsConfiguration.image = UIImage(systemName: "gearshape.fill")
        settingsConfiguration.imagePadding = 6
        settingsConfiguration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        settingsConfiguration.cornerStyle = .capsule
        settingsConfiguration.baseBackgroundColor = AppTheme.neonPink
        settingsConfiguration.baseForegroundColor = .white
        settingsConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
        settingsConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.roundedFont(.subheadline, weight: .semibold)
            return attributes
        }
        openSettingsButton.configuration = settingsConfiguration
        openSettingsButton.enablePressAnimation()
        openSettingsButton.isHidden = true
        openSettingsButton.addTarget(self, action: #selector(openSettingsTapped), for: .touchUpInside)

        cameraStatusStackView.axis = .vertical
        cameraStatusStackView.alignment = .center
        cameraStatusStackView.spacing = AppTheme.Spacing.m
        cameraStatusStackView.addArrangedSubview(cameraStatusIconView)
        cameraStatusStackView.addArrangedSubview(cameraStatusActivityIndicator)
        cameraStatusStackView.addArrangedSubview(cameraStatusLabel)
        cameraStatusStackView.addArrangedSubview(openSettingsButton)
        cameraStatusStackView.setCustomSpacing(AppTheme.Spacing.l, after: cameraStatusLabel)
        cameraStatusStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupRecordingPill() {
        recordingPillView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        recordingPillView.layer.cornerRadius = 15
        recordingPillView.layer.cornerCurve = .continuous
        recordingPillView.alpha = 0
        recordingPillView.isAccessibilityElement = true
        recordingPillView.translatesAutoresizingMaskIntoConstraints = false

        recordingDotView.backgroundColor = AppTheme.danger
        recordingDotView.layer.cornerRadius = 4
        recordingDotView.translatesAutoresizingMaskIntoConstraints = false

        recordingLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        recordingLabel.textColor = .white
        recordingLabel.translatesAutoresizingMaskIntoConstraints = false

        recordingPillView.addSubview(recordingDotView)
        recordingPillView.addSubview(recordingLabel)

        NSLayoutConstraint.activate([
            recordingPillView.heightAnchor.constraint(equalToConstant: 30),

            recordingDotView.leadingAnchor.constraint(equalTo: recordingPillView.leadingAnchor, constant: 12),
            recordingDotView.centerYAnchor.constraint(equalTo: recordingPillView.centerYAnchor),
            recordingDotView.widthAnchor.constraint(equalToConstant: 8),
            recordingDotView.heightAnchor.constraint(equalToConstant: 8),

            recordingLabel.leadingAnchor.constraint(equalTo: recordingDotView.trailingAnchor, constant: 8),
            recordingLabel.trailingAnchor.constraint(equalTo: recordingPillView.trailingAnchor, constant: -14),
            recordingLabel.centerYAnchor.constraint(equalTo: recordingPillView.centerYAnchor)
        ])
    }

    private func setupCaptureButton() {
        let size = Self.captureButtonSize
        let innerSize = Self.captureInnerSize

        captureButton.backgroundColor = .clear
        captureButton.layer.cornerRadius = size / 2
        captureButton.layer.borderWidth = 4
        captureButton.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        captureButton.accessibilityLabel = "촬영 시작"
        captureButton.accessibilityHint = "\(Int(maxRecordSeconds))초 동안 영상을 촬영합니다"
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        captureButton.addTarget(self, action: #selector(captureTouchDown), for: .touchDown)
        captureButton.addTarget(self, action: #selector(captureTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        captureInnerView.backgroundColor = AppTheme.butter
        captureInnerView.layer.cornerRadius = innerSize / 2
        captureInnerView.layer.cornerCurve = .continuous
        captureInnerView.isUserInteractionEnabled = false
        captureInnerView.translatesAutoresizingMaskIntoConstraints = false

        captureLogoImageView.contentMode = .scaleAspectFit
        captureLogoImageView.layer.cornerRadius = 22
        captureLogoImageView.clipsToBounds = true
        captureLogoImageView.isUserInteractionEnabled = false
        captureLogoImageView.translatesAutoresizingMaskIntoConstraints = false

        // Recording progress ring drawn over the shutter's outline, starting at 12 o'clock.
        let ringRadius = size / 2 - 2
        captureProgressLayer.path = UIBezierPath(
            arcCenter: CGPoint(x: size / 2, y: size / 2),
            radius: ringRadius,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        ).cgPath
        captureProgressLayer.fillColor = UIColor.clear.cgColor
        captureProgressLayer.strokeColor = AppTheme.neonPink.cgColor
        captureProgressLayer.lineWidth = 5
        captureProgressLayer.lineCap = .round
        captureProgressLayer.strokeEnd = 0
        captureButton.layer.addSublayer(captureProgressLayer)

        captureButton.addSubview(captureInnerView)
        captureInnerView.addSubview(captureLogoImageView)

        NSLayoutConstraint.activate([
            captureButton.widthAnchor.constraint(equalToConstant: size),
            captureButton.heightAnchor.constraint(equalToConstant: size),

            captureInnerView.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            captureInnerView.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            captureInnerView.widthAnchor.constraint(equalToConstant: innerSize),
            captureInnerView.heightAnchor.constraint(equalToConstant: innerSize),

            captureLogoImageView.centerXAnchor.constraint(equalTo: captureInnerView.centerXAnchor),
            captureLogoImageView.centerYAnchor.constraint(equalTo: captureInnerView.centerYAnchor),
            captureLogoImageView.widthAnchor.constraint(equalToConstant: 48),
            captureLogoImageView.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func setupZoomButtons() {
        zoomContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        zoomContainerView.layer.cornerRadius = 22
        zoomContainerView.layer.cornerCurve = .continuous
        zoomContainerView.translatesAutoresizingMaskIntoConstraints = false

        zoomStackView.axis = .horizontal
        zoomStackView.alignment = .center
        zoomStackView.distribution = .equalSpacing
        zoomStackView.spacing = 6
        zoomStackView.translatesAutoresizingMaskIntoConstraints = false

        [CGFloat(0.5), CGFloat(1), CGFloat(3)].forEach { zoom in
            let button = UIButton(type: .custom)
            button.tag = Int(zoom * 10)
            button.addTarget(self, action: #selector(zoomTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 36),
                button.heightAnchor.constraint(equalToConstant: 36)
            ])

            zoomStackView.addArrangedSubview(button)
        }

        zoomContainerView.addSubview(zoomStackView)
        NSLayoutConstraint.activate([
            zoomStackView.topAnchor.constraint(equalTo: zoomContainerView.topAnchor, constant: 4),
            zoomStackView.bottomAnchor.constraint(equalTo: zoomContainerView.bottomAnchor, constant: -4),
            zoomStackView.leadingAnchor.constraint(equalTo: zoomContainerView.leadingAnchor, constant: 4),
            zoomStackView.trailingAnchor.constraint(equalTo: zoomContainerView.trailingAnchor, constant: -4)
        ])

        updateZoomButtons()
    }

    // MARK: - Camera setup

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
                        self?.showCameraUnavailableMessage("카메라 권한이 필요합니다.\n설정에서 카메라 접근을 허용해주세요.", showsSettingsButton: true)
                    }
                }
            }
        case .denied, .restricted:
            showCameraUnavailableMessage("카메라 권한이 꺼져 있습니다.\n설정에서 카메라 접근을 허용해주세요.", showsSettingsButton: true)
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
        guard let camera = preferredCamera(position: currentCameraPosition, zoom: selectedZoom) else {
            showCameraUnavailableMessage("이 환경에서는 카메라를 사용할 수 없습니다.\n시뮬레이터 대신 실제 iPhone에서 확인해주세요.")
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
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
        hideCameraStatus()
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

        if (try? cameraDevice.lockForConfiguration()) != nil {
            cameraDevice.torchMode = .off
            cameraDevice.unlockForConfiguration()
        }
        isTorchOn = false
        updateFlashButton()
    }

    // MARK: - Status presentation

    private func showCameraUnavailableMessage(_ message: String, showsSettingsButton: Bool = false) {
        cameraStatusLabel.text = message
        cameraStatusIconView.isHidden = false
        cameraStatusActivityIndicator.stopAnimating()
        cameraStatusActivityIndicator.isHidden = true
        openSettingsButton.isHidden = !showsSettingsButton
        cameraStatusStackView.isHidden = false
        zoomContainerView.isHidden = true
        UIAccessibility.post(notification: .layoutChanged, argument: cameraStatusLabel)
    }

    private func hideCameraStatus() {
        cameraStatusActivityIndicator.stopAnimating()
        cameraStatusStackView.isHidden = true
        zoomContainerView.isHidden = false
    }

    @objc private func openSettingsTapped() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func setRecordingAppearance(_ isRecording: Bool) {
        let innerSize = Self.captureInnerSize
        captureButton.accessibilityLabel = isRecording ? "촬영 중" : "촬영 시작"
        captureButton.accessibilityTraits = isRecording ? [.button, .notEnabled] : .button

        if isRecording {
            updateRecordingProgress(elapsed: 0)
            recordingLabel.text = "촬영 중 0.0초"
            startRecordingDotPulse()
        } else {
            recordingDotView.layer.removeAllAnimations()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            captureProgressLayer.strokeEnd = 0
            CATransaction.commit()
        }

        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.captureInnerView.transform = isRecording ? CGAffineTransform(scaleX: 0.5, y: 0.5) : .identity
            self.captureInnerView.layer.cornerRadius = isRecording ? 16 : innerSize / 2
            self.captureInnerView.backgroundColor = isRecording ? AppTheme.danger : AppTheme.butter
            self.captureLogoImageView.alpha = isRecording ? 0 : 1
            self.captureButton.layer.borderColor = (isRecording
                ? UIColor.white.withAlphaComponent(0.35)
                : UIColor.white.withAlphaComponent(0.9)).cgColor
            if isRecording {
                // Hiding is handled by `showRecordingCompleted` / `hideRecordingPill`.
                self.recordingPillView.alpha = 1
            }
            self.zoomContainerView.alpha = isRecording ? 0.35 : 1
            self.switchCameraButton.alpha = isRecording ? 0.35 : 1
        }
    }

    private func startRecordingDotPulse() {
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.25
        pulse.duration = 0.5
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        recordingDotView.layer.add(pulse, forKey: "pulse")
    }

    private func updateRecordingProgress(elapsed: TimeInterval) {
        let progress = min(max(elapsed / maxRecordSeconds, 0), 1)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        captureProgressLayer.strokeEnd = progress
        CATransaction.commit()

        let clamped = min(max(elapsed, 0), maxRecordSeconds)
        recordingLabel.text = String(format: "촬영 중 %.1f초", clamped)
        recordingPillView.accessibilityLabel = "촬영 중"
    }

    private func showRecordingCompleted() {
        recordingDotView.layer.removeAllAnimations()
        recordingDotView.backgroundColor = AppTheme.success
        recordingLabel.text = "촬영 완료"
        recordingPillView.accessibilityLabel = "촬영 완료"
        recordingPillView.alpha = 1

        UIView.animate(withDuration: 0.25, delay: 1.2, options: [.beginFromCurrentState]) {
            self.recordingPillView.alpha = 0
        } completion: { _ in
            self.recordingDotView.backgroundColor = AppTheme.danger
        }
    }

    private func hideRecordingPill() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState]) {
            self.recordingPillView.alpha = 0
        }
    }

    @objc private func captureTouchDown() {
        UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
    }

    @objc private func captureTouchUp() {
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.captureButton.transform = .identity
        }
    }

    // MARK: - Controls

    @objc private func zoomTapped(_ sender: UIButton) {
        guard !movieOutput.isRecording else { return }

        let zoom = CGFloat(sender.tag) / 10
        if switchCameraDeviceIfNeeded(position: currentCameraPosition, zoom: zoom) {
            if zoom != selectedZoom {
                Haptics.selection()
            }
            selectedZoom = zoom
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

        let newInput: AVCaptureDeviceInput
        do {
            newInput = try AVCaptureDeviceInput(device: newCamera)
        } catch {
            showAlert(title: "카메라 변경 실패", message: error.localizedDescription)
            return false
        }

        turnTorchOffIfNeeded()

        captureSession.beginConfiguration()
        let previousInput = videoInput
        if let previousInput {
            captureSession.removeInput(previousInput)
        }

        guard captureSession.canAddInput(newInput) else {
            if let previousInput, captureSession.canAddInput(previousInput) {
                captureSession.addInput(previousInput)
            }
            captureSession.commitConfiguration()
            showAlert(title: "카메라 변경 실패", message: "선택한 카메라 입력을 추가할 수 없습니다.")
            return false
        }

        captureSession.addInput(newInput)
        captureSession.commitConfiguration()

        videoInput = newInput
        cameraDevice = newCamera
        currentCameraPosition = position
        applyZoom(zoom)
        updateFlashButton()
        return true
    }

    private func updateZoomButtons() {
        zoomStackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { button in
            let zoom = CGFloat(button.tag) / 10
            let isSelected = zoom == selectedZoom
            let baseTitle = zoom == 0.5 ? ".5" : "\(Int(zoom))"

            var configuration = UIButton.Configuration.plain()
            configuration.title = isSelected ? "\(baseTitle)×" : baseTitle
            configuration.contentInsets = .zero
            configuration.cornerStyle = .capsule
            configuration.background.backgroundColor = isSelected ? UIColor.black.withAlphaComponent(0.55) : .clear
            configuration.baseForegroundColor = isSelected ? AppTheme.butter : UIColor.white.withAlphaComponent(0.85)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.systemFont(ofSize: isSelected ? 13 : 12, weight: .bold).rounded
                return attributes
            }
            button.configuration = configuration
            button.accessibilityLabel = "\(zoom == 0.5 ? "0.5" : baseTitle)배 줌"
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
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

        let nextPosition: AVCaptureDevice.Position = currentCameraPosition == .back ? .front : .back
        if switchCameraDeviceIfNeeded(position: nextPosition, zoom: 1) {
            selectedZoom = 1
        }
        updateZoomButtons()
    }

    private func updateFlashButton() {
        let hasTorch = cameraDevice?.hasTorch ?? false
        var configuration = flashButton.configuration
        configuration?.image = UIImage(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
        configuration?.baseForegroundColor = isTorchOn ? .black : .white
        configuration?.baseBackgroundColor = isTorchOn ? AppTheme.butter : UIColor.black.withAlphaComponent(0.35)
        flashButton.configuration = configuration
        flashButton.alpha = (cameraDevice == nil || hasTorch) ? 1 : 0.45
        flashButton.accessibilityValue = isTorchOn ? "켜짐" : "꺼짐"
    }

    @objc private func showLog() {
        AppRouter.showLog(from: self)
    }

    // MARK: - Recording

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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        hideCameraStatus()
        setRecordingAppearance(true)

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

    private func handleRecordingFinished(fileURL: URL, errorMessage: String?) {
        recordTimer?.invalidate()
        recordTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil

        if let errorMessage {
            try? FileManager.default.removeItem(at: fileURL)
            resetCaptureButton()
            hideRecordingPill()
            Haptics.error()
            showAlert(title: "촬영 실패", message: errorMessage)
            return
        }

        finishRecording(fileURL: fileURL)
    }

    private func finishRecording(fileURL: URL) {
        recordedVideoURL = fileURL
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        resetCaptureButton()
        showRecordingCompleted()

        showGroupSelection()
    }

    private func showGroupSelection() {
        guard let userID = AuthService.shared.currentUserID else {
            showAlert(title: "업로드 실패", message: "로그인이 필요합니다.")
            return
        }

        groupRepository.fetchGroups(for: userID) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let groups):
                self.presentGroupSelection(groups)
            case .failure(let error):
                self.showAlert(title: "그룹 조회 실패", message: error.localizedDescription)
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

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self,
                  let recordingStartedAt = self.recordingStartedAt else {
                return
            }

            self.updateRecordingProgress(elapsed: Date().timeIntervalSince(recordingStartedAt))
        }
    }

    private func resetCaptureButton() {
        setRecordingAppearance(false)
    }
}

extension UploadViewController: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        // Hitting `maxRecordedDuration` reports an error even though the file is complete.
        let nsError = error as NSError?
        let finishedSuccessfully = nsError == nil
            || nsError?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
        let errorMessage = nsError?.localizedDescription

        Task { @MainActor in
            self.handleRecordingFinished(
                fileURL: outputFileURL,
                errorMessage: finishedSuccessfully ? nil : errorMessage
            )
        }
    }
}

/// Non-interactive vertical gradient used as a legibility scrim over the camera preview.
private final class CameraScrimView: UIView {
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    init(colors: [UIColor]) {
        super.init(frame: .zero)
        let gradientLayer = layer as! CAGradientLayer
        gradientLayer.colors = colors.map(\.cgColor)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
