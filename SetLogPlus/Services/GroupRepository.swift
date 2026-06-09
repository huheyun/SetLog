import FirebaseFirestore
import Foundation

final class GroupRepository {
    private let db = Firestore.firestore()

    func createGroup(name: String, owner: AppUser, completion: @escaping (Result<Group, Error>) -> Void) {
        let groupRef = db.collection("groups").document()
        let inviteCode = Self.makeInviteCode()
        let group = Group(
            id: groupRef.documentID,
            name: name,
            ownerID: owner.uid,
            memberIDs: [owner.uid],
            inviteCode: inviteCode
        )

        let groupData: [String: Any] = [
            "id": group.id,
            "name": group.name,
            "ownerID": group.ownerID,
            "memberIDs": group.memberIDs,
            "inviteCode": group.inviteCode,
            "createdAt": FieldValue.serverTimestamp()
        ]

        let memberData: [String: Any] = [
            "uid": owner.uid,
            "email": owner.email,
            "displayName": owner.displayName,
            "role": "owner",
            "joinedAt": FieldValue.serverTimestamp()
        ]

        let batch = db.batch()
        batch.setData(groupData, forDocument: groupRef)
        batch.setData(memberData, forDocument: groupRef.collection("members").document(owner.uid))

        batch.commit { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(group))
            }
        }
    }

    func fetchGroups(for uid: String, completion: @escaping (Result<[Group], Error>) -> Void) {
        db.collection("groups")
            .whereField("memberIDs", arrayContains: uid)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let groups = snapshot?.documents.compactMap { document -> Group? in
                    Self.makeGroup(from: document)
                } ?? []

                completion(.success(groups))
            }
    }

    func updateMemberDisplayName(userID: String, displayName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("groups")
            .whereField("memberIDs", arrayContains: userID)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    completion(.failure(error))
                    return
                }

                let documents = snapshot?.documents ?? []
                guard !documents.isEmpty else {
                    completion(.success(()))
                    return
                }

                let batch = self.db.batch()
                documents.forEach { document in
                    let memberRef = document.reference.collection("members").document(userID)
                    batch.updateData(["displayName": displayName], forDocument: memberRef)
                }

                batch.commit { error in
                    if let error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }

    func joinGroup(inviteCode: String, user: AppUser, completion: @escaping (Result<Group, Error>) -> Void) {
        let normalizedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        db.collection("groups")
            .whereField("inviteCode", isEqualTo: normalizedCode)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    completion(.failure(error))
                    return
                }

                guard let document = snapshot?.documents.first,
                      var group = Self.makeGroup(from: document) else {
                    completion(.failure(GroupRepositoryError.groupNotFound))
                    return
                }

                if group.memberIDs.contains(user.uid) {
                    completion(.success(group))
                    return
                }

                let groupRef = self.db.collection("groups").document(document.documentID)
                let memberData: [String: Any] = [
                    "uid": user.uid,
                    "email": user.email,
                    "displayName": user.displayName,
                    "role": "member",
                    "joinedAt": FieldValue.serverTimestamp()
                ]

                let batch = self.db.batch()
                batch.updateData(["memberIDs": FieldValue.arrayUnion([user.uid])], forDocument: groupRef)
                batch.setData(memberData, forDocument: groupRef.collection("members").document(user.uid))

                batch.commit { error in
                    if let error {
                        completion(.failure(error))
                    } else {
                        group = Group(
                            id: group.id,
                            name: group.name,
                            ownerID: group.ownerID,
                            memberIDs: group.memberIDs + [user.uid],
                            inviteCode: group.inviteCode
                        )
                        completion(.success(group))
                    }
                }
            }
    }

    func fetchMembers(groupID: String, completion: @escaping (Result<[GroupMember], Error>) -> Void) {
        db.collection("groups")
            .document(groupID)
            .collection("members")
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let members = snapshot?.documents.compactMap { document -> GroupMember? in
                    let data = document.data()

                    guard let uid = data["uid"] as? String,
                          let email = data["email"] as? String,
                          let displayName = data["displayName"] as? String,
                          let role = data["role"] as? String else {
                        return nil
                    }

                    return GroupMember(uid: uid, email: email, displayName: displayName, role: role)
                } ?? []

                completion(.success(members))
            }
    }

    func leaveGroup(group: Group, userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard group.ownerID != userID else {
            completion(.failure(GroupRepositoryError.ownerCannotLeave))
            return
        }

        let groupRef = db.collection("groups").document(group.id)
        let memberRef = groupRef.collection("members").document(userID)

        let batch = db.batch()
        batch.updateData(["memberIDs": FieldValue.arrayRemove([userID])], forDocument: groupRef)
        batch.deleteDocument(memberRef)

        batch.commit { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func deleteGroup(group: Group, userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard group.ownerID == userID else {
            completion(.failure(GroupRepositoryError.onlyOwnerCanDelete))
            return
        }

        let groupRef = db.collection("groups").document(group.id)

        groupRef.collection("members").getDocuments { snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            let batch = self.db.batch()
            snapshot?.documents.forEach { document in
                batch.deleteDocument(document.reference)
            }
            batch.deleteDocument(groupRef)

            batch.commit { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    private static func makeGroup(from document: QueryDocumentSnapshot) -> Group? {
        let data = document.data()

        guard let name = data["name"] as? String,
              let ownerID = data["ownerID"] as? String,
              let memberIDs = data["memberIDs"] as? [String] else {
            return nil
        }

        let inviteCode = data["inviteCode"] as? String ?? "초대 코드 없음"

        return Group(
            id: document.documentID,
            name: name,
            ownerID: ownerID,
            memberIDs: memberIDs,
            inviteCode: inviteCode
        )
    }

    private static func makeInviteCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in characters.randomElement() })
    }
}

enum GroupRepositoryError: LocalizedError {
    case groupNotFound
    case ownerCannotLeave
    case onlyOwnerCanDelete

    var errorDescription: String? {
        switch self {
        case .groupNotFound:
            return "해당 초대 코드의 그룹을 찾을 수 없습니다."
        case .ownerCannotLeave:
            return "그룹장은 그룹 나가기 대신 그룹 삭제를 사용할 수 있습니다."
        case .onlyOwnerCanDelete:
            return "그룹장만 그룹을 삭제할 수 있습니다."
        }
    }
}
