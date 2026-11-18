import AVKit
import UIKit

final class UploadGroupSelectionViewController: UIViewController {
    private let fileURL: URL
    private let groups: [Group]
    private let hourKey: String
    private let durationSeconds: Int
    private let postUploadService = PostUploadService()
    private let videoAudioService = VideoAudioService()
    private var selectedGroupIDs: Set<String> = []
    private var includesAudio = true
    private var isUploading = false {
        didSet { updateUploadButton() }
    }
    private let groupStackView = UIStackView()
    private var groupRows: [String: UploadGroupSelectionRow] = [:]
    private let uploadButton = UIButton(type: .system)
    private let soundButton = IconCircleButton(systemName: "speaker.wave.2.fill", accessibilityLabel: "소리")
    private let selectAllButton = UIButton(type: .system)
    private let selectionCountLabel = UILabel()
    private let uploadOverlayView = UIView()
    private let uploadStatusIconView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let uploadStatusLabel = UILabel()
    private let uploadProgressLabel = UILabel()
    private let uploadProgressView = UIProgressView(progressViewStyle: .default)
    private let uploadActivityIndicator = UIActivityIndicatorView(style: .large)
    private var player: AVPlayer?
    private weak var playerLayer: AVPlayerLayer?
    private var mutedCopyURL: URL?

    init(fileURL: URL, groups: [Group], hourKey: String, durationSeconds: Int) {
        self.fileURL = fileURL
        self.groups = groups
        self.hourKey = hourKey
        self.durationSeconds = durationSeconds
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        setupLayout()
        renderGroups()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        player?.pause()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = playerLayer?.superlayer?.bounds ?? .zero
    }

    // MARK: - Layout

