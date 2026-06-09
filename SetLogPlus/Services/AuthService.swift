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

    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func signUp(displayName: String, email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
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

                let appUser = AppUser(
                    uid: firebaseUser.uid,
                    email: email,
                    displayName: displayName
                )

                self?.userRepository.createUserProfile(appUser, completion: completion)
            }
        }
    }

    func signOut() -> Result<Void, Error> {
        do {
            try Auth.auth().signOut()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func updateDisplayName(_ displayName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(AuthError.missingUser))
            return
        }

        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        changeRequest.commitChanges { [weak self] error in
            if let error {
                completion(.failure(error))
                return
            }

            self?.userRepository.updateDisplayName(uid: user.uid, displayName: displayName) { result in
                switch result {
                case .success:
                    self?.groupRepository.updateMemberDisplayName(
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

    var errorDescription: String? {
        switch self {
        case .missingUser:
            return "회원가입은 완료되었지만 사용자 정보를 찾을 수 없습니다."
        }
    }
}
