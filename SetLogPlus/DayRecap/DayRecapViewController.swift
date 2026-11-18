import AVFoundation
import Photos
import UIKit

/// "하루 영상": stitches a group's clips for one day into a single video,
/// previews it on loop, and lets the user save it to Photos or share it.
///
/// Presents itself full screen; just `present(DayRecapViewController(...), animated: true)`.
final class DayRecapViewController: UIViewController {
    private enum State {
        case preparing(completed: Int, total: Int)
        case composing
        case ready(URL)
        case empty
        case failed
    }

    private let group: Group
    private let clips: [DayRecapService.Clip]
    private let date: Date
    private let service: DayRecapService

    private var recapTask: Task<Void, Never>?
    private var recapURL: URL?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var isMuted = false

    private let closeButton = IconCircleButton(systemName: "xmark", accessibilityLabel: "닫기")
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let contentGuide = UILayoutGuide()
    private let previewContainer = UIView()
    private let playerView = DayRecapPlayerView()
    private let muteButton = IconCircleButton(systemName: "speaker.wave.2.fill", accessibilityLabel: "소리 끄기", size: 36)
    private let progressStack = UIStackView()
    private let progressLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private var stateCardView: UIView?
    private let saveButton = PrimaryButton(title: "사진 앱에 저장")
    private let shareButton = PrimaryButton(title: "공유", style: .secondary)

    init(group: Group, posts: [Post], members: [GroupMember], date: Date) {
        self.group = group
        self.date = date

        let namesByID = Dictionary(members.map { ($0.uid, $0.displayName) }, uniquingKeysWith: { first, _ in first })
        self.clips = posts
            .sorted { first, second in
                if first.hourKey != second.hourKey {
                    return first.hourKey < second.hourKey
                }
                return (first.createdAt ?? .distantPast) < (second.createdAt ?? .distantPast)
            }
            .map { post in
                let memberName = namesByID[post.authorID].flatMap { $0.isEmpty ? nil : $0 }
                let postName = post.authorName.isEmpty ? nil : post.authorName
                return DayRecapService.Clip(
                    post: post,
                    authorName: memberName ?? postName ?? "멤버",
                    hourText: HourSlot.displayText(hourKey: post.hourKey)
                )
            }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DayRecap-\(UUID().uuidString)", isDirectory: true)
        self.service = DayRecapService(workDirectory: directory)

        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // Safety net in case the screen goes away without viewDidDisappear (temp files only).
        try? FileManager.default.removeItem(at: service.workDirectory)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        startRecap()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        player?.play()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil {
            tearDown()
        } else {
            player?.pause()
        }
    }

    // MARK: - Layout

    private func setupLayout() {
        view.backgroundColor = AppTheme.background

        titleLabel.text = "하루 영상"
        titleLabel.font = AppTheme.titleFont
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.text

        subtitleLabel.text = "\(Self.dateText(for: date)) · \(group.name)"
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = AppTheme.secondaryText
        subtitleLabel.numberOfLines = 2

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = AppTheme.Spacing.xs

        closeButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .touchUpInside)

