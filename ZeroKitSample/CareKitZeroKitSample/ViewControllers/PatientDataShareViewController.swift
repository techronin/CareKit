import UIKit

/**
 View controller to handle sharing the patient's data with a doctor.
 */
class PatientDataShareViewController: UITableViewController {
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var shareCareCardSwitch: UISwitch!
    @IBOutlet weak var shareSymptomsSwitch: UISwitch!
    @IBOutlet weak var removeButton: UIButton!

    private var dataShare: PatientDataShare?
    private var isNewShare = false
    
    var currentUser: User {
        return AppDelegate.current.authenticator.currentUser!
    }
    
    func configureForNewDataShare() {
        isNewShare = true
    }
    
    func configureForExisting(dataShare: PatientDataShare) {
        self.dataShare = dataShare
        isNewShare = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if self.dataShare == nil {
            self.showNewShare()
        } else {
            self.showExistingShare()
        }
    }
    
    private func showNewShare() {
        self.title = "Add new doctor"
        self.usernameTextField.isHidden = false
        self.removeButton.isHidden = true
    }
    
    private func showExistingShare() {
        self.title = dataShare!.doctor.username
        self.usernameTextField.isHidden = true
        self.shareCareCardSwitch.isOn = dataShare!.isInterventionsTresorShared
        self.shareSymptomsSwitch.isOn = dataShare!.isAssessmentsTresorShared
        self.removeButton.isHidden = false
    }
    
    @IBAction func cancelButtonTapped(_ sender: AnyObject) {
        self.view.endEditing(true)
        self.dismiss()
    }
    
    @IBAction func doneButtonTapped(_ sender: AnyObject) {
        self.view.endEditing(true)
        if self.dataShare != nil {
            performSharing()
        } else {
            createNewShare()
        }
    }
    
    @IBAction func removeButtonTapped(_ sender: Any) {
        self.view.endEditing(true)
        
        let sheet = UIAlertController(title: "Remove \(dataShare!.doctor.username)?", message: nil, preferredStyle: .actionSheet)
        
        let logoutAction = UIAlertAction(title: "Remove", style: .destructive) { action in
            self.removeShare()
        }
        sheet.addAction(logoutAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        sheet.addAction(cancelAction)
        
        self.present(sheet, animated: true, completion: nil)
    }
    
    private func removeShare() {
        guard let existingShare = self.dataShare else {
            return
        }
        
        AppDelegate.current.showProgress()
        
        share(interventions: false, assessments: false) { error in
            CloudKitStore.remove(patientDataShare: existingShare) { (success, error) in
                DispatchQueue.main.async {
                    AppDelegate.current.hideProgress()
                    
                    if let error = error {
                        self.showAlert("Error while removing", message: "\(error)")
                    } else {
                        self.dismiss()
                    }
                }
            }
        }
    }
    
    private func performSharing() {
        AppDelegate.current.showProgress()
        
        share(interventions: self.shareCareCardSwitch.isOn, assessments: self.shareSymptomsSwitch.isOn) { error in
            AppDelegate.current.hideProgress()
            
            if let error = error {
                self.showAlert("Error while sharing", message: "\(error)")
            } else {
                self.dismiss()
            }
        }
    }
    
    private func share(interventions shareInterventions: Bool, assessments shareAssessments: Bool, completion: @escaping (Error?) -> Void) {
        
        let shareInterventionsChanged = self.dataShare?.isInterventionsTresorShared != shareInterventions
        let shareAssessmentsChanged = self.dataShare?.isAssessmentsTresorShared != shareAssessments
        
        DispatchQueue.global().async {
            var error2: Error?
            
            do {
                if shareInterventionsChanged {
                    try self.dataShare!.synchronouslyShare(interventions: shareInterventions)
                }
                
                if shareAssessmentsChanged {
                    try self.dataShare!.synchronouslyShare(assessments: shareAssessments)
                }
            } catch {
                error2 = error
            }
            
            DispatchQueue.main.async {
                completion(error2)
            }
        }
    }
    
    private func createNewShare() {
        guard let username = self.usernameTextField.text,
            username.characters.count > 0 else {
                self.showAlert("Enter a username to share with")
                return
        }
        
        AppDelegate.current.showProgress()
        
        CloudKitStore.fetch(userForUsername: username) { success, user, error in
            DispatchQueue.main.async {
                guard success else {
                    self.showAlert("Failed fetching user: '\(username)'", message: "\(error)")
                    AppDelegate.current.hideProgress()
                    return
                }
                
                guard let user = user else {
                    self.showAlert("User '\(username)' not found.")
                    AppDelegate.current.hideProgress()
                    return
                }
                
                self.currentUser.getDataShare(withDoctor: user) { success, dataShare, error in
                    guard success else {
                        self.showAlert("Failed fetching share", message: "\(error)")
                        AppDelegate.current.hideProgress()
                        return
                    }
                    
                    self.dataShare = dataShare!
                    self.performSharing()
                }
            }
        }
    }
    
    private func dismiss() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if isNewShare {
            return 1
        }
        
        return super.numberOfSections(in: tableView)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && indexPath.row == 0 {
            // username row
            if isNewShare {
                return UITableViewAutomaticDimension
            } else {
                return 0
            }
        }
        
        return UITableViewAutomaticDimension
    }
}
