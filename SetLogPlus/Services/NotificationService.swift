import Foundation

final class NotificationService {
    private let postRepository = PostRepository()
    private let resultQueue = DispatchQueue(label: "setlogplus.notification.results")

    func fetchTodayLogNotifications(
        groups: [Group],
        excluding userID: String?,
        limit: Int = 5,
        completion: @escaping (Result<[LogNotification], Error>) -> Void
    ) {
        guard !groups.isEmpty else {
            completion(.success([]))
            return
        }

        let dispatchGroup = DispatchGroup()
        var fetchedPosts: [Post] = []
        var fetchError: Error?

        groups.forEach { group in
            dispatchGroup.enter()
            postRepository.fetchPosts(groupID: group.id) { result in
                self.resultQueue.async {
                    switch result {
                    case .success(let posts):
                        fetchedPosts.append(contentsOf: posts)
                    case .failure(let error):
                        fetchError = error
                    }
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            if let fetchError {
                completion(.failure(fetchError))
                return
            }

            let notifications = fetchedPosts
                .filter { $0.authorID != userID && HourSlot.isTodayKey($0.hourKey) }
                .sorted { $0.hourKey > $1.hourKey }
                .prefix(limit)
                .compactMap { post -> LogNotification? in
                    guard let group = groups.first(where: { $0.id == post.groupID }) else {
                        return nil
                    }

                    return LogNotification(
                        authorName: post.authorName,
                        groupName: group.name,
                        hourKey: post.hourKey
                    )
                }

            completion(.success(Array(notifications)))
        }
    }
}
