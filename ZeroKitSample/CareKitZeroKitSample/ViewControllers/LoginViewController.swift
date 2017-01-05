import UIKit
import LocalAuthentication
import ZeroKit

/**
 The view controller to handle login.
 */
class LoginViewController: UITableViewController {
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: ZeroKitPasswordField!
    @IBOutlet weak var enableTouchIDSwitch: UISwitch!

    private var authenticator: Authenticator {
        return AppDelegate.current.authenticator
    }
    
    private var touchIDAvailable: Bool {
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        passwordTextField.borderStyle = .none
        
        if let lastUsername = authenticator.lastUserName {
            self.usernameTextField.text = lastUsername
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        // Hide the static table view cell for Touch ID login if it is not available.
        if touchIDAvailable {
            return 2
        }
        return 1
    }
    
    @IBAction func loginButtonTapped(_ sender: AnyObject) {
        guard let username = usernameTextField.text,
            !passwordTextField.isEmpty else {
                self.showAlert("Enter your username and password")
                return
        }
        
        self.view.endEditing(true)
        AppDelegate.current.showProgress()
        let rememberMe = enableTouchIDSwitch.isOn
        
        self.authenticator.login(username: username, passwordField: passwordTextField, rememberMe: rememberMe) { success, error in
            AppDelegate.current.hideProgress()
            if !success {
                self.showAlert("Login failed", message: "\(error)")
            }
        }
    }
    
    @IBAction func cancelButtonTapped(_ sender: AnyObject) {
        self.view.endEditing(true)
        self.navigationController!.dismiss(animated: true, completion: nil)
    }
}
