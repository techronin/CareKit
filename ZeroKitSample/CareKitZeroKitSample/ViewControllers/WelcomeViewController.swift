import UIKit
import LocalAuthentication

/**
 View controller to init user registration and login.
 */
class WelcomeViewController: UIViewController {

    @IBOutlet weak var registerButtonBg: UIView!
    @IBOutlet weak var loginButtonBg: UIView!
    private var didTryAutologin = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let cornerRad: CGFloat = 8.0
        
        self.registerButtonBg.layer.cornerRadius = cornerRad
        self.registerButtonBg.clipsToBounds = true
        
        self.loginButtonBg.layer.cornerRadius = cornerRad
        self.loginButtonBg.clipsToBounds = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        autologinIfAvailable()
    }
    
    private func autologinIfAvailable() {
        guard !didTryAutologin else {
            return
        }
        
        didTryAutologin = true
        
        // If Touch ID is available and the user enabled Touch ID login when they previously logged in, then we use it to authenticate the user and log in without needing to enter their password.
        
        let context = LAContext()
        guard AppDelegate.current.authenticator.canAutologin() &&
            LocalSettings.loginWithTouchID &&
            context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
                
                return
        }
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to log in") { (success, error) in
            if success {
                DispatchQueue.main.async {
                    AppDelegate.current.showProgress()
                    AppDelegate.current.authenticator.autologin { (success, error) in
                        AppDelegate.current.hideProgress()
                    }
                }
            }
        }
    }
}
