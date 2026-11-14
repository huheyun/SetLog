import FirebaseFirestore
import Foundation

final class GroupRepository {
    private let db = Firestore.firestore()

    private var groupsCollection: CollectionReference {
        db.collection("groups")
    }

    func createGroup(name: String, owner: AppUser, completion: @escaping (Result<Group, Error>) -> Void) {
        let groupRef = groupsCollection.document()
        let group = Group(
            id: groupRef.documentID,
            name: name,
            ownerID: owner.uid,
            memberIDs: [owner.uid],
            inviteCode: Self.makeInviteCode()
        )

        let groupData: [String: Any] = [
            "id": group.id,
            "name": group.name,
            "ownerID": group.ownerID,
            "memberIDs": group.memberIDs,
            "inviteCode": group.inviteCode,
            "createdAt": FieldValue.serverTimestamp()
        ]

        let batch = db.batch()
        batch.setData(groupData, forDocument: groupRef)
        batch.setData(
            Self.memberData(for: owner, role: .owner),
            forDocument: groupRef.collection("members").document(owner.uid)
        )

        batch.commit { error in
            completion(Result(error: error).map { group })
        }
    }

    func fetchGroups(for uid: String, completion: @escaping (Result<[Group], Error>) -> Void) {
        groupsCollection
            .whereField("memberIDs", arrayContains: uid)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let groups = snapshot?.documents.compactMap(Self.makeGroup(from:)) ?? []
                completion(.success(groups))
            }
    }

    func updateMemberDisplayName(userID: String, displayName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let db = db
        groupsCollection
            .whereField("memberIDs", arrayContains: userID)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let documents = snapshot?.documents ?? []
                guard !documents.isEmpty else {
                    completion(.success(()))
                    return
                }

                let batch = db.batch()
                documents.forEach { document in
                    let memberRef = document.reference.collection("members").document(userID)
                    batch.updateData(["displayName": displayName], forDocument: memberRef)
                }

                batch.commit { error in
                    completion(Result(error: error))
                }
            }
    }

    func joinGroup(inviteCode: String, user: AppUser, completion: @escaping (Result<Group, Error>) -> Void) {
        let normalizedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let db = db

        groupsCollection
            .whereField("inviteCode", isEqualTo: normalizedCode)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                guard let document = snapshot?.documents.first,
                      let group = Self.makeGroup(from: document) else {
                    completion(.failure(GroupRepositoryError.groupNotFound))
                    return
                }

                if group.memberIDs.contains(user.uid) {
                    completion(.success(group))
                    return
                }

                let groupRef = document.reference
                let batch = db.batch()
                batch.updateData(["memberIDs": FieldValue.arrayUnion([user.uid])], forDocument: groupRef)
                batch.setData(
                    Self.memberData(for: user, role: .member),
                    forDocument: groupRef.collection("members").document(user.uid)
                )

                batch.commit { error in
                    let joinedGroup = Group(
                        id: group.id,
                        name: group.name,
                        ownerID: group.ownerID,
                        memberIDs: group.memberIDs + [user.uid],
                        inviteCode: group.inviteCode
                    )
                    completion(Result(error: error).map { joinedGroup })
                }
            }
    }

    func fetchMembers(groupID: String, completion: @escaping (Result<[GroupMember], Error>) -> Void) {
        groupsCollection
            .document(groupID)
            .collection("members")
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let members = snapshot?.documents.compactMap(Self.makeMember(from:)) ?? []
                completion(.success(members))
            }
    }

    func leaveGroup(group: Group, userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard group.ownerID != userID else {
            completion(.failure(GroupRepositoryError.ownerCannotLeave))
            return
        }

        let groupRef = groupsCollection.document(group.id)

        let batch = db.batch()
        batch.updateData(["memberIDs": FieldValue.arrayRemove([userID])], forDocument: groupRef)
        batch.deleteDocument(groupRef.collection("members").document(userID))

        batch.commit { error in
            completion(Result(error: error))
        }
    }

    func deleteGroup(group: Group, userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard group.ownerID == userID else {
            completion(.failure(GroupRepositoryError.onlyOwnerCanDelete))
            return
        }

        let groupRef = groupsCollection.document(group.id)
        let db = db

        groupRef.collection("members").getDocuments { snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            let batch = db.batch()
            snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
            batch.deleteDocument(groupRef)

            batch.commit { error in
                completion(Result(error: error))
            }
        }
    }

    // MARK: - Mapping

    private static func memberData(for user: AppUser, role: GroupMember.Role) -> [String: Any] {
        [
            "uid": user.uid,
            "email": user.email,
            "displayName": user.displayName,
            "role": role.rawValue,
            "joinedAt": FieldValue.serverTimestamp()
        ]
    }

    nonisolated private static func makeGroup(from document: QueryDocumentSnapshot) -> Group? {
        let data = document.data()

        guard let name = data["name"] as? String,
              let ownerID = data["ownerID"] as? String,
              let memberIDs = data["memberIDs"] as? [String] else {
            return nil
        }

        return Group(
            id: document.documentID,
            name: name,
            ownerID: ownerID,
            memberIDs: memberIDs,
            inviteCode: data["inviteCode"] as? String ?? "초대 코드 없음"
        )
    }

    nonisolated private static func makeMember(from document: QueryDocumentSnapshot) -> GroupMember? {
        let data = document.data()

        guard let uid = data["uid"] as? String,
              let email = data["email"] as? String,
              let displayName = data["displayName"] as? String,
              let role = data["role"] as? String else {
            return nil
        }

        return GroupMember(uid: uid, email: email, displayName: displayName, role: role)
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
