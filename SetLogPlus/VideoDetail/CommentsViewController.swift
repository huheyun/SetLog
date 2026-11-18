import FirebaseFirestore
import UIKit

/// Bottom sheet listing a post's comments with a keyboard-pinned input bar.
final class CommentsViewController: UIViewController {
    private let post: Post
    private let commentRepository = CommentRepository()
    private var commentsListener: ListenerRegistration?
    private var comments: [PostComment]
    private var isSending = false
    private var shouldScrollToBottomOnNextUpdate = false

    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateView = UIStackView()
    private let inputContainerView = UIView()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let counterLabel = UILabel()
    private let sendButton = UIButton(type: .system)
    private var textViewHeightConstraint: NSLayoutConstraint?

    private static let minimumInputHeight: CGFloat = 38
    private static let maximumInputHeight: CGFloat = 110
    private static let counterThreshold = PostComment.maxLength - 50

    init(post: Post, initialComments: [PostComment] = []) {
        self.post = post
        self.comments = initialComments
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = AppTheme.Radius.large
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        commentsListener?.remove()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = AppTheme.card
        setupLayout()
        reloadComments()
        startListening()
    }

    // MARK: - Layout

    private func setupLayout() {
        titleLabel.font = AppTheme.roundedFont(.headline, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.text
        titleLabel.textAlignment = .center
        titleLabel.accessibilityTraits = .header
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let headerSeparator = UIView()
        headerSeparator.backgroundColor = AppTheme.separator
        headerSeparator.translatesAutoresizingMaskIntoConstraints = false

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.alwaysBounceVertical = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CommentCell.self, forCellReuseIdentifier: CommentCell.reuseIdentifier)
        tableView.contentInset = UIEdgeInsets(top: AppTheme.Spacing.s, left: 0, bottom: AppTheme.Spacing.s, right: 0)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        setupEmptyState()
        setupInputBar()

        view.addSubview(titleLabel)
        view.addSubview(headerSeparator)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(inputContainerView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: AppTheme.Spacing.xl),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.Spacing.screen),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.Spacing.screen),

            headerSeparator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppTheme.Spacing.m),
            headerSeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerSeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerSeparator.heightAnchor.constraint(equalToConstant: 1),

            tableView.topAnchor.constraint(equalTo: headerSeparator.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor),

            emptyStateView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyStateView.topAnchor.constraint(equalTo: tableView.topAnchor, constant: AppTheme.Spacing.xxl),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppTheme.Spacing.screen),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppTheme.Spacing.screen),

            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
    }

    private func setupEmptyState() {
        let iconView = UIImageView(image: UIImage(systemName: "bubble.left.and.bubble.right"))
        iconView.tintColor = AppTheme.tertiaryText
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = "첫 댓글을 남겨보세요"
        label.font = AppTheme.roundedFont(.subheadline, weight: .semibold)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = AppTheme.secondaryText
        label.textAlignment = .center
        label.numberOfLines = 0

        emptyStateView.addArrangedSubview(iconView)
        emptyStateView.addArrangedSubview(label)
        emptyStateView.axis = .vertical
        emptyStateView.alignment = .center
        emptyStateView.spacing = AppTheme.Spacing.m
        emptyStateView.isHidden = true
        emptyStateView.isUserInteractionEnabled = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupInputBar() {
        inputContainerView.backgroundColor = AppTheme.card
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false

        let topSeparator = UIView()
        topSeparator.backgroundColor = AppTheme.separator
        topSeparator.translatesAutoresizingMaskIntoConstraints = false

        let fieldBackgroundView = UIView()
        fieldBackgroundView.backgroundColor = AppTheme.cardMuted
        fieldBackgroundView.layer.cornerRadius = Self.minimumInputHeight / 2 + 1
        fieldBackgroundView.layer.cornerCurve = .continuous
        fieldBackgroundView.layer.borderWidth = 1
        fieldBackgroundView.layer.borderColor = AppTheme.separator.cgColor
        fieldBackgroundView.translatesAutoresizingMaskIntoConstraints = false

        textView.backgroundColor = .clear
        textView.textColor = AppTheme.text
        textView.tintColor = AppTheme.neonPink
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        textView.isScrollEnabled = false
        textView.delegate = self
        textView.accessibilityLabel = "댓글 입력"
        textView.translatesAutoresizingMaskIntoConstraints = false

        placeholderLabel.text = "댓글 달기..."
        placeholderLabel.font = .preferredFont(forTextStyle: .body)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = AppTheme.tertiaryText
        placeholderLabel.isAccessibilityElement = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        counterLabel.font = AppTheme.roundedFont(.caption2, weight: .semibold)
        counterLabel.adjustsFontForContentSizeCategory = true
        counterLabel.textColor = AppTheme.tertiaryText
        counterLabel.textAlignment = .right
        counterLabel.isHidden = true
        counterLabel.translatesAutoresizingMaskIntoConstraints = false

        var sendConfiguration = UIButton.Configuration.filled()
        sendConfiguration.image = UIImage(systemName: "arrow.up")
        sendConfiguration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        sendConfiguration.cornerStyle = .capsule
        sendButton.configuration = sendConfiguration
        sendButton.configurationUpdateHandler = { button in
            var configuration = button.configuration
            configuration?.baseBackgroundColor = button.isEnabled ? AppTheme.neonPink : AppTheme.cardMuted
            configuration?.baseForegroundColor = button.isEnabled ? .black : AppTheme.tertiaryText
            button.configuration = configuration
        }
        sendButton.accessibilityLabel = "댓글 보내기"
        sendButton.isEnabled = false
        sendButton.enablePressAnimation()
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        inputContainerView.addSubview(topSeparator)
        inputContainerView.addSubview(fieldBackgroundView)
        fieldBackgroundView.addSubview(textView)
        fieldBackgroundView.addSubview(placeholderLabel)
        inputContainerView.addSubview(counterLabel)
        inputContainerView.addSubview(sendButton)

        let heightConstraint = textView.heightAnchor.constraint(equalToConstant: Self.minimumInputHeight)
        textViewHeightConstraint = heightConstraint

        let horizontalMargin = AppTheme.Spacing.l

        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: inputContainerView.topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor),
            topSeparator.heightAnchor.constraint(equalToConstant: 1),

            fieldBackgroundView.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: AppTheme.Spacing.s + 2),
            fieldBackgroundView.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: horizontalMargin),
            fieldBackgroundView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -AppTheme.Spacing.s),

            textView.topAnchor.constraint(equalTo: fieldBackgroundView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: fieldBackgroundView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: fieldBackgroundView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: fieldBackgroundView.bottomAnchor),
            heightConstraint,

            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 15),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor, constant: -10),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8),

            counterLabel.topAnchor.constraint(equalTo: fieldBackgroundView.bottomAnchor, constant: AppTheme.Spacing.xs),
            counterLabel.trailingAnchor.constraint(equalTo: fieldBackgroundView.trailingAnchor, constant: -AppTheme.Spacing.s),

            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -horizontalMargin),
            sendButton.bottomAnchor.constraint(equalTo: fieldBackgroundView.bottomAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: Self.minimumInputHeight),
            sendButton.heightAnchor.constraint(equalToConstant: Self.minimumInputHeight)
        ])

        // The counter only takes vertical space while it's visible.
        let bottomWithCounter = counterLabel.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -AppTheme.Spacing.s)
        let bottomWithoutCounter = fieldBackgroundView.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -(AppTheme.Spacing.s + 2))
        bottomWithCounter.priority = .defaultHigh
        bottomWithoutCounter.priority = .defaultHigh
        counterBottomConstraints = (withCounter: bottomWithCounter, withoutCounter: bottomWithoutCounter)
        bottomWithoutCounter.isActive = true
    }

    private var counterBottomConstraints: (withCounter: NSLayoutConstraint, withoutCounter: NSLayoutConstraint)?

    // MARK: - Data

    private func startListening() {
        commentsListener = commentRepository.listenComments(postID: post.id) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let comments):
                let previousCount = self.comments.count
                self.comments = comments
                self.reloadComments()
                if self.shouldScrollToBottomOnNextUpdate, comments.count > previousCount {
                    self.shouldScrollToBottomOnNextUpdate = false
                    self.scrollToBottom(animated: true)
                }
            case .failure(let error):
                ToastView.show(message: "댓글을 불러오지 못했어요: \(error.localizedDescription)", style: .error, in: self.view)
            }
        }
    }

    private func reloadComments() {
        titleLabel.text = comments.isEmpty ? "댓글" : "댓글 \(comments.count)"
        emptyStateView.isHidden = !comments.isEmpty
        tableView.reloadData()
    }

    private func scrollToBottom(animated: Bool) {
        guard !comments.isEmpty else { return }
        tableView.scrollToRow(at: IndexPath(row: comments.count - 1, section: 0), at: .bottom, animated: animated)
    }

    private func canDelete(_ comment: PostComment) -> Bool {
        guard let currentUserID = AuthService.shared.currentUserID else { return false }
        return comment.authorID == currentUserID || post.authorID == currentUserID
    }

    private func deleteComment(_ comment: PostComment) {
        commentRepository.deleteComment(postID: post.id, commentID: comment.id) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                Haptics.success()
            case .failure(let error):
                ToastView.show(message: "댓글 삭제 실패: \(error.localizedDescription)", style: .error, in: self.view)
            }
        }
    }

    // MARK: - Input

    private var trimmedInput: String {
        textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateInputState() {
        let count = trimmedInput.count
        placeholderLabel.isHidden = !textView.text.isEmpty
        sendButton.isEnabled = !isSending && count > 0 && count <= PostComment.maxLength

        let showsCounter = count >= Self.counterThreshold
        if counterLabel.isHidden == showsCounter {
            counterLabel.isHidden = !showsCounter
            counterBottomConstraints?.withoutCounter.isActive = !showsCounter
            counterBottomConstraints?.withCounter.isActive = showsCounter
        }
        counterLabel.text = "\(count)/\(PostComment.maxLength)"
        counterLabel.textColor = count > PostComment.maxLength ? AppTheme.danger : AppTheme.tertiaryText
        counterLabel.accessibilityLabel = "\(PostComment.maxLength)자 중 \(count)자"

        let fittingHeight = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)).height
        let clampedHeight = min(max(fittingHeight, Self.minimumInputHeight), Self.maximumInputHeight)
        textView.isScrollEnabled = fittingHeight > Self.maximumInputHeight
        if textViewHeightConstraint?.constant != clampedHeight {
            textViewHeightConstraint?.constant = clampedHeight
        }
    }

    @objc private func sendTapped() {
        let text = trimmedInput
        guard !isSending, !text.isEmpty, text.count <= PostComment.maxLength else { return }

        isSending = true
        shouldScrollToBottomOnNextUpdate = true
        textView.text = ""
        updateInputState()

        commentRepository.addComment(postID: post.id, text: text) { [weak self] result in
            guard let self else { return }
            self.isSending = false

            switch result {
            case .success:
                Haptics.success()
            case .failure(let error):
                self.shouldScrollToBottomOnNextUpdate = false
                // Restore the draft so the user doesn't lose it.
                if self.textView.text.isEmpty {
                    self.textView.text = text
                }
                ToastView.show(message: "댓글 저장 실패: \(error.localizedDescription)", style: .error, in: self.view)
            }
            self.updateInputState()
        }
    }
}

