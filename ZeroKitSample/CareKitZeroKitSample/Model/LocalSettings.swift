import Foundation

class LocalSettings: NSObject {
    
    private static let loginWithTouchIDKey = "loginWithTouchIDKey"
    
    /**
     Bool value indicating if user should be logged in automatically after the app is launched.
     */
    class var loginWithTouchID: Bool {
        get {
            return UserDefaults.standard.bool(forKey: loginWithTouchIDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: loginWithTouchIDKey)
        }
    }
}
