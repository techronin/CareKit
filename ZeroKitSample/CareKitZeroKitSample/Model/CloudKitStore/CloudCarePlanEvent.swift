import CloudKit
import CareKit

fileprivate let EventRecordType = "CarePlanEvent"

fileprivate enum EventRecordAttr: String {
    case zeroKitUserId
    case activityType
    case data
}

fileprivate enum EventCoding: String {
    case activity
    case userId
    case recordName
}

/**
 `CloudCarePlanEvent` is a class that represents an `OCKCarePlanEvent` that is stored in the cloud, encrypted by ZeroKit.
 */
class CloudCarePlanEvent: NSObject, CloudRecordConvertible {
    let event: OCKCarePlanEvent
    let user: User
    let recordName: String
    
    private class var keysToEncrypt: [String] {
        return [EventRecordAttr.data.rawValue]
    }
    
    init(event: OCKCarePlanEvent, user: User, recordID: CKRecordID? = nil) {
        self.event = event
        self.user = user
        self.recordName = recordID?.recordName ?? UUID().uuidString
    }
    
    class func create(fromRecord record: CKRecord, user: User, completion: @escaping (CloudCarePlanEvent?, Error?) -> Void) {
        record.decryptedRecord(withKeysToDecrypt: self.keysToEncrypt) { record, error in
            guard let record = record, error == nil else {
                completion(nil, error)
                return
            }
            
            // Decode data
            let dataToDecode = record[EventRecordAttr.data.rawValue] as! Data
            let unarchiver = NSKeyedUnarchiver(forReadingWith: dataToDecode)
            let event = unarchiver.decodeObject(forKey: EventCoding.activity.rawValue) as! OCKCarePlanEvent
            let userId = unarchiver.decodeObject(forKey: EventCoding.userId.rawValue) as! String
            let recordName = unarchiver.decodeObject(forKey: EventCoding.recordName.rawValue) as! String
            
            // Not encrypted user ID in the record
            let recordUserId = record[EventRecordAttr.zeroKitUserId.rawValue] as! String
            let activityTypeNum = record[EventRecordAttr.activityType.rawValue] as! NSNumber
            let activityType = OCKCarePlanActivityType(rawValue: activityTypeNum.intValue)
            
            // Verify that the encrypted user ID matches
            if user.userId != userId ||
                recordUserId != userId ||
                user.userId != recordUserId {
                
                completion(nil, CareKitZeroKitError.inconsistencyError)
                return
            }
            
            // Verify that the encrypted record properties match
            if record.recordID.recordName != recordName ||
                event.activity.type != activityType {
                completion(nil, CareKitZeroKitError.inconsistencyError)
                return
            }
            
            let cloudEvent = CloudCarePlanEvent(event: event,
                                                user: user,
                                                recordID: record.recordID)
            
            completion(cloudEvent, nil)
        }
    }
    
    // MARK: CloudRecordConvertible protocol
    
    var recordID: CKRecordID {
        return CKRecordID(recordName: self.recordName)
    }
    
    func record(completion: @escaping (CKRecord?, Error?) -> Void) {
        let id = CKRecordID(recordName: self.recordName)
        let record = CKRecord(recordType: EventRecordType, recordID: id)
        record[EventRecordAttr.zeroKitUserId.rawValue] = self.user.userId as CKRecordValue
        record[EventRecordAttr.activityType.rawValue] = NSNumber(value: self.event.activity.type.rawValue) as CKRecordValue
        record[EventRecordAttr.data.rawValue] = self.encodedData() as CKRecordValue
        
        let tresor: Tresor
        switch self.event.activity.type {
        case .intervention:
            tresor = self.user.interventionsTresor!
        case .assessment:
            tresor = self.user.assessmentsTresor!
        }
        
        record.encryptedRecord(inTresor: tresor, keysToEncrypt: CloudCarePlanEvent.keysToEncrypt, completion: completion)
    }
    
    private func encodedData() -> Data {
        let mutableData = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: mutableData)
        archiver.encode(self.event, forKey: EventCoding.activity.rawValue)
        archiver.encode(self.user.userId, forKey: EventCoding.userId.rawValue)
        archiver.encode(self.recordName, forKey: EventCoding.recordName.rawValue)
        archiver.finishEncoding()
        return mutableData as Data
    }
    
    class func queryForAllEvents(withUser user: User) -> CKQuery {
        let prediacte = NSPredicate(format: "%K = %@", EventRecordAttr.zeroKitUserId.rawValue, user.userId)
        return CKQuery(recordType: EventRecordType, predicate: prediacte)
    }
    
    class func queryForEvents(withUser user: User, activityType: OCKCarePlanActivityType) -> CKQuery {
        let prediacte = NSPredicate(format: "%K = %@ AND %K = %@",
                                    EventRecordAttr.zeroKitUserId.rawValue, user.userId,
                                    EventRecordAttr.activityType.rawValue, NSNumber(value: activityType.rawValue))
        return CKQuery(recordType: EventRecordType, predicate: prediacte)
    }
    
    // MARK: Schema creation
    
    class var dummyRecord: CKRecord {
        let rec = CKRecord(recordType: EventRecordType, recordID: CKRecordID(recordName: "DummyEvent"))
        rec[EventRecordAttr.zeroKitUserId.rawValue] = "DummyPatient@tresorit.io" as CKRecordValue
        rec[EventRecordAttr.activityType.rawValue] = NSNumber(value: OCKCarePlanActivityType.intervention.rawValue) as CKRecordValue
        rec[EventRecordAttr.data.rawValue] = "Dummy".data(using: .utf8)! as CKRecordValue
        return rec
    }
}
