import UIKit
import CareKit

/**
 Contains the list of patients who their data with the logged in doctor.
 */
class MyPatientsViewController: UITableViewController {

    fileprivate var dataShares = [PatientDataShare]()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let currentUser = AppDelegate.current.authenticator.currentUser!
        
        CloudKitStore.fetch(patientDataSharesForDoctor: currentUser) { (success, dataShares, error) in
            
            DispatchQueue.main.async {
                if success {
                    self.dataShares = dataShares ?? []
                    self.tableView.reloadData()
                } else {
                    self.showAlert("Failed to fetch shares for doctor", message: "\(error)")
                }
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataShares.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let share = dataShares[indexPath.row]
        cell.textLabel?.text = share.patient.username
        cell.detailTextLabel?.text = MyDoctorsViewController.shareDetailsDescription(forShare: share)
        
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destVC = segue.destination as! PatientDetailsViewController
        let indexPath = self.tableView.indexPathForSelectedRow!
        let share = self.dataShares[indexPath.row]
        destVC.configure(withDataShare: share)
    }
}


