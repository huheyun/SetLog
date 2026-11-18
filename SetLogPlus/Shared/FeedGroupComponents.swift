import UIKit

/// Small building blocks shared by the feed, group settings and profile screens.
enum FeedGroupComponents {
    /// Rounded-square tile showing a group's first letter in its stable color.
    static func makeGroupTile(name: String, id: String, size: CGFloat = 48) -> UIView {
        let color = AppTheme.avatarColor(for: id)

        let tile = UIView()
        tile.backgroundColor = color.withAlphaComponent(0.18)
        tile.layer.cornerRadius = size * 0.32
        tile.layer.cornerCurve = .continuous
        tile.isUserInteractionEnabled = false
        tile.isAccessibilityElement = false
        tile.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
        label.font = UIFont.systemFont(ofSize: size * 0.42, weight: .bold).rounded
        label.textColor = color
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(label)

        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: size),
            tile.heightAnchor.constraint(equalToConstant: size),
            label.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: tile.centerYAnchor)
        ])
        return tile
    }

    /// Overlapping member circles (person glyph tinted per member) with a "+N" overflow badge.
    static func makeMemberAvatarStack(
        memberIDs: [String],
        size: CGFloat = 22,
        maxVisible: Int = 4,
        borderColor: UIColor = AppTheme.card
    ) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = -size * 0.32
        stackView.isUserInteractionEnabled = false
        stackView.isAccessibilityElement = false

        let visibleIDs = memberIDs.prefix(maxVisible)
        visibleIDs.forEach { id in
            stackView.addArrangedSubview(makeCircle(size: size, borderColor: borderColor) { circle in
                circle.backgroundColor = AppTheme.avatarColor(for: id)
                let glyph = UIImageView(image: UIImage(systemName: "person.fill"))
                glyph.tintColor = UIColor.white.withAlphaComponent(0.92)
                glyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: size * 0.42, weight: .bold)
                glyph.translatesAutoresizingMaskIntoConstraints = false
                circle.addSubview(glyph)
                NSLayoutConstraint.activate([
                    glyph.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
                    glyph.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
                ])
            })
        }

        let overflow = memberIDs.count - visibleIDs.count
        if overflow > 0 {
            stackView.addArrangedSubview(makeCircle(size: size, borderColor: borderColor) { circle in
                circle.backgroundColor = AppTheme.cardMuted
                let label = UILabel()
                label.text = "+\(overflow)"
                label.font = UIFont.systemFont(ofSize: size * 0.4, weight: .bold).rounded
                label.textColor = AppTheme.secondaryText
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.6
                label.textAlignment = .center
                label.translatesAutoresizingMaskIntoConstraints = false
                circle.addSubview(label)
                NSLayoutConstraint.activate([
                    label.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
                    label.leadingAnchor.constraint(equalTo: circle.leadingAnchor, constant: 2),
                    label.trailingAnchor.constraint(equalTo: circle.trailingAnchor, constant: -2)
                ])
            })
        }

        return stackView
    }

    /// Card that stacks rows with hairline separators between them (iOS "inset grouped" look).
    static func makeGroupedCard(rows: [UIView]) -> UIView {
        let card = UIView()
        AppTheme.roundCard(card, radius: AppTheme.Radius.medium)

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false

        rows.enumerated().forEach { index, row in
            if index > 0 {
                let separator = UIView()
                separator.backgroundColor = AppTheme.separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                let separatorContainer = UIView()
                separatorContainer.addSubview(separator)
                NSLayoutConstraint.activate([
                    separatorContainer.heightAnchor.constraint(equalToConstant: 0.5),
                    separator.topAnchor.constraint(equalTo: separatorContainer.topAnchor),
                    separator.bottomAnchor.constraint(equalTo: separatorContainer.bottomAnchor),
                    separator.leadingAnchor.constraint(equalTo: separatorContainer.leadingAnchor, constant: AppTheme.Spacing.l),
                    separator.trailingAnchor.constraint(equalTo: separatorContainer.trailingAnchor)
                ])
                stackView.addArrangedSubview(separatorContainer)
            }
            stackView.addArrangedSubview(row)
        }

        card.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    /// Section header label plus content, spaced consistently.
    static func makeSection(title: String, content: UIView) -> UIView {
        let header = AppTheme.makeSectionHeader(title)
        header.accessibilityTraits = .header

        let headerContainer = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            header.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            header.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: AppTheme.Spacing.xs),
            header.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor)
        ])

        let stackView = UIStackView(arrangedSubviews: [headerContainer, content])
        stackView.axis = .vertical
        stackView.spacing = AppTheme.Spacing.s
        return stackView
    }

    /// Small capsule tag, e.g. "그룹장".
    static func makePill(text: String, color: UIColor) -> UILabel {
        let label = PaddedLabel()
        label.text = text
        label.font = AppTheme.roundedFont(.caption1, weight: .bold)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.backgroundColor = color.withAlphaComponent(0.14)
        label.layer.cornerRadius = 10
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private static func makeCircle(size: CGFloat, borderColor: UIColor, configure: (UIView) -> Void) -> UIView {
        let circle = UIView()
        circle.layer.cornerRadius = size / 2
        circle.layer.borderWidth = 2
        circle.layer.borderColor = borderColor.cgColor
        circle.clipsToBounds = true
        circle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: size),
            circle.heightAnchor.constraint(equalToConstant: size)
        ])
        configure(circle)
        return circle
    }
}

/// UILabel with horizontal/vertical insets, used for pills.
private final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
