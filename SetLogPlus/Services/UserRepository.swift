import FirebaseFirestore
import Foundation

final class UserRepository {
    private let db = Firestore.firestore()

    func createUserProfile(_ user: AppUser, completion: @escaping (Result<Void, Error>) -> Void) {
        let data: [String: Any] = [
            "uid": user.uid,
            "email": user.email,
            "displayName": user.displayName,
            "createdAt": FieldValue.serverTimestamp()
        ]

        db.collection("users").document(user.uid).setData(data) { error in
            completion(Result(error: error))
        }
    }

    /// Creates the profile only when it doesn't exist yet.
    func createUserProfileIfNeeded(_ user: AppUser, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("users").document(user.uid).getDocument { [weak self] snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard snapshot?.exists != true else {
                completion(.success(()))
                return
            }

            guard let self else {
                completion(.success(()))
                return
            }
            self.createUserProfile(user, completion: completion)
        }
    }

    func updateDisplayName(uid: String, displayName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("users").document(uid).setData(["displayName": displayName], merge: true) { error in
            completion(Result(error: error))
        }
    }
}
