import UIKit
import LocalAuthentication

class AccountViewController: UITableViewController {

    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var userIdLabel: UILabel!
    
    var authenticator: Authenticator {
        return AppDelegate.current.authenticator
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.usernameLabel.text = authenticator.currentUser?.username
        self.userIdLabel.text = authenticator.currentUser?.userId
    }
    
    @IBAction func logoutButtonTapped(_ sender: AnyObject) {
        let sheet = UIAlertController(title: "Log out?", message: nil, preferredStyle: .actionSheet)
        
        let logoutAction = UIAlertAction(title: "Log out", style: .destructive) { action in
            self.authenticator.logout { success, error in
                if !success {
                    self.showAlert("Logout failed", message: "\(error)")
                }
            }
        }
        sheet.addAction(logoutAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        sheet.addAction(cancelAction)
        
        self.present(sheet, animated: true, completion: nil)
    }
}
