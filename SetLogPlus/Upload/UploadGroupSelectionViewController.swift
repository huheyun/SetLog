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
    private let groupStackView = UIStackView()
    private let uploadButton = IconCircleButton(systemName: "arrow.up")
    private let soundButton = IconCircleButton(systemName: "speaker.wave.2.fill")
    private let uploadOverlayView = UIView()
    private let uploadStatusLabel = UILabel()
    private let uploadProgressLabel = UILabel()
    private let uploadActivityIndicator = UIActivityIndicatorView(style: .large)
    private var player: AVPlayer?
    private weak var playerLayer: AVPlayerLayer?

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

    private func setupLayout() {
        let previewView = UIView()
        previewView.backgroundColor = AppTheme.cardMuted
        previewView.layer.cornerRadius = 24
        previewView.clipsToBounds = true
        previewView.translatesAutoresizingMaskIntoConstraints = false

        let player = AVPlayer(url: fileURL)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(playerLayer)
        self.player = player
        self.playerLayer = playerLayer

        let closeButton = IconCircleButton(systemName: "xmark")
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        uploadButton.addTarget(self, action: #selector(uploadTapped), for: .touchUpInside)
        uploadButton.configuration?.baseForegroundColor = AppTheme.secondaryText
        soundButton.addTarget(self, action: #selector(soundTapped), for: .touchUpInside)

        let timeLabel = UILabel()
        timeLabel.text = HourSlot.displayText()
        timeLabel.font = .systemFont(ofSize: 40, weight: .black)
        timeLabel.textColor = .white
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "보낼 로그방:"
        titleLabel.font = .systemFont(ofSize: 24, weight: .black)
        titleLabel.textColor = AppTheme.secondaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        groupStackView.axis = .vertical
        groupStackView.spacing = 12
        groupStackView.translatesAutoresizingMaskIntoConstraints = false
        setupUploadOverlay()

        view.addSubview(previewView)
        previewView.addSubview(closeButton)
        previewView.addSubview(uploadButton)
        previewView.addSubview(timeLabel)
        previewView.addSubview(soundButton)
        view.addSubview(titleLabel)
        view.addSubview(scrollView)
        view.addSubview(uploadOverlayView)
        scrollView.addSubview(groupStackView)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            previewView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            previewView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            previewView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.28),

            closeButton.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 14),
            closeButton.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 14),

            uploadButton.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 14),
            uploadButton.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -14),

            timeLabel.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: previewView.centerYAnchor, constant: -4),

            soundButton.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 20),
            soundButton.bottomAnchor.constraint(equalTo: previewView.bottomAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),

            groupStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            groupStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            groupStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            groupStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            groupStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            uploadOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            uploadOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            uploadOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            uploadOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        updateSoundButton()
        player.play()
    }

    private func setupUploadOverlay() {
        uploadOverlayView.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        uploadOverlayView.isHidden = true
        uploadOverlayView.alpha = 0
        uploadOverlayView.translatesAutoresizingMaskIntoConstraints = false

        let panelView = UIView()
        panelView.backgroundColor = AppTheme.card
        panelView.layer.cornerRadius = 22
        panelView.translatesAutoresizingMaskIntoConstraints = false

        uploadActivityIndicator.color = AppTheme.mint
        uploadActivityIndicator.translatesAutoresizingMaskIntoConstraints = false

        uploadStatusLabel.text = "업로드 준비 중"
        uploadStatusLabel.font = .systemFont(ofSize: 20, weight: .black)
        uploadStatusLabel.textColor = AppTheme.text
        uploadStatusLabel.textAlignment = .center

        uploadProgressLabel.text = "잠시만 기다려주세요"
        uploadProgressLabel.font = .preferredFont(forTextStyle: .subheadline)
        uploadProgressLabel.textColor = AppTheme.secondaryText
        uploadProgressLabel.textAlignment = .center

        let stackView = UIStackView(arrangedSubviews: [uploadActivityIndicator, uploadStatusLabel, uploadProgressLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 14
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
            stackView.bottomAnchor.constraint(equalTo: panelView.bottomAnchor, constant: -28)
        ])
    }

    private func renderGroups() {
        groupStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        groups.forEach { group in
            groupStackView.addArrangedSubview(makeGroupRow(group))
        }
        updateUploadButton()
    }

    private func makeGroupRow(_ group: Group) -> UIView {
        let row = UIControl()
        row.backgroundColor = AppTheme.card
        row.layer.cornerRadius = 22
        row.clipsToBounds = true
        row.addAction(UIAction { [weak self] _ in
            self?.toggleGroup(group)
        }, for: .touchUpInside)

        let selected = selectedGroupIDs.contains(group.id)
        let checkImageView = UIImageView(image: UIImage(systemName: selected ? "checkmark.circle.fill" : "circle"))
        checkImageView.tintColor = selected ? AppTheme.mint : UIColor.white.withAlphaComponent(0.22)
        checkImageView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = group.name
        nameLabel.font = .systemFont(ofSize: 22, weight: .black)
        nameLabel.textColor = AppTheme.text

        let memberLabel = UILabel()
        memberLabel.text = "멤버 \(group.memberIDs.count)명"
        memberLabel.font = .preferredFont(forTextStyle: .subheadline)
        memberLabel.textColor = AppTheme.secondaryText

        let textStackView = UIStackView(arrangedSubviews: [nameLabel, memberLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 4
        textStackView.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(checkImageView)
        row.addSubview(textStackView)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 88),

            checkImageView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            checkImageView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            checkImageView.widthAnchor.constraint(equalToConstant: 34),
            checkImageView.heightAnchor.constraint(equalToConstant: 34),

            textStackView.leadingAnchor.constraint(equalTo: checkImageView.trailingAnchor, constant: 18),
            textStackView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -18),
            textStackView.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func toggleGroup(_ group: Group) {
        if selectedGroupIDs.contains(group.id) {
            selectedGroupIDs.remove(group.id)
        } else {
            selectedGroupIDs.insert(group.id)
        }
        renderGroups()
    }

    private func updateUploadButton() {
        let isEnabled = !selectedGroupIDs.isEmpty
        uploadButton.isEnabled = isEnabled
        uploadButton.configuration?.baseForegroundColor = isEnabled ? AppTheme.mint : AppTheme.secondaryText
    }

    @objc private func soundTapped() {
        includesAudio.toggle()
        player?.isMuted = !includesAudio
        updateSoundButton()
    }

    private func updateSoundButton() {
        var configuration = soundButton.configuration
        configuration?.image = UIImage(systemName: includesAudio ? "speaker.wave.2.fill" : "speaker.slash.fill")
        configuration?.baseForegroundColor = includesAudio ? .white : AppTheme.secondaryText
        soundButton.configuration = configuration
        player?.isMuted = !includesAudio
    }

    @objc private func uploadTapped() {
        let selectedGroups = groups.filter { selectedGroupIDs.contains($0.id) }
        guard !selectedGroups.isEmpty else { return }

        uploadButton.isEnabled = false
        uploadButton.configuration?.baseForegroundColor = AppTheme.secondaryText
        showUploadOverlay(status: includesAudio ? "업로드 준비 중" : "무음 영상 준비 중", progress: "\(selectedGroups.count)개 그룹에 보낼게요")

        prepareVideoForUpload { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                self.hideUploadOverlay()
                self.uploadButton.isEnabled = true
                self.updateUploadButton()
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

        videoAudioService.makeMutedCopy(from: fileURL, completion: completion)
    }

    private func upload(uploadFileURL: URL, to selectedGroups: [Group]) {
        let dispatchGroup = DispatchGroup()
        var uploadErrors: [String] = []
        var completedCount = 0
        showUploadOverlay(status: "업로드 중", progress: "0 / \(selectedGroups.count)")

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

                    if case .failure(let error) = result {
                        uploadErrors.append("\(group.name): \(error.localizedDescription)")
                    }

                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }

            if uploadErrors.isEmpty {
                self.uploadActivityIndicator.stopAnimating()
                self.uploadStatusLabel.text = "업로드 완료"
                self.uploadProgressLabel.text = selectedGroups.count == 1 ? "그룹 피드에서 바로 확인해볼게요" : "로그 화면에서 바로 확인해볼게요"

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
                self.uploadButton.isEnabled = true
                self.updateUploadButton()
                self.showAlert(title: "일부 업로드 실패", message: uploadErrors.joined(separator: "\n"))
            }
        }
    }

    private func showUploadOverlay(status: String, progress: String) {
        uploadStatusLabel.text = status
        uploadProgressLabel.text = progress
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
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            completion?()
        })
        present(alertController, animated: true)
    }
}
