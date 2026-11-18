import Foundation

struct GroupMember {
    enum Role: String {
        case owner
        case member
    }

    let uid: String
    let email: String
    let displayName: String
    let role: String

    var isOwner: Bool {
        role == Role.owner.rawValue
    }
}

extension Array where Element == GroupMember {
    /// Owner first, then members by display name.
    func sortedForDisplay() -> [GroupMember] {
        sorted { first, second in
            if first.isOwner != second.isOwner {
                return first.isOwner
            }
            return first.displayName < second.displayName
        }
    }
}
