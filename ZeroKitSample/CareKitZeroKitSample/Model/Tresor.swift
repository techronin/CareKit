import ZeroKit

/**
 The `Tresor` class represents a user's tresor. Tresors are used to encrypt and decrypt data.
 */
class Tresor: NSObject {
    let tresorId: String
    private(set) weak var user: User?
    
    init(tresorId: String, user: User) {
        self.tresorId = tresorId
        self.user = user
    }
}
