import CareKit

protocol CarePlanStoreManagerDelegate: class {
    
    func carePlanStoreManager(_ manager: CarePlanStoreManager, didUpdateInsights insights: [OCKInsightItem])
    
}

/** 
 The `CarePlanStoreManager` class manages the local care plan store and the cloud kit store. Schedules updates from the cloud and pushes local changes to the cloud when they happen.
 */
class CarePlanStoreManager: NSObject {
    
    let user: User
    let patientDataShare: PatientDataShare?
    let localStore: OCKCarePlanStore
    let cloudStore: CloudKitPatientDataStore
    
    weak var delegate: CarePlanStoreManagerDelegate?
    var isUpdatingFromCloud = false
    
    var insights: [OCKInsightItem] {
        return insightsBuilder.insights
    }
    
    fileprivate let insightsBuilder: InsightsBuilder
    
    fileprivate var cloudSync: CloudSync?
    
    class var localStoreDirectoryUrl: URL {
        let searchPaths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let applicationSupportPath = searchPaths[0]
        return URL(fileURLWithPath: applicationSupportPath).appendingPathComponent("localdb")
    }
    
    class func deleteLocalStore() -> Bool {
        var success = true
        do {
            try FileManager.default.removeItem(at: localStoreDirectoryUrl)
        } catch {
            success = false
            print("Failed to delete local store data: \(error)")
        }
        return success
    }
    
    // MARK: Initialization
    
    convenience init(patientDataShare: PatientDataShare) {
        self.init(patient: patientDataShare.patient, patientDataShare: patientDataShare)
    }
    
    convenience init(patient: User) {
        self.init(patient: patient, patientDataShare: nil)
    }
    
    required init(patient: User, patientDataShare: PatientDataShare?) {
        self.user = patient
        self.patientDataShare = patientDataShare
        
        // Create the store.
        let persistenceDirectoryURL = CarePlanStoreManager.localStoreDirectoryUrl.appendingPathComponent(user.username)
        
        if !FileManager.default.fileExists(atPath: persistenceDirectoryURL.absoluteString, isDirectory: nil) {
            try! FileManager.default.createDirectory(at: persistenceDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        localStore = OCKCarePlanStore(persistenceDirectoryURL: persistenceDirectoryURL)
        cloudStore = CloudKitPatientDataStore(user: user)
        
        /*
         Create an `InsightsBuilder` to build insights based on the data in
         the store.
         */
        insightsBuilder = InsightsBuilder(carePlanStore: localStore)
        
        super.init()
        
        // Register this object as the store's delegate to be notified of changes.
        localStore.delegate = self
        
        // Start to build the initial array of insights.
        updateInsights()
    }
    
    func updateInsights() {
        insightsBuilder.updateInsights { [weak self] completed, newInsights in
            // If new insights have been created, notifiy the delegate.
            guard let storeManager = self, let newInsights = newInsights , completed else { return }
            storeManager.delegate?.carePlanStoreManager(storeManager, didUpdateInsights: newInsights)
        }
    }
    
    func enableSyncWithCloud() {
        if cloudSync == nil {
            cloudSync = CloudSync(storeManager: self)
        }
        cloudSync?.scheduleSync()
        cloudSync?.syncData()
    }
    
    deinit {
        self.cloudSync?.unscheduleSync()
    }
}

extension CarePlanStoreManager: OCKCarePlanStoreDelegate {
    @objc public func carePlanStoreActivityListDidChange(_ store: OCKCarePlanStore) {
        updateInsights()
        
        if !isUpdatingFromCloud {
            cloudSync?.syncData()
        }
    }
    
    @objc public func carePlanStore(_ store: OCKCarePlanStore, didReceiveUpdateOf event: OCKCarePlanEvent) {
        updateInsights()
        
        if !isUpdatingFromCloud {
            cloudSync?.update(eventInCloud: event)
        }
    }
    
    @objc public func carePlanStoreWillBeginEvents(forCloudUpdates store: OCKCarePlanStore) {
        isUpdatingFromCloud = true
    }
    
    @objc public func carePlanStoreDidEndEvents(forCloudUpdates store: OCKCarePlanStore) {
        isUpdatingFromCloud = false
    }
}