        let headerStack = UIStackView(arrangedSubviews: [titleStack, closeButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .top
        headerStack.spacing = AppTheme.Spacing.m
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        // Preview: 9:16 card that fits the space between the header and the buttons.
        AppTheme.roundCard(previewContainer, radius: AppTheme.Radius.large)
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.isHidden = true
        previewContainer.addSubview(playerView)

        muteButton.isHidden = true
        muteButton.addAction(UIAction { [weak self] _ in
            self?.toggleMute()
        }, for: .touchUpInside)
        previewContainer.addSubview(muteButton)

        progressLabel.font = AppTheme.roundedFont(.subheadline, weight: .semibold)
        progressLabel.adjustsFontForContentSizeCategory = true
        progressLabel.textColor = AppTheme.secondaryText
        progressLabel.textAlignment = .center
        progressLabel.numberOfLines = 0

        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = AppTheme.secondaryText
        indicator.startAnimating()

        progressView.progressTintColor = AppTheme.neonPink
        progressView.trackTintColor = AppTheme.cardMuted
        progressView.translatesAutoresizingMaskIntoConstraints = false

        progressStack.addArrangedSubview(indicator)
        progressStack.addArrangedSubview(progressLabel)
        progressStack.addArrangedSubview(progressView)
        progressStack.axis = .vertical
        progressStack.alignment = .center
        progressStack.spacing = AppTheme.Spacing.m
        progressStack.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(progressStack)

        saveButton.isEnabled = false
        shareButton.isEnabled = false
        saveButton.addAction(UIAction { [weak self] _ in
            self?.saveToPhotos()
        }, for: .touchUpInside)
        shareButton.addAction(UIAction { [weak self] _ in
            self?.share()
        }, for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [shareButton, saveButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = AppTheme.Spacing.m
        buttonStack.distribution = .fill
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        shareButton.setContentHuggingPriority(.required, for: .horizontal)
        saveButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

        view.addSubview(headerStack)
        view.addSubview(previewContainer)
        view.addSubview(buttonStack)
        view.addLayoutGuide(contentGuide)

        let safeArea = view.safeAreaLayoutGuide
        let fillHeight = previewContainer.heightAnchor.constraint(equalTo: contentGuide.heightAnchor)
        fillHeight.priority = .defaultHigh
        let fillWidth = previewContainer.widthAnchor.constraint(equalTo: contentGuide.widthAnchor)
        fillWidth.priority = .defaultHigh - 1

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: AppTheme.Spacing.l),
            headerStack.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: AppTheme.Spacing.screen),
            headerStack.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -AppTheme.Spacing.screen),

            contentGuide.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: AppTheme.Spacing.l),
            contentGuide.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: AppTheme.Spacing.screen),
            contentGuide.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -AppTheme.Spacing.screen),
            contentGuide.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -AppTheme.Spacing.l),

            previewContainer.widthAnchor.constraint(equalTo: previewContainer.heightAnchor, multiplier: 9.0 / 16.0),
            previewContainer.centerXAnchor.constraint(equalTo: contentGuide.centerXAnchor),
            previewContainer.centerYAnchor.constraint(equalTo: contentGuide.centerYAnchor),
            previewContainer.heightAnchor.constraint(lessThanOrEqualTo: contentGuide.heightAnchor),
            previewContainer.widthAnchor.constraint(lessThanOrEqualTo: contentGuide.widthAnchor),
            fillHeight,
            fillWidth,

            playerView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),

            muteButton.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: AppTheme.Spacing.m),
            muteButton.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -AppTheme.Spacing.m),

            progressStack.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            progressStack.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: AppTheme.Spacing.xl),
            progressStack.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -AppTheme.Spacing.xl),
            progressView.widthAnchor.constraint(equalTo: progressStack.widthAnchor, multiplier: 0.8),

            buttonStack.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: AppTheme.Spacing.screen),
            buttonStack.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -AppTheme.Spacing.screen),
            buttonStack.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -AppTheme.Spacing.l),
            shareButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 110)
        ])
    }

    // MARK: - Recap

    private func startRecap() {
        guard !clips.isEmpty else {
            apply(.empty)
            return
        }

        recapTask?.cancel()
        apply(.preparing(completed: 0, total: clips.count))

        recapTask = Task { [weak self, service, clips] in
            do {
                let output = try await service.makeRecap(clips: clips) { progress in
                    switch progress {
                    case let .downloading(completed, total):
                        self?.apply(.preparing(completed: completed, total: total))
                    case .composing:
                        self?.apply(.composing)
                    }
                }
                guard let self, !Task.isCancelled else { return }
                self.apply(.ready(output.url))
                if output.failedCount > 0 {
                    ToastView.show(message: "일부 영상을 불러오지 못했어요", style: .error, in: self.view)
                }
            } catch {
                guard let self, !Task.isCancelled, !(error is CancellationError) else { return }
                self.apply(.failed)
            }
        }
    }

    private func apply(_ state: State) {
        stateCardView?.removeFromSuperview()
        stateCardView = nil

        switch state {
        case let .preparing(completed, total):
            showProgress(text: "영상 준비 중 \(completed)/\(total)", fraction: total > 0 ? Float(completed) / Float(total) * 0.7 : 0)
            setActionsEnabled(false)
        case .composing:
            showProgress(text: "하루 영상 만드는 중…", fraction: 0.85)
            setActionsEnabled(false)
        case let .ready(url):
            previewContainer.isHidden = false
            progressStack.isHidden = true
            recapURL = url
            startPlayback(url: url)
            setActionsEnabled(true)
            Haptics.success()
        case .empty:
            showStateCard(InfoCardView(
                title: "이 날 올라온 영상이 없어요",
                message: "멤버들이 영상을 올리면 하루 영상을 만들 수 있어요.",
                systemImageName: "film.stack"
            ))
        case .failed:
            showStateCard(InfoCardView(
                title: "영상을 만들지 못했어요",
                message: "네트워크 상태를 확인하고 다시 시도해 주세요.",
                systemImageName: "exclamationmark.triangle",
                actionTitle: "다시 시도",
                action: { [weak self] in
                    self?.startRecap()
                }
            ))
        }
    }

    private func showProgress(text: String, fraction: Float) {
        previewContainer.isHidden = false
        progressStack.isHidden = false
        playerView.isHidden = true
        muteButton.isHidden = true
        progressLabel.text = text
        progressView.setProgress(fraction, animated: true)
        progressStack.accessibilityLabel = text
    }

    private func showStateCard(_ card: UIView) {
        stopPlayback()
        previewContainer.isHidden = true
        setActionsEnabled(false)

        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        NSLayoutConstraint.activate([
            card.centerYAnchor.constraint(equalTo: contentGuide.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            card.heightAnchor.constraint(lessThanOrEqualTo: contentGuide.heightAnchor)
        ])
        stateCardView = card
    }

    private func setActionsEnabled(_ isEnabled: Bool) {
        saveButton.isEnabled = isEnabled
        shareButton.isEnabled = isEnabled
    }

    // MARK: - Playback

    private func startPlayback(url: URL) {
        stopPlayback()
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = isMuted
        looper = AVPlayerLooper(player: player, templateItem: item)
        self.player = player
        playerView.playerLayer.player = player
        playerView.isHidden = false
        muteButton.isHidden = false
        player.play()
    }

    private func stopPlayback() {
        player?.pause()
        looper?.disableLooping()
        looper = nil
        playerView.playerLayer.player = nil
        player = nil
    }

    private func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
        muteButton.setSymbol(isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
        muteButton.accessibilityLabel = isMuted ? "소리 켜기" : "소리 끄기"
    }

    private func tearDown() {
        recapTask?.cancel()
        recapTask = nil
        stopPlayback()
        service.cleanUp()
    }

    // MARK: - Actions

    private func saveToPhotos() {
        guard let url = recapURL else { return }
        saveButton.isLoading = true

        Task { [weak self] in
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                self?.saveButton.isLoading = false
                self?.showAlert(
                    title: "사진 접근 권한이 필요해요",
                    message: "설정 > 개인정보 보호 > 사진에서 SetLog+의 사진 추가를 허용해 주세요."
                )
                return
            }

            do {
                try await PHPhotoLibrary.shared().performChanges {
                    _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
                guard let self else { return }
                self.saveButton.isLoading = false
                ToastView.show(message: "사진 앱에 저장했어요", style: .success, in: self.view)
            } catch {
                guard let self else { return }
                self.saveButton.isLoading = false
                ToastView.show(message: "저장하지 못했어요", style: .error, in: self.view)
            }
        }
    }

    private func share() {
        guard let url = recapURL else { return }
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(activityController, animated: true)
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter
    }()

    private static func dateText(for date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

/// Plain view backed by an `AVPlayerLayer` (aspect-fill).
private final class DayRecapPlayerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
        isAccessibilityElement = true
        accessibilityLabel = "하루 영상 미리보기"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