    private func setupLayout() {
        let closeButton = IconCircleButton(systemName: "xmark", accessibilityLabel: "닫기")
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.text = "로그 올리기"
        titleLabel.font = AppTheme.roundedFont(.headline, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.text
        titleLabel.accessibilityTraits = .header
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let previewView = makePreviewView()

        let sectionTitleLabel = UILabel()
        sectionTitleLabel.text = "보낼 로그방"
        sectionTitleLabel.font = AppTheme.roundedFont(.title3, weight: .bold)
        sectionTitleLabel.adjustsFontForContentSizeCategory = true
        sectionTitleLabel.textColor = AppTheme.text
        sectionTitleLabel.accessibilityTraits = .header

        selectionCountLabel.font = AppTheme.roundedFont(.subheadline, weight: .semibold)
        selectionCountLabel.adjustsFontForContentSizeCategory = true
        selectionCountLabel.textColor = AppTheme.tertiaryText

        var selectAllConfiguration = UIButton.Configuration.plain()
        selectAllConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 0)
        selectAllConfiguration.baseForegroundColor = AppTheme.neonPink
        selectAllConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.roundedFont(.subheadline, weight: .semibold)
            return attributes
        }
        selectAllButton.configuration = selectAllConfiguration
        selectAllButton.isHidden = groups.count < 2
        selectAllButton.setContentHuggingPriority(.required, for: .horizontal)
        selectAllButton.addTarget(self, action: #selector(selectAllTapped), for: .touchUpInside)

        let sectionTitleStackView = UIStackView(arrangedSubviews: [sectionTitleLabel, selectionCountLabel])
        sectionTitleStackView.axis = .horizontal
        sectionTitleStackView.alignment = .firstBaseline
        sectionTitleStackView.spacing = AppTheme.Spacing.s

        let sectionHeaderStackView = UIStackView(arrangedSubviews: [sectionTitleStackView, UIView(), selectAllButton])
        sectionHeaderStackView.axis = .horizontal
        sectionHeaderStackView.alignment = .center
        sectionHeaderStackView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        groupStackView.axis = .vertical
        groupStackView.spacing = AppTheme.Spacing.m - 2
        groupStackView.translatesAutoresizingMaskIntoConstraints = false

        // Sticky footer with a soft fade so rows scroll under the button.
        let footerView = UIView()
        footerView.backgroundColor = AppTheme.background
        footerView.translatesAutoresizingMaskIntoConstraints = false
        let footerFadeView = UploadFadeView(colors: [AppTheme.background.withAlphaComponent(0), AppTheme.background])
        footerFadeView.isUserInteractionEnabled = false
        footerFadeView.translatesAutoresizingMaskIntoConstraints = false

        setupUploadButton()
        setupUploadOverlay()

        view.addSubview(closeButton)
        view.addSubview(titleLabel)
        view.addSubview(previewView)
        view.addSubview(sectionHeaderStackView)
        view.addSubview(scrollView)
        scrollView.addSubview(groupStackView)
        view.addSubview(footerFadeView)
        view.addSubview(footerView)
        footerView.addSubview(uploadButton)
        view.addSubview(uploadOverlayView)

        let margin = AppTheme.Spacing.screen
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppTheme.Spacing.s),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Spacing.l),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            previewView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: AppTheme.Spacing.m),
            previewView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin),
            previewView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin),
            previewView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3),

            sectionHeaderStackView.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: AppTheme.Spacing.xl),
            sectionHeaderStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin),
            sectionHeaderStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin),
            sectionHeaderStackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),

            scrollView.topAnchor.constraint(equalTo: sectionHeaderStackView.bottomAnchor, constant: AppTheme.Spacing.m),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin),
            scrollView.bottomAnchor.constraint(equalTo: footerView.topAnchor),

            groupStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            groupStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            groupStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            groupStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.l),
            groupStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            footerFadeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerFadeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerFadeView.bottomAnchor.constraint(equalTo: footerView.topAnchor),
            footerFadeView.heightAnchor.constraint(equalToConstant: AppTheme.Spacing.xl),

            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            uploadButton.topAnchor.constraint(equalTo: footerView.topAnchor, constant: AppTheme.Spacing.s),
            uploadButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin),
            uploadButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin),
            uploadButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.m),

            uploadOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            uploadOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            uploadOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            uploadOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        updateSoundButton()
        player?.play()
    }

    private func makePreviewView() -> UIView {
        let previewView = UIView()
        previewView.backgroundColor = AppTheme.cardMuted
        previewView.layer.cornerRadius = AppTheme.Radius.large
        previewView.layer.cornerCurve = .continuous
        previewView.layer.borderWidth = 1
        previewView.layer.borderColor = AppTheme.separator.cgColor
        previewView.clipsToBounds = true
        previewView.isAccessibilityElement = false
        previewView.translatesAutoresizingMaskIntoConstraints = false

        let player = AVPlayer(url: fileURL)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(playerLayer)
        self.player = player
        self.playerLayer = playerLayer

        // Loop the short clip so the preview never ends on a frozen frame.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEnd(_:)),
            name: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem
        )

        let hourBadge = makePreviewBadge(text: HourSlot.displayText(hourKey: hourKey), systemName: "clock.fill")
        let durationBadge = makePreviewBadge(text: "\(durationSeconds)초", systemName: "video.fill")

        soundButton.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.45)
        soundButton.addTarget(self, action: #selector(soundTapped), for: .touchUpInside)

        previewView.addSubview(hourBadge)
        previewView.addSubview(durationBadge)
        previewView.addSubview(soundButton)

        NSLayoutConstraint.activate([
            hourBadge.topAnchor.constraint(equalTo: previewView.topAnchor, constant: AppTheme.Spacing.m),
            hourBadge.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: AppTheme.Spacing.m),

            durationBadge.topAnchor.constraint(equalTo: previewView.topAnchor, constant: AppTheme.Spacing.m),
            durationBadge.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -AppTheme.Spacing.m),

            soundButton.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -AppTheme.Spacing.m),
            soundButton.bottomAnchor.constraint(equalTo: previewView.bottomAnchor, constant: -AppTheme.Spacing.m)
        ])

        return previewView
    }

    private func makePreviewBadge(text: String, systemName: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        container.layer.cornerRadius = 14
        container.layer.cornerCurve = .continuous
        container.isAccessibilityElement = true
        container.accessibilityLabel = text
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: systemName))
        iconView.tintColor = AppTheme.butter
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)

        let label = UILabel()
        label.text = text
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        label.textColor = .white

        let stackView = UIStackView(arrangedSubviews: [iconView, label])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 5
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 28),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func setupUploadButton() {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.imagePadding = 8
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.roundedFont(.headline, weight: .semibold)
            return attributes
        }
        uploadButton.configuration = configuration
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        uploadButton.addTarget(self, action: #selector(uploadTapped), for: .touchUpInside)
        uploadButton.addAction(UIAction { _ in Haptics.tap() }, for: .touchUpInside)

        uploadButton.configurationUpdateHandler = { [weak self] button in
            guard let self, var configuration = button.configuration else { return }
            let count = self.selectedGroupIDs.count

            configuration.showsActivityIndicator = self.isUploading
            if self.isUploading {
                configuration.title = nil
                configuration.image = nil
            } else if count == 0 {
                configuration.title = "올릴 그룹을 선택해주세요"
                configuration.image = nil
            } else {
                configuration.title = "\(count)개 그룹에 올리기"
                configuration.image = UIImage(systemName: "arrow.up")
            }

            configuration.baseBackgroundColor = AppTheme.neonPink
            configuration.baseForegroundColor = .white
            if !button.isEnabled && !self.isUploading {
                configuration.baseBackgroundColor = AppTheme.cardMuted
                configuration.baseForegroundColor = AppTheme.tertiaryText
            }
            button.configuration = configuration

            let pressed = button.isHighlighted
            UIView.animate(
                withDuration: pressed ? 0.12 : 0.28,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                button.transform = pressed ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    private func setupUploadOverlay() {
        uploadOverlayView.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        uploadOverlayView.isHidden = true
        uploadOverlayView.alpha = 0
        uploadOverlayView.accessibilityViewIsModal = true
        uploadOverlayView.translatesAutoresizingMaskIntoConstraints = false

        let panelView = UIView()
        AppTheme.roundCard(panelView, radius: AppTheme.Radius.large)
        panelView.translatesAutoresizingMaskIntoConstraints = false

        uploadActivityIndicator.color = AppTheme.neonPink

        uploadStatusIconView.tintColor = AppTheme.success
        uploadStatusIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40, weight: .semibold)
        uploadStatusIconView.isHidden = true

        uploadStatusLabel.text = "업로드 준비 중"
        uploadStatusLabel.font = AppTheme.roundedFont(.title3, weight: .bold)
        uploadStatusLabel.adjustsFontForContentSizeCategory = true
        uploadStatusLabel.textColor = AppTheme.text
        uploadStatusLabel.textAlignment = .center
        uploadStatusLabel.numberOfLines = 0

        uploadProgressLabel.text = "잠시만 기다려주세요"
        uploadProgressLabel.font = AppTheme.roundedFont(.subheadline, weight: .medium)
        uploadProgressLabel.adjustsFontForContentSizeCategory = true
        uploadProgressLabel.textColor = AppTheme.secondaryText
        uploadProgressLabel.textAlignment = .center
        uploadProgressLabel.numberOfLines = 0

        uploadProgressView.progressTintColor = AppTheme.neonPink
        uploadProgressView.trackTintColor = AppTheme.cardMuted
        uploadProgressView.progress = 0
        uploadProgressView.isHidden = true
        uploadProgressView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView(arrangedSubviews: [
            uploadActivityIndicator,
            uploadStatusIconView,
            uploadStatusLabel,
            uploadProgressView,
            uploadProgressLabel
        ])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = AppTheme.Spacing.m
        stackView.setCustomSpacing(AppTheme.Spacing.l, after: uploadActivityIndicator)
        stackView.setCustomSpacing(AppTheme.Spacing.l, after: uploadStatusIconView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        uploadOverlayView.addSubview(panelView)
        panelView.addSubview(stackView)

        NSLayoutConstraint.activate([
            panelView.centerXAnchor.constraint(equalTo: uploadOverlayView.centerXAnchor),
            panelView.centerYAnchor.constraint(equalTo: uploadOverlayView.centerYAnchor),
            panelView.leadingAnchor.constraint(equalTo: uploadOverlayView.leadingAnchor, constant: 42),
            panelView.trailingAnchor.constraint(equalTo: uploadOverlayView.trailingAnchor, constant: -42),

            stackView.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 28),
            stackView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 22),
            stackView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -22),
            stackView.bottomAnchor.constraint(equalTo: panelView.bottomAnchor, constant: -28),

            uploadProgressView.widthAnchor.constraint(equalTo: stackView.widthAnchor, multiplier: 0.8)
        ])
    }

    // MARK: - Groups

    private func renderGroups() {
        groupStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        groupRows.removeAll()
        groups.forEach { group in
            let row = UploadGroupSelectionRow(group: group)
            row.setSelected(selectedGroupIDs.contains(group.id), animated: false)
            row.addAction(UIAction { [weak self] _ in
                self?.toggleGroup(group)
            }, for: .touchUpInside)
            groupRows[group.id] = row
            groupStackView.addArrangedSubview(row)
        }
        updateUploadButton()
    }

    private func toggleGroup(_ group: Group) {
        if selectedGroupIDs.contains(group.id) {
            selectedGroupIDs.remove(group.id)
        } else {
            selectedGroupIDs.insert(group.id)
        }
        Haptics.selection()
        groupRows[group.id]?.setSelected(selectedGroupIDs.contains(group.id), animated: true)
        updateUploadButton()
    }

    @objc private func selectAllTapped() {
        let allIDs = Set(groups.map(\.id))
        selectedGroupIDs = selectedGroupIDs == allIDs ? [] : allIDs
        Haptics.selection()
        groups.forEach { group in
            groupRows[group.id]?.setSelected(selectedGroupIDs.contains(group.id), animated: true)
        }
        updateUploadButton()
    }

    private func updateUploadButton() {
        let count = selectedGroupIDs.count
        uploadButton.isEnabled = count > 0 && !isUploading
        uploadButton.setNeedsUpdateConfiguration()

        selectionCountLabel.text = count > 0 ? "\(count)/\(groups.count)" : nil
        selectAllButton.configuration?.title = count == groups.count ? "선택 해제" : "전체 선택"
    }

    // MARK: - Preview

    @objc private func playerItemDidPlayToEnd(_ notification: Notification) {
        player?.seek(to: .zero)
        player?.play()
    }

    @objc private func soundTapped() {
        includesAudio.toggle()
        player?.isMuted = !includesAudio
        updateSoundButton()
        ToastView.show(message: includesAudio ? "소리와 함께 올려요" : "소리 없이 올려요", in: view)
    }

    private func updateSoundButton() {
        var configuration = soundButton.configuration
        configuration?.image = UIImage(systemName: includesAudio ? "speaker.wave.2.fill" : "speaker.slash.fill")
        configuration?.baseForegroundColor = includesAudio ? .white : AppTheme.butter
        soundButton.configuration = configuration
        soundButton.accessibilityValue = includesAudio ? "켜짐" : "꺼짐"
        player?.isMuted = !includesAudio
    }

    // MARK: - Upload

    @objc private func uploadTapped() {
        let selectedGroups = groups.filter { selectedGroupIDs.contains($0.id) }
        guard !selectedGroups.isEmpty else { return }

        isUploading = true
        showUploadOverlay(status: includesAudio ? "업로드 준비 중" : "무음 영상 준비 중", progress: "\(selectedGroups.count)개 그룹에 보낼게요")

        prepareVideoForUpload { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                self.hideUploadOverlay()
                self.isUploading = false
                Haptics.error()
                self.showAlert(title: "업로드 준비 실패", message: error.localizedDescription)
            case .success(let uploadFileURL):
                self.upload(uploadFileURL: uploadFileURL, to: selectedGroups)
            }
        }
    }

    private func prepareVideoForUpload(completion: @escaping (Result<URL, Error>) -> Void) {
        guard !includesAudio else {
            completion(.success(fileURL))
            return
        }

        if let mutedCopyURL {
            completion(.success(mutedCopyURL))
            return
        }

        videoAudioService.makeMutedCopy(from: fileURL) { [weak self] result in
            if case .success(let url) = result {
                self?.mutedCopyURL = url
            }
            completion(result)
        }
    }

    /// Recorded clips live in the temp directory; remove them once they're no longer needed.
    private func removeTemporaryFiles() {
        [fileURL, mutedCopyURL].compactMap { $0 }.forEach {
            try? FileManager.default.removeItem(at: $0)
        }
        mutedCopyURL = nil
    }

    private func upload(uploadFileURL: URL, to selectedGroups: [Group]) {
        let dispatchGroup = DispatchGroup()
        var uploadErrors: [String] = []
        var completedCount = 0
        showUploadOverlay(status: "업로드 중", progress: "0 / \(selectedGroups.count)")
        uploadProgressView.isHidden = false
        uploadProgressView.setProgress(0, animated: false)

        selectedGroups.forEach { group in
            dispatchGroup.enter()
            postUploadService.uploadPost(
                fileURL: uploadFileURL,
                group: group,
                caption: "",
                durationSeconds: durationSeconds,
                hourKey: hourKey,
                includesAudio: includesAudio
            ) { result in
                DispatchQueue.main.async {
                    completedCount += 1
                    self.uploadProgressLabel.text = "\(completedCount) / \(selectedGroups.count)"
                    self.uploadProgressView.setProgress(Float(completedCount) / Float(selectedGroups.count), animated: true)

                    switch result {
                    case .success:
                        // Deselect so a retry after partial failure doesn't post twice.
                        self.selectedGroupIDs.remove(group.id)
                    case .failure(let error):
                        uploadErrors.append("\(group.name): \(error.localizedDescription)")
                    }

                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }

            if uploadErrors.isEmpty {
                self.player?.pause()
                self.removeTemporaryFiles()
                self.showUploadSucceeded(
                    message: selectedGroups.count == 1 ? "그룹 피드에서 바로 확인해볼게요" : "로그 화면에서 바로 확인해볼게요"
                )

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                    guard let presentingViewController = self.presentingViewController else {
                        self.dismiss(animated: true)
                        return
                    }

                    self.dismiss(animated: true) {
                        if selectedGroups.count == 1, let group = selectedGroups.first {
                            AppRouter.showGroupFeed(from: presentingViewController, group: group)
                        } else {
                            AppRouter.showLog(from: presentingViewController)
                        }
                    }
                }
            } else {
                self.hideUploadOverlay()
                self.isUploading = false
                self.renderGroups()
                Haptics.error()
                let succeededCount = selectedGroups.count - uploadErrors.count
                let summary = succeededCount > 0
                    ? "\(succeededCount)개 그룹에는 올렸어요. 실패한 그룹만 다시 선택되어 있어요.\n\n"
                    : ""
                self.showAlert(title: "일부 업로드 실패", message: summary + uploadErrors.joined(separator: "\n"))
            }
        }
    }

    private func showUploadSucceeded(message: String) {
        uploadActivityIndicator.stopAnimating()
        uploadActivityIndicator.isHidden = true
        uploadProgressView.isHidden = true
        uploadStatusIconView.isHidden = false
        uploadStatusLabel.text = "업로드 완료"
        uploadProgressLabel.text = message
        uploadStatusIconView.addSymbolEffect(.bounce)
        Haptics.success()
        UIAccessibility.post(notification: .announcement, argument: "업로드 완료")
    }

    private func showUploadOverlay(status: String, progress: String) {
        uploadStatusLabel.text = status
        uploadProgressLabel.text = progress
        uploadStatusIconView.isHidden = true
        uploadActivityIndicator.isHidden = false
        uploadOverlayView.isHidden = false
        uploadActivityIndicator.startAnimating()

        UIView.animate(withDuration: 0.18) {
            self.uploadOverlayView.alpha = 1
        }
    }

    private func hideUploadOverlay() {
        uploadActivityIndicator.stopAnimating()

        UIView.animate(withDuration: 0.18) {
            self.uploadOverlayView.alpha = 0
        } completion: { _ in
            self.uploadOverlayView.isHidden = true
            self.uploadProgressView.isHidden = true
        }
    }

    @objc private func closeTapped() {
        player?.pause()
        removeTemporaryFiles()
        dismiss(animated: true)
    }
}

