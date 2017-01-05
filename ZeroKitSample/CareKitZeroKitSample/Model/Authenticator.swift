import ZeroKit
import Security

public extension NSNotification.Name {
    public static var AuthenticatorDidLogIn: NSNotification.Name { get { return NSNotification.Name("AuthenticatorDidLogIn") } }
    public static var AuthenticatorDidLogOut: NSNotification.Name { get { return NSNotification.Name("AuthenticatorDidLogOut") } }
}


/**
 The `Authenticator` class handles user registration, login and logout via ZeroKit.
 */
class Authenticator: NSObject {

    let zeroKit: ZeroKit
    let appMock: ExampleAppMock
    private(set) var currentUser: User?
    
    init(zeroKit: ZeroKit, appMock: ExampleAppMock) {
        self.zeroKit = zeroKit
        self.appMock = appMock
        super.init()
    }
    
    private let lastUserNameKey = "lastUserNameKey"
    public private(set) var lastUserName: String? {
        get {
            return UserDefaults.standard.string(forKey: lastUserNameKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastUserNameKey)
        }
    }
    
    private let lastUserIdKey = "lastUserIdKey"
    private var lastUserId: String? {
        get {
            return UserDefaults.standard.string(forKey: lastUserIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastUserIdKey)
        }
    }
    
    func canAutologin() -> Bool {
        if let userId = self.lastUserId, self.lastUserName != nil {
            return zeroKit.canLoginByRememberMe(with: userId)
        }
        return false
    }
    
    /**
     We can use autologin if the user previously logged in with `rememberMe` set to true. Check if it is available by calling `canAutologin()` first.
     */
    func autologin(completion: @escaping (Bool, Error?) -> Void) {
        guard let username = self.lastUserName, let userId = self.lastUserId else {
            completion(false, CareKitZeroKitError.notFoundError)
            return
        }
        
        CloudKitStore.fetch(userForUsername: username) { success, user, error in
            guard let user = user, success, user.userId == userId else {
                DispatchQueue.main.async {
                    completion(false, error)
                }
                return
            }
            
            self.zeroKit.loginByRememberMe(with: userId) { error in
                self.handleLogin(user: user, error: error, completion: completion)
            }
        }
    }
    
    func login(username: String, passwordField: ZeroKitPasswordField, rememberMe: Bool, completion: @escaping (Bool, Error?) -> Void) {
        CloudKitStore.fetch(userForUsername: username) { success, user, error in
            guard let user = user, success else {
                DispatchQueue.main.async {
                    completion(false, error)
                }
                return
            }
            
            self.zeroKit.login(withUserId: user.userId, passwordField: passwordField, rememberMe: rememberMe) { error in
                LocalSettings.loginWithTouchID = rememberMe
                self.handleLogin(user: user, error: error, completion: completion)
            }
        }
    }
    
    private func handleLogin(user: User, error: Error?, completion: @escaping (Bool, Error?) -> Void) {
        guard error == nil else {
            completion(false, error)
            return
        }
        
        self.lastUserName = user.username
        self.lastUserId = user.userId
        self.currentUser = user
        
        completion(true, nil)
        NotificationCenter.default.post(name: NSNotification.Name.AuthenticatorDidLogIn, object: self)
    }

    func logout(completion: @escaping (Bool, Error?) -> Void) {
        self.lastUserName = nil
        self.lastUserId = nil
        LocalSettings.loginWithTouchID = false
        
        zeroKit.logout { error in
            guard error == nil else {
                completion(false, error)
                return
            }
            
            self.currentUser = nil
            completion(true, nil)
            NotificationCenter.default.post(name: NSNotification.Name.AuthenticatorDidLogOut, object: self)
        }
    }
    
    func register(username: String, passwordField: ZeroKitPasswordField, type: UserType, completion: @escaping (Bool, Error?) -> Void) {
        /// 1. You must initialize a user registration with the admin. You should send a request to your application's backend to do this.
        appMock.initUserRegistration { (success, userId, regSessionId, regSessionVerifier) -> (Void) in
            guard success else {
                completion(false, CareKitZeroKitError.adminCallError)
                return
            }
            
            /// 2. You register the user with their password via ZeroKit.
            self.zeroKit.register(withUserId: userId!, registrationId: regSessionId!, passwordField: passwordField) { regValidationVerifier, error in
                guard error == nil else {
                    completion(false, error)
                    return
                }
                
                /// 3. Once the user is registered they must be validated with an admin call made by your backend.
                self.appMock.validateUser(userId!, regSessionId: regSessionId!, regSessionVerifier: regSessionVerifier!, regValidationVerifier: regValidationVerifier!) { (success) -> (Void) in
                    
                    if success {
                        let user = User(userId: userId!, username: username, type: type, interventionsTresorId: nil, assessmentsTresorId: nil)
                        
                        CloudKitStore.save(user: user) { success, error in
                            DispatchQueue.main.async {
                                if success {
                                    completion(true, nil)
                                } else {
                                    completion(false, error)
                                }
                            }
                        }
                        
                    } else {
                        completion(false, CareKitZeroKitError.adminCallError)
                    }
                }
            }
        }
    }
}
