import UIKit

/// "‹  11월 18일 (화) · 오늘  ›" bar above the hour chips in the group feed.
final class GroupFeedDateBar: UIView {
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onDateTapped: (() -> Void)?

    private let previousButton = IconCircleButton(
        systemName: "chevron.left",
        tintColor: AppTheme.text,
        accessibilityLabel: "이전 날",
        size: 36
    )
    private let nextButton = IconCircleButton(
        systemName: "chevron.right",
        tintColor: AppTheme.text,
        accessibilityLabel: "다음 날",
        size: 36
    )
    private let dateButton = UIButton(configuration: .plain())

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(date: Date, isToday: Bool) {
        let dayText = HourSlot.displayDayText(date: date)

        var title = AttributedString(dayText)
        title.font = AppTheme.roundedFont(.headline, weight: .bold)
        title.foregroundColor = AppTheme.text
        if isToday {
            var suffix = AttributedString(" · 오늘")
            suffix.font = AppTheme.roundedFont(.headline, weight: .bold)
            suffix.foregroundColor = AppTheme.neonPink
            title.append(suffix)
        }

        var configuration = dateButton.configuration ?? .plain()
        configuration.attributedTitle = title
        dateButton.configuration = configuration
        dateButton.accessibilityLabel = dayText + (isToday ? ", 오늘" : "")

        nextButton.isEnabled = !isToday
        nextButton.alpha = isToday ? 0.3 : 1
    }

    private func setup() {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.down")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        configuration.baseForegroundColor = AppTheme.secondaryText
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        configuration.titleLineBreakMode = .byTruncatingTail
        dateButton.configuration = configuration
        dateButton.enablePressAnimation()
        dateButton.accessibilityHint = "달력에서 날짜를 고릅니다"
        dateButton.addAction(UIAction { [weak self] _ in self?.onDateTapped?() }, for: .touchUpInside)

        previousButton.addAction(UIAction { [weak self] _ in self?.onPrevious?() }, for: .touchUpInside)
        nextButton.addAction(UIAction { [weak self] _ in self?.onNext?() }, for: .touchUpInside)

        [previousButton, dateButton, nextButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        dateButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),

            previousButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            previousButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            nextButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            dateButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            dateButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dateButton.leadingAnchor.constraint(greaterThanOrEqualTo: previousButton.trailingAnchor, constant: AppTheme.Spacing.xs),
            dateButton.trailingAnchor.constraint(lessThanOrEqualTo: nextButton.leadingAnchor, constant: -AppTheme.Spacing.xs)
        ])
    }
}