// MARK: - UITextViewDelegate

extension CommentsViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        // Give the conversation room once the keyboard is up.
        guard let sheet = sheetPresentationController, sheet.selectedDetentIdentifier != .large else { return }
        sheet.animateChanges {
            sheet.selectedDetentIdentifier = .large
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        updateInputState()
    }
}

// MARK: - UITableView

extension CommentsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        comments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommentCell.reuseIdentifier, for: indexPath)
        if let commentCell = cell as? CommentCell {
            let comment = comments[indexPath.row]
            commentCell.configure(with: comment, isPostAuthor: comment.authorID == post.authorID)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        false
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard comments.indices.contains(indexPath.row) else { return nil }
        let comment = comments[indexPath.row]
        guard canDelete(comment) else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            self?.deleteComment(comment)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        deleteAction.backgroundColor = AppTheme.danger
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard comments.indices.contains(indexPath.row) else { return nil }
        let comment = comments[indexPath.row]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            var actions: [UIMenuElement] = [
                UIAction(title: "복사", image: UIImage(systemName: "doc.on.doc")) { _ in
                    UIPasteboard.general.string = comment.text
                }
            ]
            if self?.canDelete(comment) == true {
                actions.append(UIAction(title: "삭제", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                    self?.deleteComment(comment)
                })
            }
            return UIMenu(children: actions)
        }
    }
}

