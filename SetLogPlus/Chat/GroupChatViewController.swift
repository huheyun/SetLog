import FirebaseFirestore
import UIKit

/// Realtime group chat (`groups/{groupId}/messages`).
final class GroupChatViewController: UIViewController {
    private let group: Group
    private let repository = ChatRepository()
    private let currentUserID = AuthService.shared.currentUserID

    private var listener: ListenerRegistration?
    private var rowsByID: [String: ChatRow] = [:]
    private var hasLoadedOnce = false
    private var hasShownLoadError = false
    /// Whether the list was scrolled to (near) the bottom before the last layout/data change.
    private var isPinnedToBottom = true
    private var lastTableHeight: CGFloat = 0

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputBar = ChatInputBar()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let emptyStateView = UIStackView()
    private lazy var dataSource = makeDataSource()

    init(group: Group) {
        self.group = group
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        listener?.remove()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        navigationItem.title = group.name
        navigationItem.subtitle = "멤버 \(group.memberIDs.count)명"
        navigationItem.largeTitleDisplayMode = .never

        setupTableView()
        setupInputBar()
        setupEmptyState()
        applyRows([])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startListening()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopListening()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keyboard / composer height changes shrink the list; keep the latest message visible.
        let height = tableView.bounds.height
        if height != lastTableHeight {
            lastTableHeight = height
            if isPinnedToBottom {
                scrollToBottom(animated: false)
            }
        }
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.backgroundColor = AppTheme.background
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.keyboardDismissMode = .interactive
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: AppTheme.Spacing.m, right: 0)
        tableView.delegate = self
        tableView.register(OutgoingMessageCell.self, forCellReuseIdentifier: OutgoingMessageCell.reuseIdentifier)
        tableView.register(IncomingMessageCell.self, forCellReuseIdentifier: IncomingMessageCell.reuseIdentifier)
        tableView.register(ChatDateCell.self, forCellReuseIdentifier: ChatDateCell.reuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupInputBar() {
        inputBar.onSend = { [weak self] text in
            self?.send(text)
        }

        // Fills the home-indicator area below the composer.
        let bottomFill = UIView()
        bottomFill.backgroundColor = AppTheme.background
        bottomFill.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(bottomFill)
        view.addSubview(inputBar)
        NSLayoutConstraint.activate([
            inputBar.topAnchor.constraint(equalTo: tableView.bottomAnchor),
            inputBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            bottomFill.topAnchor.constraint(equalTo: inputBar.bottomAnchor),
            bottomFill.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFill.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFill.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyState() {
        let icon = UIImageView(image: UIImage(systemName: "bubble.left.and.bubble.right.fill"))
        icon.tintColor = AppTheme.neonPink
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)

        let title = UILabel()
        title.text = "첫 메시지를 보내보세요"
        title.font = AppTheme.roundedFont(.headline, weight: .semibold)
        title.adjustsFontForContentSizeCategory = true
        title.textColor = AppTheme.text

        let subtitle = UILabel()
        subtitle.text = "\(group.name) 멤버들과 오늘의 순간을 이야기해보세요."
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.textColor = AppTheme.secondaryText
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center

        emptyStateView.axis = .vertical
        emptyStateView.alignment = .center
        emptyStateView.spacing = AppTheme.Spacing.s
        emptyStateView.setCustomSpacing(AppTheme.Spacing.m, after: icon)
        [icon, title, subtitle].forEach(emptyStateView.addArrangedSubview)
        emptyStateView.isHidden = true
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false

        loadingIndicator.color = AppTheme.secondaryText
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()

        view.addSubview(emptyStateView)
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            emptyStateView.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.Spacing.xxl),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.Spacing.xxl),
            loadingIndicator.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }

    // MARK: - Data

    private func startListening() {
        guard listener == nil else { return }
        listener = repository.listenMessages(groupID: group.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let messages):
                self.hasLoadedOnce = true
                self.loadingIndicator.stopAnimating()
                self.applyRows(ChatRowBuilder.rows(for: messages, currentUserID: self.currentUserID))
            case .failure:
                self.loadingIndicator.stopAnimating()
                guard !self.hasShownLoadError else { return }
                self.hasShownLoadError = true
                ToastView.show(message: "채팅을 불러오지 못했어요.", style: .error, in: self.view)
            }
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    private func makeDataSource() -> UITableViewDiffableDataSource<Int, String> {
        let dataSource = UITableViewDiffableDataSource<Int, String>(tableView: tableView) { [weak self] tableView, indexPath, id in
            guard let row = self?.rowsByID[id] else { return UITableViewCell() }

            switch row {
            case .date(let date):
                let cell = tableView.dequeueReusableCell(withIdentifier: ChatDateCell.reuseIdentifier, for: indexPath)
                (cell as? ChatDateCell)?.configure(date: date)
                return cell
            case .message(let messageRow) where messageRow.isMine:
                let cell = tableView.dequeueReusableCell(withIdentifier: OutgoingMessageCell.reuseIdentifier, for: indexPath)
                (cell as? OutgoingMessageCell)?.configure(with: messageRow)
                return cell
            case .message(let messageRow):
                let cell = tableView.dequeueReusableCell(withIdentifier: IncomingMessageCell.reuseIdentifier, for: indexPath)
                (cell as? IncomingMessageCell)?.configure(with: messageRow)
                return cell
            }
        }
        dataSource.defaultRowAnimation = .fade
        return dataSource
    }

    private func applyRows(_ rows: [ChatRow]) {
        let previousRows = rowsByID
        let previousLastID = dataSource.snapshot().itemIdentifiers.last
        let wasNearBottom = isNearBottom

        var newRowsByID: [String: ChatRow] = [:]
        newRowsByID.reserveCapacity(rows.count)
        rows.forEach { newRowsByID[$0.id] = $0 }
        rowsByID = newRowsByID

        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(rows.map(\.id))
        let changedIDs = rows.compactMap { row -> String? in
            guard let previous = previousRows[row.id], previous != row else { return nil }
            return row.id
        }
        snapshot.reconfigureItems(changedIDs)

        emptyStateView.isHidden = !(hasLoadedOnce && rows.isEmpty)

        let isInitialLoad = previousRows.isEmpty
        let newLastID = rows.last?.id
        let lastIsMine: Bool = {
            if case .message(let row) = rows.last { return row.isMine }
            return false
        }()

        dataSource.apply(snapshot, animatingDifferences: !isInitialLoad && view.window != nil) { [weak self] in
            guard let self, newLastID != nil, newLastID != previousLastID else { return }
            if isInitialLoad {
                self.scrollToBottom(animated: false)
            } else if wasNearBottom || lastIsMine {
                self.scrollToBottom(animated: true)
            }
        }
    }

    // MARK: - Actions

    private func send(_ text: String) {
        inputBar.clear()
        isPinnedToBottom = true
        repository.sendMessage(groupID: group.id, text: text) { [weak self] result in
            guard case .failure = result else { return }
            Haptics.error()
            guard let self else { return }
            self.inputBar.restore(text: text)
            ToastView.show(message: "메시지를 보내지 못했어요.", style: .error, in: self.view)
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Scrolling

    private var isNearBottom: Bool {
        let visibleBottom = tableView.contentOffset.y + tableView.bounds.height - tableView.adjustedContentInset.bottom
        return visibleBottom >= tableView.contentSize.height - 120
    }

    private func scrollToBottom(animated: Bool) {
        let rowCount = tableView.numberOfRows(inSection: 0)
        guard tableView.numberOfSections > 0, rowCount > 0 else { return }
        tableView.scrollToRow(at: IndexPath(row: rowCount - 1, section: 0), at: .bottom, animated: animated)
    }
}

// MARK: - UITableViewDelegate

extension GroupChatViewController: UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isTracking || scrollView.isDecelerating else { return }
        isPinnedToBottom = isNearBottom
    }

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let id = dataSource.itemIdentifier(for: indexPath),
              case .message(let row) = rowsByID[id] else {
            return nil
        }

        let text = row.message.text
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: [
                UIAction(title: "복사", image: UIImage(systemName: "doc.on.doc")) { _ in
                    UIPasteboard.general.string = text
                }
            ])
        }
    }
}
