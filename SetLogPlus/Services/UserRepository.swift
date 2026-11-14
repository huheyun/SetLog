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

    func updateDisplayName(uid: String, displayName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("users").document(uid).setData(["displayName": displayName], merge: true) { error in
            completion(Result(error: error))
        }
    }
}