// MARK: - Row

/// Selectable group card: avatar, name, member count and a trailing check circle.
private final class UploadGroupSelectionRow: PressableControl {
    private let groupName: String
    private let checkImageView = UIImageView()

    init(group: Group) {
        groupName = group.name
        super.init(frame: .zero)
        setup(group: group)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(group: Group) {
        AppTheme.roundCard(self, radius: AppTheme.Radius.medium)
        isAccessibilityElement = true
        accessibilityLabel = "\(group.name), 멤버 \(group.memberIDs.count)명"

        let avatarLabel = FeedGroupComponents.makeGroupTile(name: group.name, id: group.id, size: 44)

        let nameLabel = UILabel()
        nameLabel.text = group.name
        nameLabel.font = AppTheme.roundedFont(.headline, weight: .bold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = AppTheme.text

        let memberLabel = UILabel()
        memberLabel.text = "멤버 \(group.memberIDs.count)명"
        memberLabel.font = .preferredFont(forTextStyle: .subheadline)
        memberLabel.adjustsFontForContentSizeCategory = true
        memberLabel.textColor = AppTheme.secondaryText

        let textStackView = UIStackView(arrangedSubviews: [nameLabel, memberLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 2

        checkImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        checkImageView.contentMode = .scaleAspectFit
        checkImageView.setContentHuggingPriority(.required, for: .horizontal)

        let stackView = UIStackView(arrangedSubviews: [avatarLabel, textStackView, checkImageView])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = AppTheme.Spacing.m + 2
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 76),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: AppTheme.Spacing.m),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -AppTheme.Spacing.m),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AppTheme.Spacing.l),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AppTheme.Spacing.l)
        ])
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        isSelected = selected
        accessibilityTraits = selected ? [.button, .selected] : .button

        let image = UIImage(systemName: selected ? "checkmark.circle.fill" : "circle")
        if animated, let image {
            checkImageView.setSymbolImage(image, contentTransition: .replace)
        } else {
            checkImageView.image = image
        }

        let changes = {
            self.checkImageView.tintColor = selected ? AppTheme.neonPink : AppTheme.tertiaryText
            self.backgroundColor = selected ? AppTheme.neonPink.withAlphaComponent(0.1) : AppTheme.card
            self.layer.borderColor = (selected ? AppTheme.neonPink.withAlphaComponent(0.7) : AppTheme.separator).cgColor
            self.layer.borderWidth = selected ? 1.5 : 1
        }

        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: changes)
        } else {
            changes()
        }
    }
}

/// Non-interactive vertical gradient (used to fade content under the sticky footer).
private final class UploadFadeView: UIView {
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
