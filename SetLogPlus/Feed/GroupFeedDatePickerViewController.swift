import UIKit

/// Calendar sheet for picking a past day in the group feed.
/// Days with at least one post get a small neon-pink dot.
final class GroupFeedDatePickerViewController: UIViewController {
    private let selectedDate: Date
    private let earliestDate: Date
    private let dayKeysWithPosts: Set<String>
    private let onSelect: (Date) -> Void
    private let calendarView = UICalendarView()

    /// - Parameters:
    ///   - selectedDate: Currently selected day.
    ///   - dayKeysWithPosts: `yyyyMMdd` keys of days that have posts.
    ///   - onSelect: Called with the start of the picked day, after the sheet starts dismissing.
    init(selectedDate: Date, dayKeysWithPosts: Set<String>, onSelect: @escaping (Date) -> Void) {
        self.selectedDate = HourSlot.startOfDay(selectedDate)
        self.dayKeysWithPosts = dayKeysWithPosts
        self.onSelect = onSelect
        let earliestPostDay = dayKeysWithPosts.min().flatMap { HourSlot.date(fromDayKey: $0) }
        self.earliestDate = min(earliestPostDay ?? self.selectedDate, self.selectedDate)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.card
        overrideUserInterfaceStyle = .dark
        setupLayout()
    }

    /// Wraps the picker in a sheet sized for the calendar.
    func configureSheet() {
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [
                .custom(identifier: .init("calendar")) { _ in 470 },
                .large()
            ]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = AppTheme.Radius.large
        }
    }

    private func setupLayout() {
        let titleLabel = UILabel()
        titleLabel.text = "날짜 선택"
        titleLabel.font = AppTheme.roundedFont(.headline, weight: .bold)
        titleLabel.textColor = AppTheme.text
        titleLabel.accessibilityTraits = .header

        var todayConfiguration = UIButton.Configuration.plain()
        todayConfiguration.title = "오늘"
        todayConfiguration.baseForegroundColor = AppTheme.neonPink
        todayConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.roundedFont(.subheadline, weight: .bold)
            return attributes
        }
        let todayButton = UIButton(configuration: todayConfiguration)
        todayButton.accessibilityLabel = "오늘로 이동"
        todayButton.addAction(UIAction { [weak self] _ in
            self?.finish(with: HourSlot.startOfDay())
        }, for: .touchUpInside)

        let calendar = HourSlot.calendar
        calendarView.calendar = calendar
        calendarView.locale = Locale(identifier: "ko_KR")
        calendarView.fontDesign = .rounded
        calendarView.tintColor = AppTheme.neonPink
        calendarView.delegate = self
        let today = HourSlot.startOfDay()
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: today)?.addingTimeInterval(-1) ?? today
        calendarView.availableDateRange = DateInterval(start: earliestDate, end: endOfToday)
        calendarView.visibleDateComponents = calendar.dateComponents([.calendar, .year, .month, .day], from: selectedDate)

        let selection = UICalendarSelectionSingleDate(delegate: self)
        selection.selectedDate = calendar.dateComponents([.calendar, .year, .month, .day], from: selectedDate)
        calendarView.selectionBehavior = selection

        [titleLabel, todayButton, calendarView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        let margin = AppTheme.Spacing.screen
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: AppTheme.Spacing.xl),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            todayButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            todayButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin + 8),

            calendarView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppTheme.Spacing.s),
            calendarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.Spacing.s),
            calendarView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.Spacing.s),
            calendarView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func finish(with date: Date) {
        let onSelect = onSelect
        dismiss(animated: true)
        onSelect(HourSlot.startOfDay(date))
    }

    private static func dayKey(for components: DateComponents) -> String? {
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        return String(format: "%04d%02d%02d", year, month, day)
    }
}

extension GroupFeedDatePickerViewController: UICalendarViewDelegate {
    func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
        guard let key = Self.dayKey(for: dateComponents), dayKeysWithPosts.contains(key) else {
            return nil
        }
        return .default(color: AppTheme.neonPink, size: .small)
    }
}

extension GroupFeedDatePickerViewController: UICalendarSelectionSingleDateDelegate {
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        guard let dateComponents,
              let date = HourSlot.calendar.date(from: dateComponents) else {
            return
        }
        finish(with: date)
    }
}
