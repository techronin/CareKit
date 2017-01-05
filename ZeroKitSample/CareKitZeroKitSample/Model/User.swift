import ZeroKit
import CloudKit

enum UserType: Int {
    case patient
    case doctor
}

/**
 The `User` class represents a user of the CareKitZeroKitSample app. A user can either be a doctor or a patient. A patient user has tresors to encrypt their care card and symptoms data.
 */
class User: NSObject {
    let userId: String
    let username: String
    let type: UserType
    
    /** Tresor that is used to encrypt the patient's Care Card data. */
    var interventionsTresor: Tresor?
    /** Tresor that is used to encrypt the patient's Symptoms data. */
    var assessmentsTresor: Tresor?
    
    let zeroKit = AppDelegate.current.zeroKit!
    let appMock = AppDelegate.current.appMock!
    
    init(userId: String,
         username: String,
         type: UserType,
         interventionsTresorId: String?,
         assessmentsTresorId: String?) {
        
        self.userId = userId
        self.username = username
        self.type = type
        
        super.init()

        if let assessmentsTresorId = assessmentsTresorId, assessmentsTresorId.characters.count > 0 {
            self.assessmentsTresor = Tresor(tresorId: assessmentsTresorId, user: self)
        }
        
        if let interventionsTresorId = interventionsTresorId, interventionsTresorId.characters.count > 0 {
            self.interventionsTresor = Tresor(tresorId: interventionsTresorId, user: self)
        }
    }
    
    func createCarePlanTresors(completion: @escaping (Bool, Error?) -> Void) {
        self.createInterventionsTresor { success, error in
            guard success else {
                completion(success, error)
                return
            }
            
            self.createAssessmentsTresor { success, error in
                completion(success, error)
            }
        }
    }
    
    private func createInterventionsTresor(completion: @escaping (Bool, Error?) -> Void) {
        guard interventionsTresor == nil else {
            completion(true, nil)
            return
        }
        
        createTresor { success, tresorId, error in
            if success {
                CloudKitStore.update(interventionsTresorId: tresorId, assessmentsTresorId: nil, forUser: self) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.interventionsTresor = Tresor(tresorId: tresorId!, user: self)
                        }
                        completion(success, error)
                    }
                }
            } else {
                completion(false, error)
            }
        }
    }
    
    private func createAssessmentsTresor(completion: @escaping (Bool, Error?) -> Void) {
        guard assessmentsTresor == nil else {
            completion(true, nil)
            return
        }
        
        createTresor { success, tresorId, error in
            if success {
                CloudKitStore.update(interventionsTresorId: nil, assessmentsTresorId: tresorId, forUser: self) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.assessmentsTresor = Tresor(tresorId: tresorId!, user: self)
                        }
                        completion(success, error)
                    }
                }
            } else {
                completion(false, error)
            }
        }
    }
    
    private func createTresor(completion: @escaping (Bool, String?, Error?) -> Void) {
        zeroKit.createTresor { tresorId, error in
            guard error == nil else {
                completion(false, nil, error)
                return
            }
            
            self.appMock.approveTresorCreation(tresorId!, approve: true) { success in
                if success {
                    completion(true, tresorId!, nil)
                } else {
                    completion(false, nil, CareKitZeroKitError.adminCallError)
                }
            }
        }
    }
    
    func getDataShare(withDoctor doctor: User, completion: @escaping (Bool, PatientDataShare?, Error?) -> Void) {
        CloudKitStore.fetch(dataShareForPatient: self, doctor: doctor, zeroKit: zeroKit, appMock: appMock) { (success, dataShare, error) in
            DispatchQueue.main.async {
                if success {
                    if let dataShare = dataShare {
                        completion(true, dataShare, nil)
                    } else {
                        let newShare = PatientDataShare(patient: self, doctor: doctor, assessmentsShared: false, interventionsShared: false)
                        completion(true, newShare, nil)
                    }
                } else {
                    completion(false, nil, error)
                }
            }
        }
    }
    
    
    // MARK: CKRecord transform
    
    static let recordType = "User"
    
    enum RecordAttr: String {
        case zeroKitUserId
        case type
        case assessmentsTresor
        case interventionsTresor
    }
    
    convenience init(record: CKRecord) {
        
        assert(record.recordType == User.recordType, "Record type \(record.recordType) does not match expected record type \(User.recordType)")
        
        let typeNumber = record[RecordAttr.type.rawValue] as! NSNumber
        let type = UserType(rawValue: typeNumber.intValue)!
        
        self.init(userId: record[RecordAttr.zeroKitUserId.rawValue] as! String,
                  username: record.recordID.recordName,
                  type: type,
                  interventionsTresorId: record[RecordAttr.interventionsTresor.rawValue] as? String,
                  assessmentsTresorId: record[RecordAttr.assessmentsTresor.rawValue] as? String)
    }
    
    var recordID: CKRecordID {
        return CKRecordID(recordName: self.username)
    }
    
    func toCKRecord(withNewInterventionsTresorId newInterventionsTresorId: String? = nil, newAssessmentsTresorId: String? = nil) -> CKRecord {
        let record = CKRecord(recordType: User.recordType, recordID: recordID)
        
        record[RecordAttr.zeroKitUserId.rawValue] = self.userId as CKRecordValue
        record[RecordAttr.type.rawValue] = NSNumber(value: self.type.rawValue) as CKRecordValue
        
        if let newInterventionsTresorId = newInterventionsTresorId {
            record[RecordAttr.interventionsTresor.rawValue] = newInterventionsTresorId as CKRecordValue
        } else {
            record[RecordAttr.interventionsTresor.rawValue] = self.interventionsTresor?.tresorId as CKRecordValue?
        }
        
        if let newAssessmentsTresorId = newAssessmentsTresorId {
            record[RecordAttr.assessmentsTresor.rawValue] = newAssessmentsTresorId as CKRecordValue
        } else {
            record[RecordAttr.assessmentsTresor.rawValue] = self.assessmentsTresor?.tresorId as CKRecordValue?
        }
        
        return record
    }
}
