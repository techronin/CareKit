import UIKit
import CareKit

fileprivate enum PatientDetailsRow {
    case careCard
    case symptoms
    case insights
    
    var title: String {
        switch self {
        case .careCard:
            return NSLocalizedString("Care Card", comment: "")
        case .symptoms:
            return NSLocalizedString("Symptoms Tracker", comment: "")
        case .insights:
            return NSLocalizedString("Insights", comment: "")
        }
    }
}

/**
 Details view for the patient who shared their data with the logged in doctor.
 */
class PatientDetailsViewController: UITableViewController {

    private var dataShare: PatientDataShare!
    private var rows = [PatientDetailsRow]()
    private var patientStore: CarePlanStoreManager?
    fileprivate weak var insightsViewController: OCKInsightsViewController?
    
    func configure(withDataShare dataShare: PatientDataShare) {
        self.dataShare = dataShare
        var items = [PatientDetailsRow]()
        
        if dataShare.isInterventionsTresorShared {
            items.append(.careCard)
        }
        
        if dataShare.isAssessmentsTresorShared {
            items.append(.symptoms)
        }
        
        if dataShare.isInterventionsTresorShared && dataShare.isAssessmentsTresorShared {
            items.append(.insights)
        }
        
        self.rows = items
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = dataShare.patient.username
        
        self.patientStore = CarePlanStoreManager(patientDataShare: dataShare)
        self.patientStore?.delegate = self
        self.patientStore?.enableSyncWithCloud()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.rows.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = rows[indexPath.row].title
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = rows[indexPath.row]
        
        switch row {
        case .careCard:
            let vc = OCKCareCardViewController(carePlanStore: self.patientStore!.localStore)
            vc.delegate = self
            vc.title = String(format: NSLocalizedString("Care Card of %@", comment: ""), dataShare.patient.username)
            self.navigationController?.pushViewController(vc, animated: true)
            
        case .symptoms:
            let vc = OCKSymptomTrackerViewController(carePlanStore: self.patientStore!.localStore)
            vc.title = "Symptom Tracker for \(dataShare.patient.username)"
            self.navigationController?.pushViewController(vc, animated: true)
            
        case .insights:
            self.patientStore!.updateInsights()
            
            let headerTitle = NSLocalizedString("Weekly Charts", comment: "")
            let vc = OCKInsightsViewController(insightItems: self.patientStore!.insights, headerTitle: headerTitle, headerSubtitle: "")
            vc.title = "Insights for \(dataShare.patient.username)"
            insightsViewController = vc
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension PatientDetailsViewController: CarePlanStoreManagerDelegate {
    
    func carePlanStoreManager(_ manager: CarePlanStoreManager, didUpdateInsights insights: [OCKInsightItem]) {
        // Update the insights view controller with the new insights.
        insightsViewController?.items = insights
    }
}

extension PatientDetailsViewController: OCKCareCardViewControllerDelegate {
    public func careCardViewController(_ viewController: OCKCareCardViewController, shouldHandleEventCompletionFor interventionActivity: OCKCarePlanActivity) -> Bool {
        // Do not allow doctors to edit patient events
        return false
    }
}
