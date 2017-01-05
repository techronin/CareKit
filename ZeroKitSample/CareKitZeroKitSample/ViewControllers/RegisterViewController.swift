import UIKit
import LocalAuthentication
import ZeroKit

/**
 View controller to handle registration.
 */
class RegisterViewController: UITableViewController {
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: ZeroKitPasswordField!
    @IBOutlet weak var passwordConfirmationTextField: ZeroKitPasswordField!
    @IBOutlet weak var isDoctorSwitch: UISwitch!
    @IBOutlet weak var enableTouchIDSwitch: UISwitch!

    private var authenticator: Authenticator {
        return AppDelegate.current.authenticator
    }
    
    private var touchIDAvailable: Bool {
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        passwordTextField.matchingField = passwordConfirmationTextField
        passwordTextField.borderStyle = .none
        passwordConfirmationTextField.borderStyle = .none
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // Hide the static table view cell for Touch ID login if it is not available.
        if touchIDAvailable {
            return 2
        }
        return 1
    }

    @IBAction func registerButtonTapped(_ sender: AnyObject) {
        guard let username = usernameTextField.text,
            !passwordTextField.isEmpty &&
            !passwordConfirmationTextField.isEmpty else {
                self.showAlert("Provide a username and confirm your password")
                return
        }
        
        guard passwordTextField.passwordsMatch else {
            self.showAlert("Passwords do not match")
            return
        }
        
        self.view.endEditing(true)
        AppDelegate.current.showProgress()
        
        let type = isDoctorSwitch.isOn ? UserType.doctor : UserType.patient
        let rememberMe = enableTouchIDSwitch.isOn
        
        authenticator.register(username: username, passwordField: passwordTextField, type: type) { success, error in
            guard success else {
                AppDelegate.current.hideProgress()
                self.showAlert("Registration failed", message: "\(error)")
                return
            }
            
            self.authenticator.login(username: username, passwordField: self.passwordTextField, rememberMe: rememberMe) { success, error in
                AppDelegate.current.hideProgress()
                if !success {
                    self.showAlert("Registration was successful but login failed", message: "Please try to log in again.\n\nError: \(error)")
                }
            }
        }
    }
    
    @IBAction func cancelButtonTapped(_ sender: AnyObject) {
        self.view.endEditing(true)
        self.navigationController!.dismiss(animated: true, completion: nil)
    }
}
