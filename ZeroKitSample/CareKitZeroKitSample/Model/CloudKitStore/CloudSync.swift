import CareKit

/**
 This class keeps the local and cloud database in sync.
 */
class CloudSync: NSObject {
    private weak var storeManager: CarePlanStoreManager?
    
    private var isSyncing = false
    private var syncAgain = false
    
    private var syncTimer: Timer?
    private var isSyncScheduled = false
    
    init(storeManager: CarePlanStoreManager) {
        self.storeManager = storeManager
    }
    
    private var activityTypeToFetch: OCKCarePlanActivityType? {
        if let share = self.storeManager?.patientDataShare {
            if share.isAssessmentsTresorShared && share.isInterventionsTresorShared {
                // fetch all, do not specify
                return nil
            }
            
            if share.isAssessmentsTresorShared {
                return OCKCarePlanActivityType.assessment
            }
            
            if share.isInterventionsTresorShared {
                return OCKCarePlanActivityType.intervention
            }
        }
        return nil
    }
    
    // MARK: Schedule
    
    func scheduleSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(syncTimerFired(timer:)), userInfo: nil, repeats: false)
        isSyncScheduled = true
    }
    
    @objc private func syncTimerFired(timer: Timer) {
        syncTimer = nil
        self.syncData()
    }
    
    func unscheduleSync() {
        syncTimer?.invalidate()
        isSyncScheduled = false
    }
    
    // MARK: Cloud data synchronization
    
    /**
     Performs some simple synchonization by fetching all cloud and local records and updating them as needed.
     */
    func syncData() {
        guard let _ = self.storeManager else {
            return
        }
        
        if isSyncing {
            syncAgain = true
            return
        }
        
        isSyncing = true
        
        let finished = {
            DispatchQueue.main.async {
                self.isSyncing = false
                let needToSyncAgain = self.syncAgain
                self.syncAgain = false
                
                if needToSyncAgain || self.isSyncScheduled {
                    self.scheduleSync()
                }
            }
        }
        
        syncActivitiesWithCloud { error in
            guard error == nil else {
                print("Error syncing activities: \(error!)")
                finished()
                return
            }
            
            self.syncEventsWithCloud { error in
                if let error = error {
                    print("Error syncing events: \(error)")
                }
                finished()
            }
        }
    }
    
    private func syncActivitiesWithCloud(completion: @escaping (Error?) -> Void) {
        let storeManager = self.storeManager!
        let activityType = self.activityTypeToFetch
        
        let localActivitiesCompletion = { (success: Bool, localActivities: [OCKCarePlanActivity], error: Error?) -> Void in
            guard success else {
                completion(error)
                return
            }
            
            // Fetch cloud activities.
            storeManager.cloudStore.fetchActivities(withType: activityType) { fetchedCloudActivities, error in
                guard error == nil else {
                    completion(error)
                    return
                }
                
                let cloudActivities = fetchedCloudActivities ?? []
                self.sync(localActivities: localActivities, withCloudActivities: cloudActivities, completion: completion)
            }
        }
        
        // Fetch local activities.
        if let activityType = activityType {
            storeManager.localStore.activities(with: activityType, completion: localActivitiesCompletion)
        } else {
            storeManager.localStore.activities(completion: localActivitiesCompletion)
        }
    }
    
    private func syncEventsWithCloud(completion: @escaping (Error?) -> Void) {
        let storeManager = self.storeManager!
        let activityType = self.activityTypeToFetch
        
        let localEventsCompletion = { (success: Bool, localEvents: [OCKCarePlanEvent], error: Error?) -> Void in
            guard success else {
                completion(error)
                return
            }
            
            storeManager.cloudStore.fetchEvents(withActivityType: self.activityTypeToFetch) { fetchedCloudEvents, error in
                guard error == nil else {
                    completion(error)
                    return
                }
                
                let cloudEvents = fetchedCloudEvents ?? []
                self.sync(localEvents: localEvents, withCloudEvents: cloudEvents, completion: completion)
            }
        }
        
        if let activityType = activityType {
            storeManager.localStore.eventsForActivities(with: activityType, completion: localEventsCompletion)
        } else {
            storeManager.localStore.events(completion: localEventsCompletion)
        }
    }
    
    private func sync(localActivities: [OCKCarePlanActivity], withCloudActivities: [CloudCarePlanActivity], completion: @escaping (Error?) -> Void) {
        let storeManager = self.storeManager!
        
        // Compare, push changes to cloud and update locally.
        // We use modification dates to check if a record is later than the other.
        
        var cloudActivitiesToPush = [CloudCarePlanActivity]()
        var activitiesToAdd = [OCKCarePlanActivity]()
        var activitiesToUpdate = [OCKCarePlanActivity]()
        var activitiesToRemove = [OCKCarePlanActivity]()
        
        var cloudActivities = withCloudActivities
        
        for localActivity in localActivities {
            var cloudActivity: CloudCarePlanActivity?
            var cloudActivityIndex: Int?
            
            for (index, existingCloudActivity) in cloudActivities.enumerated() {
                if localActivity.identifier == existingCloudActivity.activity.identifier {
                    cloudActivity = existingCloudActivity
                    cloudActivityIndex = index
                    break
                }
            }
            
            if let cloudActivity = cloudActivity {
                // A cloud activity already exists for this activity
                
                cloudActivities.remove(at: cloudActivityIndex!)
                
                if localActivity.modificationDate == cloudActivity.activity.modificationDate {
                    // It is either the same or was modified at the same time. Leave it be.
                    continue
                }
                
                let isLocalActivityLater =
                    (localActivity.modificationDate != nil && cloudActivity.activity.modificationDate == nil) ||
                        (localActivity.modificationDate != nil && cloudActivity.activity.modificationDate != nil &&
                            localActivity.modificationDate! > cloudActivity.activity.modificationDate!)
                
                if isLocalActivityLater {
                    // Push existing to cloud
                    let newCloudActivity = CloudCarePlanActivity(activity: localActivity,
                                                                 isDeleted: false,
                                                                 user: cloudActivity.user,
                                                                 recordID: cloudActivity.recordID)
                    cloudActivitiesToPush.append(newCloudActivity)
                    
                } else {
                    // Update locally
                    if cloudActivity.isDeleted {
                        activitiesToRemove.append(cloudActivity.activity)
                    } else {
                        activitiesToUpdate.append(cloudActivity.activity)
                    }
                }
                
            } else {
                // Push new entry to cloud
                let newCloudActivity = CloudCarePlanActivity(activity: localActivity,
                                                             isDeleted: false,
                                                             user: storeManager.user,
                                                             recordID: nil)
                cloudActivitiesToPush.append(newCloudActivity)
            }
        }
        
        for existingCloudActivity in cloudActivities {
            // These cloud activities do not have local pair
            if !existingCloudActivity.isDeleted {
                activitiesToAdd.append(existingCloudActivity.activity)
            }
        }
        
        // Update activities
        
        storeManager.cloudStore.save(activities: cloudActivitiesToPush) { error in
            guard error == nil else {
                completion(error)
                return
            }
            
            storeManager.localStore.addActivities(activitiesToAdd,
                                                  updateActivities: activitiesToUpdate,
                                                  removeActivities: activitiesToRemove,
                                                  isChangeFromCloud: true) { success, error in
                                                    
                                                    completion(error)
            }
        }
    }
    
    private func sync(localEvents: [OCKCarePlanEvent], withCloudEvents: [CloudCarePlanEvent], completion: @escaping (Error?) -> Void) {
        let storeManager = self.storeManager!
        
        // Compare, push changes to cloud and update locally.
        // We use modification dates to check if a record is later than the other.
        
        var cloudEventsToPush = [CloudCarePlanEvent]()
        var eventsToAdd = [OCKCarePlanEvent]()
        var eventsToUpdate = [OCKCarePlanEvent]()
        
        var cloudEvents = withCloudEvents
        
        for localEvent in localEvents {
            var cloudEvent: CloudCarePlanEvent?
            var cloudEventIndex: Int?
            
            for (index, existingCloudEvent) in cloudEvents.enumerated() {
                if localEvent.occurrenceIndexOfDay == existingCloudEvent.event.occurrenceIndexOfDay &&
                    localEvent.numberOfDaysSinceStart == existingCloudEvent.event.numberOfDaysSinceStart &&
                    localEvent.activity.identifier == existingCloudEvent.event.activity.identifier {
                    
                    cloudEvent = existingCloudEvent
                    cloudEventIndex = index
                    break
                }
            }
            
            if let cloudEvent = cloudEvent {
                // A cloud event already exists for this event
                
                cloudEvents.remove(at: cloudEventIndex!)
                
                if localEvent.modificationDate == cloudEvent.event.modificationDate {
                    // It is either the same or was modified at the same time. Leave it be.
                    continue
                }
                
                let isLocalEventLater =
                    (localEvent.modificationDate != nil && cloudEvent.event.modificationDate == nil) ||
                        (localEvent.modificationDate != nil && cloudEvent.event.modificationDate != nil &&
                            localEvent.modificationDate! > cloudEvent.event.modificationDate!)
                
                if isLocalEventLater {
                    // Push existing to cloud
                    let newCloudEvent = CloudCarePlanEvent(event: localEvent,
                                                           user: cloudEvent.user,
                                                           recordID: cloudEvent.recordID)
                    cloudEventsToPush.append(newCloudEvent)
                    
                } else {
                    // Update locally
                    eventsToUpdate.append(cloudEvent.event)
                }
                
            } else {
                // Push new entry to cloud
                let newCloudEvent = CloudCarePlanEvent(event: localEvent,
                                                       user: storeManager.user,
                                                       recordID: nil)
                cloudEventsToPush.append(newCloudEvent)
            }
        }
        
        for existingCloudEvent in cloudEvents {
            // These cloud events do not have local pair
            eventsToAdd.append(existingCloudEvent.event)
        }
        
        // Update activities
        
        storeManager.cloudStore.save(events: cloudEventsToPush) { error in
            guard error == nil else {
                completion(error)
                return
            }
            
            var eventsToUpdateLocally = eventsToAdd
            eventsToUpdateLocally.append(contentsOf: eventsToUpdate)
            
            let eventsCount = eventsToUpdateLocally.count
            var updatedCount = 0
            var outError: Error? = nil
            
            let completeIfFinished = {
                if updatedCount == eventsCount {
                    completion(outError)
                }
            }
            
            // TODO: Update all events with one care plan store call
            for event in eventsToUpdateLocally {
                storeManager.localStore.updateCloudEvent(event, with: event.result, state: event.state) { success, updatedEvent, error in
                    DispatchQueue.main.async {
                        updatedCount += 1
                        if let error = error {
                            outError = error
                        }
                        
                        completeIfFinished()
                    }
                }
            }
            
            completeIfFinished()
        }
    }
    
    func update(eventInCloud event: OCKCarePlanEvent) {
        // TODO: Sync the changed events only
        self.syncData()
    }
}