// MARK: - Cell

private final class CommentCell: UITableViewCell {
    static let reuseIdentifier = "CommentCell"

    private static let avatarSize: CGFloat = 32

    private let avatarContainerView = UIView()
    private var avatarLabel: UILabel?
    private let nameLabel = UILabel()
    private let authorBadgeLabel = UILabel()
    private let timeLabel = UILabel()
    private let bodyLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        avatarContainerView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = AppTheme.roundedFont(.subheadline, weight: .bold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = AppTheme.text
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        authorBadgeLabel.text = "작성자"
        authorBadgeLabel.font = AppTheme.roundedFont(.caption2, weight: .bold)
        authorBadgeLabel.adjustsFontForContentSizeCategory = true
        authorBadgeLabel.textColor = AppTheme.neonPink
        authorBadgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        authorBadgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        timeLabel.font = AppTheme.roundedFont(.caption1, weight: .medium)
        timeLabel.adjustsFontForContentSizeCategory = true
        timeLabel.textColor = AppTheme.tertiaryText
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let spacerView = UIView()
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let headerStackView = UIStackView(arrangedSubviews: [nameLabel, authorBadgeLabel, timeLabel, spacerView])
        headerStackView.axis = .horizontal
        headerStackView.alignment = .firstBaseline
        headerStackView.spacing = AppTheme.Spacing.s - 2

        bodyLabel.font = .preferredFont(forTextStyle: .subheadline)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.textColor = AppTheme.text.withAlphaComponent(0.92)
        bodyLabel.numberOfLines = 0

        let textStackView = UIStackView(arrangedSubviews: [headerStackView, bodyLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 3
        textStackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(avatarContainerView)
        contentView.addSubview(textStackView)

        let margin = AppTheme.Spacing.l

        NSLayoutConstraint.activate([
            avatarContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppTheme.Spacing.s + 2),
            avatarContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            avatarContainerView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarContainerView.heightAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarContainerView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -(AppTheme.Spacing.s + 2)),

            textStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppTheme.Spacing.s + 2),
            textStackView.leadingAnchor.constraint(equalTo: avatarContainerView.trailingAnchor, constant: AppTheme.Spacing.m),
            textStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            textStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -(AppTheme.Spacing.s + 2))
        ])
    }

    func configure(with comment: PostComment, isPostAuthor: Bool) {
        avatarLabel?.removeFromSuperview()
        let avatar = AppTheme.makeAvatarLabel(
            text: String(comment.authorName.prefix(1)),
            size: Self.avatarSize,
            fontSize: 13,
            color: AppTheme.avatarColor(for: comment.authorID)
        )
        avatarContainerView.addSubview(avatar)
        NSLayoutConstraint.activate([
            avatar.centerXAnchor.constraint(equalTo: avatarContainerView.centerXAnchor),
            avatar.centerYAnchor.constraint(equalTo: avatarContainerView.centerYAnchor)
        ])
        avatarLabel = avatar

        nameLabel.text = comment.authorName
        authorBadgeLabel.isHidden = !isPostAuthor
        let relativeTime = CommentTimeFormatter.relativeText(for: comment.createdAt)
        timeLabel.text = relativeTime
        bodyLabel.text = comment.text

        isAccessibilityElement = true
        accessibilityLabel = [
            comment.authorName,
            isPostAuthor ? "작성자" : nil,
            relativeTime,
            comment.text
        ].compactMap { $0 }.joined(separator: ", ")
    }
}

// MARK: - Relative time

enum CommentTimeFormatter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter
    }()

    static func relativeText(for date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60:
            return "방금"
        case ..<3_600:
            return "\(Int(seconds / 60))분 전"
        case ..<86_400:
            return "\(Int(seconds / 3_600))시간 전"
        case ..<(86_400 * 7):
            return "\(Int(seconds / 86_400))일 전"
        default:
            return dateFormatter.string(from: date)
        }
    }
}
