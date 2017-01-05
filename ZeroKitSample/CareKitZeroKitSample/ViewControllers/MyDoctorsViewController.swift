import UIKit

/**
 Contains the list of doctors whom the user shared their interventions or assessments tresors with.
 */
class MyDoctorsViewController: UITableViewController {

    private var dataShares = [PatientDataShare]()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let currentUser = AppDelegate.current.authenticator.currentUser!
        
        CloudKitStore.fetch(dataSharesForPatient: currentUser) { (success, dataShares, error) in
            
            DispatchQueue.main.async {
                if success {
                    self.dataShares = dataShares ?? []
                    self.tableView.reloadData()
                } else {
                    self.showAlert("Failed to fetch shares for patient", message: "\(error)")
                }
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataShares.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        let share = dataShares[indexPath.row]
        
        cell.textLabel?.text = share.doctor.username
        cell.detailTextLabel?.text = MyDoctorsViewController.shareDetailsDescription(forShare: share)
        
        return cell
    }
    
    class func shareDetailsDescription(forShare share: PatientDataShare) -> String {
        var shareDetails = ""
        var notShared = true
        
        if share.isInterventionsTresorShared {
            shareDetails.append("Care Card")
            notShared = false
        }
        if share.isAssessmentsTresorShared {
            if shareDetails.characters.count > 0 {
                shareDetails.append(", ")
            }
            shareDetails.append("Symptoms")
            notShared = false
        }
        
        if notShared {
            shareDetails = "No data shared"
        } else {
            shareDetails.append(" data shared")
        }
        
        return shareDetails
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let navVC = segue.destination as! UINavigationController
        let shareVC = navVC.viewControllers.first! as! PatientDataShareViewController
        
        if segue.identifier! == "existingShareSegue" {
            let index = self.tableView.indexPathForSelectedRow!.row
            let share = self.dataShares[index]
            shareVC.configureForExisting(dataShare: share)
        } else if segue.identifier! == "newShareSegue" {
            shareVC.configureForNewDataShare()
        } else {
            assert(false, "Unhandled segue")
        }
    }
}
