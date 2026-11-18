import UIKit

// MARK: - Bubble

/// Rounded bubble with a multi-line label.
final class ChatBubbleView: UIView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous

        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private func makeTimeLabel() -> UILabel {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .caption2)
    label.adjustsFontForContentSizeCategory = true
    label.textColor = AppTheme.tertiaryText
    label.setContentHuggingPriority(.required, for: .horizontal)
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    return label
}

private let maxBubbleWidthRatio: CGFloat = 0.7
private let runStartSpacing: CGFloat = 10
private let runContinuationSpacing: CGFloat = 2

// MARK: - Outgoing

final class OutgoingMessageCell: UITableViewCell {
    static let reuseIdentifier = "OutgoingMessageCell"

    private let bubble = ChatBubbleView()
    private let timeLabel = makeTimeLabel()
    private var topConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        bubble.backgroundColor = AppTheme.neonPink
        bubble.label.textColor = .black

        let row = UIStackView(arrangedSubviews: [timeLabel, bubble])
        row.axis = .horizontal
        row.alignment = .bottom
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        topConstraint = row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: runContinuationSpacing)
        NSLayoutConstraint.activate([
            topConstraint,
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.Spacing.l),
            row.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: AppTheme.Spacing.l),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: maxBubbleWidthRatio)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with row: ChatMessageRow) {
        bubble.label.text = row.message.text
        bubble.alpha = row.message.isPending ? 0.6 : 1
        timeLabel.text = row.message.isPending ? "전송 중" : ChatFormatters.time.string(from: row.message.createdAt)
        timeLabel.isHidden = !(row.showsTime || row.message.isPending)
        topConstraint.constant = row.isRunStart ? runStartSpacing : runContinuationSpacing

        isAccessibilityElement = true
        accessibilityLabel = "나: \(row.message.text)"
        accessibilityValue = row.message.isPending ? "전송 중" : ChatFormatters.time.string(from: row.message.createdAt)
    }

    var bubbleView: UIView { bubble }
}

// MARK: - Incoming

final class IncomingMessageCell: UITableViewCell {
    static let reuseIdentifier = "IncomingMessageCell"

    private static let avatarSize: CGFloat = 32

    private let avatarContainer = UIView()
    private var avatarLabel: UILabel?
    private let nameLabel = UILabel()
    private let bubble = ChatBubbleView()
    private let timeLabel = makeTimeLabel()
    private var topConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        bubble.backgroundColor = AppTheme.cardMuted
        bubble.label.textColor = AppTheme.text

        nameLabel.font = AppTheme.roundedFont(.caption1, weight: .semibold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = AppTheme.secondaryText

        avatarContainer.translatesAutoresizingMaskIntoConstraints = false

        let bubbleRow = UIStackView(arrangedSubviews: [bubble, timeLabel])
        bubbleRow.axis = .horizontal
        bubbleRow.alignment = .bottom
        bubbleRow.spacing = 6

        let column = UIStackView(arrangedSubviews: [nameLabel, bubbleRow])
        column.axis = .vertical
        column.alignment = .leading
        column.spacing = 4
        column.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(avatarContainer)
        contentView.addSubview(column)

        topConstraint = column.topAnchor.constraint(equalTo: contentView.topAnchor, constant: runContinuationSpacing)
        NSLayoutConstraint.activate([
            avatarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.Spacing.l),
            avatarContainer.topAnchor.constraint(equalTo: column.topAnchor),
            avatarContainer.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarContainer.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            topConstraint,
            column.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            column.leadingAnchor.constraint(equalTo: avatarContainer.trailingAnchor, constant: AppTheme.Spacing.s),
            column.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -AppTheme.Spacing.l),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: maxBubbleWidthRatio)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with row: ChatMessageRow) {
        let message = row.message
        bubble.label.text = message.text
        timeLabel.text = ChatFormatters.time.string(from: message.createdAt)
        timeLabel.isHidden = !row.showsTime
        nameLabel.text = message.senderName
        nameLabel.isHidden = !row.isRunStart
        topConstraint.constant = row.isRunStart ? runStartSpacing : runContinuationSpacing

        avatarLabel?.removeFromSuperview()
        avatarLabel = nil
        if row.isRunStart {
            let avatar = AppTheme.makeAvatarLabel(
                text: String(message.senderName.prefix(1)),
                size: Self.avatarSize,
                fontSize: 14,
                color: AppTheme.avatarColor(for: message.senderID)
            )
            avatarContainer.addSubview(avatar)
            NSLayoutConstraint.activate([
                avatar.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
                avatar.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor)
            ])
            avatarLabel = avatar
        }

        isAccessibilityElement = true
        accessibilityLabel = "\(message.senderName): \(message.text)"
        accessibilityValue = ChatFormatters.time.string(from: message.createdAt)
    }

    var bubbleView: UIView { bubble }
}

// MARK: - Date separator

final class ChatDateCell: UITableViewCell {
    static let reuseIdentifier = "ChatDateCell"

    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        let capsule = UIView()
        capsule.backgroundColor = AppTheme.card
        capsule.layer.cornerRadius = 12
        capsule.layer.cornerCurve = .continuous
        capsule.layer.borderWidth = 1
        capsule.layer.borderColor = AppTheme.separator.cgColor
        capsule.translatesAutoresizingMaskIntoConstraints = false

        label.font = AppTheme.roundedFont(.caption1, weight: .semibold)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = AppTheme.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(capsule)
        capsule.addSubview(label)

        NSLayoutConstraint.activate([
            capsule.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppTheme.Spacing.l),
            capsule.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppTheme.Spacing.xs),
            capsule.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.topAnchor.constraint(equalTo: capsule.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: capsule.bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: capsule.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: capsule.trailingAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(date: Date) {
        label.text = ChatFormatters.dayTitle(for: date)
        accessibilityLabel = label.text
        accessibilityTraits = .header
    }
}
