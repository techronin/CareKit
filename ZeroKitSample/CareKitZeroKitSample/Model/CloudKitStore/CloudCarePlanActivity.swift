import CloudKit
import CareKit

fileprivate let ActivityRecordType = "CarePlanActivity"

fileprivate enum ActivityRecordAttr: String {
    case zeroKitUserId
    case activityType
    case data
}

fileprivate enum ActivityCoding: String {
    case activity
    case isDeleted
    case userId
    case recordName
}

/**
 `CloudCarePlanActivity` is a class that represents an `OCKCarePlanActivity` that is stored in the cloud, encrypted by ZeroKit.
 */
class CloudCarePlanActivity: NSObject, CloudRecordConvertible {
    let activity: OCKCarePlanActivity
    let isDeleted: Bool
    let user: User
    let recordName: String
    
    private class var keysToEncrypt: [String] {
        return [ActivityRecordAttr.data.rawValue]
    }
    
    init(activity: OCKCarePlanActivity, isDeleted: Bool, user: User, recordID: CKRecordID? = nil) {
        self.activity = activity
        self.isDeleted = isDeleted
        self.user = user
        self.recordName = recordID?.recordName ?? UUID().uuidString
    }
    
    class func create(fromRecord record: CKRecord, user: User, completion: @escaping (CloudCarePlanActivity?, Error?) -> Void) {
        record.decryptedRecord(withKeysToDecrypt: self.keysToEncrypt) { record, error in
            guard let record = record, error == nil else {
                completion(nil, error)
                return
            }
            
            // Decode data
            let dataToDecode = record[ActivityRecordAttr.data.rawValue] as! Data
            let unarchiver = NSKeyedUnarchiver(forReadingWith: dataToDecode)
            let activity = unarchiver.decodeObject(forKey: ActivityCoding.activity.rawValue) as! OCKCarePlanActivity
            let isDeleted = unarchiver.decodeBool(forKey: ActivityCoding.isDeleted.rawValue)
            let userId = unarchiver.decodeObject(forKey: ActivityCoding.userId.rawValue) as! String
            let recordName = unarchiver.decodeObject(forKey: ActivityCoding.recordName.rawValue) as! String
            
            // Not encrypted user ID in the record
            let recordUserId = record[ActivityRecordAttr.zeroKitUserId.rawValue] as! String
            let activityTypeNum = record[ActivityRecordAttr.activityType.rawValue] as! NSNumber
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
                activity.type != activityType {
                completion(nil, CareKitZeroKitError.inconsistencyError)
                return
            }
            
            let cloudActivity = CloudCarePlanActivity(activity: activity,
                                                      isDeleted: isDeleted,
                                                      user: user,
                                                      recordID: record.recordID)
            
            completion(cloudActivity, nil)
        }
    }
    
    // MARK: CloudRecordConvertible protocol
    
    var recordID: CKRecordID {
        return CKRecordID(recordName: self.recordName)
    }
    
    func record(completion: @escaping (CKRecord?, Error?) -> Void) {
        let record = CKRecord(recordType: ActivityRecordType, recordID: recordID)
        record[ActivityRecordAttr.zeroKitUserId.rawValue] = self.user.userId as CKRecordValue
        record[ActivityRecordAttr.activityType.rawValue] = NSNumber(value: self.activity.type.rawValue) as CKRecordValue
        record[ActivityRecordAttr.data.rawValue] = self.encodedData() as CKRecordValue
        
        let tresor: Tresor
        switch self.activity.type {
        case .intervention:
            tresor = self.user.interventionsTresor!
        case .assessment:
            tresor = self.user.assessmentsTresor!
        }
        
        record.encryptedRecord(inTresor: tresor, keysToEncrypt: CloudCarePlanActivity.keysToEncrypt, completion: completion)
    }
    
    private func encodedData() -> Data {
        let mutableData = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: mutableData)
        archiver.encode(self.activity, forKey: ActivityCoding.activity.rawValue)
        archiver.encode(self.isDeleted, forKey: ActivityCoding.isDeleted.rawValue)
        archiver.encode(self.user.userId, forKey: ActivityCoding.userId.rawValue)
        archiver.encode(self.recordName, forKey: ActivityCoding.recordName.rawValue)
        archiver.finishEncoding()
        return mutableData as Data
    }
    
    class func queryForAllAcitivites(withUser user: User) -> CKQuery {
        let prediacte = NSPredicate(format: "%K = %@", ActivityRecordAttr.zeroKitUserId.rawValue, user.userId)
        return CKQuery(recordType: ActivityRecordType, predicate: prediacte)
    }
    
    class func queryForAcitivites(withUser user: User, type: OCKCarePlanActivityType) -> CKQuery {
        let prediacte = NSPredicate(format: "%K = %@ AND %K = %@",
                                    ActivityRecordAttr.zeroKitUserId.rawValue, user.userId,
                                    ActivityRecordAttr.activityType.rawValue, NSNumber(value: type.rawValue))
        return CKQuery(recordType: ActivityRecordType, predicate: prediacte)
    }
    
    // MARK: Schema creation
    
    class var dummyRecord: CKRecord {
        let rec = CKRecord(recordType: ActivityRecordType, recordID: CKRecordID(recordName: "DummyActivity"))
        rec[ActivityRecordAttr.zeroKitUserId.rawValue] = "DummyPatient@tresorit.io" as CKRecordValue
        rec[ActivityRecordAttr.activityType.rawValue] = NSNumber(value: OCKCarePlanActivityType.intervention.rawValue) as CKRecordValue
        rec[ActivityRecordAttr.data.rawValue] = "Dummy".data(using: .utf8)! as CKRecordValue
        return rec
    }
}
