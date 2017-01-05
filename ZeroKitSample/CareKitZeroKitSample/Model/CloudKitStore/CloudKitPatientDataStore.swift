import CloudKit
import CareKit
import ZeroKit

typealias AllCloudDataCallback = ([CloudCarePlanActivity]?, [CloudCarePlanEvent]?, Error?) -> Void
typealias CloudActivitiesCallback = ([CloudCarePlanActivity]?, Error?) -> Void
typealias CloudEventsCallback = ([CloudCarePlanEvent]?, Error?) -> Void

/**
 Handles fetching and saving data that belongs to a patient and is protected by ZeroKit encryption.
 */
class CloudKitPatientDataStore: NSObject {
    private let container: CKContainer
    private let publicDB: CKDatabase
    private let user: User
    
    required init(user: User) {
        self.user = user
        container = CKContainer.default()
        publicDB = container.publicCloudDatabase
    }
    
    // MARK: Fetching from cloud
    
    func fetchActivities(withType: OCKCarePlanActivityType?, completion: @escaping CloudActivitiesCallback) {
        let activitiesQuery: CKQuery
        
        if let type = withType {
            activitiesQuery = CloudCarePlanActivity.queryForAcitivites(withUser: self.user, type: type)
        } else {
            activitiesQuery = CloudCarePlanActivity.queryForAllAcitivites(withUser: self.user)
        }
        
        publicDB.perform(activitiesQuery, inZoneWith: nil) { activityRecords, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            self.activities(fromRecords: activityRecords!) { activities, error in
                DispatchQueue.main.async {
                    if error == nil {
                        completion(activities, nil)
                    } else {
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    func fetchEvents(withActivityType: OCKCarePlanActivityType?, completion: @escaping CloudEventsCallback) {
        let eventsQuery: CKQuery
        
        if let type = withActivityType {
            eventsQuery = CloudCarePlanEvent.queryForEvents(withUser: self.user, activityType: type)
        } else {
            eventsQuery = CloudCarePlanEvent.queryForAllEvents(withUser: self.user)
        }
        
        publicDB.perform(eventsQuery, inZoneWith: nil) { eventRecords, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            self.events(fromRecords: eventRecords!) { events, error in
                DispatchQueue.main.async {
                    if error == nil {
                        completion(events, nil)
                    } else {
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    private func activities(fromRecords records: [CKRecord], completion: @escaping ([CloudCarePlanActivity]?, Error?) -> Void) {
        records.asyncMap(transform: { record, resultCallback in
            CloudCarePlanActivity.create(fromRecord: record, user: self.user) { activity, error in
                resultCallback(activity, error)
            }
        }) { activities, error in
            completion(activities, error)
        }
    }
    
    private func events(fromRecords records: [CKRecord], completion: @escaping ([CloudCarePlanEvent]?, Error?) -> Void) {
        records.asyncMap(transform: { record, resultCallback in
            CloudCarePlanEvent.create(fromRecord: record, user: self.user) { event, error in
                resultCallback(event, error)
            }
        }) { events, error in
            completion(events, error)
        }
    }
    
    // MARK: Save to cloud
    
    func save(activities: [CloudCarePlanActivity], completion: @escaping (Error?) -> Void) {
        self.save(objects: activities, completion: completion)
    }
    
    func save(events: [CloudCarePlanEvent], completion: @escaping (Error?) -> Void) {
        self.save(objects: events, completion: completion)
    }
    
    func save(objects: [CloudRecordConvertible], completion: @escaping (Error?) -> Void) {
        objects.asyncMap(transform: { item, resultCallback in
            item.record { record, error in
                resultCallback(record, error)
            }
        }) { records, error in
            
            guard error == nil else {
                completion(error)
                return
            }
            
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.modifyRecordsCompletionBlock = { saved, _, error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
            
            self.publicDB.add(operation)
        }
    }
}
