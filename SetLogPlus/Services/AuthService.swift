import FirebaseAuth
import Foundation

final class AuthService {
    static let shared = AuthService()

    private let userRepository = UserRepository()
    private let groupRepository = GroupRepository()

    private init() {}

    var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    /// The signed-in user as an `AppUser`, with display name falling back to email.
    var currentAppUser: AppUser? {
        guard let user = Auth.auth().currentUser else { return nil }

        return AppUser(
            uid: user.uid,
            email: user.email ?? "",
            displayName: user.displayName ?? user.email ?? "사용자"
        )
    }

    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            completion(Result(error: error))
        }
    }

    func signUp(displayName: String, email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [userRepository] result, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let firebaseUser = result?.user else {
                completion(.failure(AuthError.missingUser))
                return
            }

            let changeRequest = firebaseUser.createProfileChangeRequest()
            changeRequest.displayName = displayName
            changeRequest.commitChanges { profileError in
                if let profileError {
                    completion(.failure(profileError))
                    return
                }

                let appUser = AppUser(uid: firebaseUser.uid, email: email, displayName: displayName)
                userRepository.createUserProfile(appUser, completion: completion)
            }
        }
    }

    func signOut() -> Result<Void, Error> {
        Result { try Auth.auth().signOut() }
    }

    func updateDisplayName(_ displayName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(AuthError.missingUser))
            return
        }

        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        changeRequest.commitChanges { [userRepository, groupRepository] error in
            if let error {
                completion(.failure(error))
                return
            }

            userRepository.updateDisplayName(uid: user.uid, displayName: displayName) { result in
                switch result {
                case .success:
                    groupRepository.updateMemberDisplayName(
                        userID: user.uid,
                        displayName: displayName,
                        completion: completion
                    )
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}

enum AuthError: LocalizedError {
    case missingUser
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .missingUser:
            return "회원가입은 완료되었지만 사용자 정보를 찾을 수 없습니다."
        case .notLoggedIn:
            return "로그인이 필요합니다."
        }
    }
}
