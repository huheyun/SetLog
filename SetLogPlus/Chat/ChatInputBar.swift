import UIKit

/// Message composer: a growing text view (up to `maxVisibleLines`) and a send button.
final class ChatInputBar: UIView {
    var onSend: ((String) -> Void)?

    private static let maxVisibleLines: CGFloat = 5

    let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let sendButton = UIButton(type: .system)
    private let fieldBackground = UIView()
    private var textViewHeightConstraint: NSLayoutConstraint!

    /// Text with surrounding whitespace removed.
    var trimmedText: String {
        textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        updateState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clear() {
        textView.text = ""
        updateState()
    }

    func restore(text: String) {
        guard textView.text.isEmpty else { return }
        textView.text = text
        updateState()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTextViewHeight()
    }

    private func setupViews() {
        backgroundColor = AppTheme.background
        translatesAutoresizingMaskIntoConstraints = false

        let topSeparator = UIView()
        topSeparator.backgroundColor = AppTheme.separator
        topSeparator.translatesAutoresizingMaskIntoConstraints = false

        fieldBackground.backgroundColor = AppTheme.card
        fieldBackground.layer.cornerRadius = 20
        fieldBackground.layer.cornerCurve = .continuous
        fieldBackground.layer.borderWidth = 1
        fieldBackground.layer.borderColor = AppTheme.separator.cgColor
        fieldBackground.translatesAutoresizingMaskIntoConstraints = false

        textView.backgroundColor = .clear
        textView.textColor = AppTheme.text
        textView.tintColor = AppTheme.neonPink
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = UIEdgeInsets(top: 9, left: 10, bottom: 9, right: 10)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardAppearance = .dark
        textView.delegate = self
        textView.accessibilityLabel = "메시지 입력"
        textView.translatesAutoresizingMaskIntoConstraints = false

        placeholderLabel.text = "메시지 보내기"
        placeholderLabel.font = .preferredFont(forTextStyle: .body)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = AppTheme.tertiaryText
        placeholderLabel.isAccessibilityElement = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "arrow.up")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        configuration.cornerStyle = .capsule
        sendButton.configuration = configuration
        sendButton.configurationUpdateHandler = { button in
            var configuration = button.configuration
            configuration?.baseBackgroundColor = button.isEnabled ? AppTheme.neonPink : AppTheme.cardMuted
            configuration?.baseForegroundColor = button.isEnabled ? .black : AppTheme.tertiaryText
            button.configuration = configuration
        }
        sendButton.accessibilityLabel = "보내기"
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addAction(UIAction { [weak self] _ in self?.sendTapped() }, for: .touchUpInside)

        addSubview(topSeparator)
        addSubview(fieldBackground)
        fieldBackground.addSubview(textView)
        fieldBackground.addSubview(placeholderLabel)
        addSubview(sendButton)

        textViewHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 40)

        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            topSeparator.heightAnchor.constraint(equalToConstant: 1),

            fieldBackground.topAnchor.constraint(equalTo: topAnchor, constant: AppTheme.Spacing.s),
            fieldBackground.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AppTheme.Spacing.s),
            fieldBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AppTheme.Spacing.m),
            fieldBackground.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -AppTheme.Spacing.s),

            textView.topAnchor.constraint(equalTo: fieldBackground.topAnchor),
            textView.bottomAnchor.constraint(equalTo: fieldBackground.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: fieldBackground.leadingAnchor, constant: 4),
            textView.trailingAnchor.constraint(equalTo: fieldBackground.trailingAnchor, constant: -4),
            textViewHeightConstraint,

            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 10),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor, constant: -10),
            placeholderLabel.centerYAnchor.constraint(equalTo: fieldBackground.topAnchor, constant: 20),

            sendButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AppTheme.Spacing.m),
            sendButton.bottomAnchor.constraint(equalTo: fieldBackground.bottomAnchor, constant: -2),
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func sendTapped() {
        let text = trimmedText
        guard !text.isEmpty else { return }
        Haptics.tap()
        onSend?(text)
    }

    private func updateState() {
        placeholderLabel.isHidden = !textView.text.isEmpty
        sendButton.isEnabled = !trimmedText.isEmpty
        updateTextViewHeight()
    }

    private func updateTextViewHeight() {
        guard textView.bounds.width > 0, let font = textView.font else { return }

        let insets = textView.textContainerInset.top + textView.textContainerInset.bottom
        let minHeight = ceil(font.lineHeight + insets)
        let maxHeight = ceil(font.lineHeight * Self.maxVisibleLines + insets)
        let fitting = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)).height
        let height = min(max(fitting, minHeight), maxHeight)

        guard abs(textViewHeightConstraint.constant - height) > 0.5 else { return }
        textViewHeightConstraint.constant = height
        if fitting <= maxHeight {
            textView.setContentOffset(.zero, animated: false)
        } else {
            textView.scrollRangeToVisible(textView.selectedRange)
        }
    }
}

extension ChatInputBar: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateState()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString
        let updated = current.replacingCharacters(in: range, with: text)
        return updated.count <= ChatRepository.maxMessageLength
    }
}
