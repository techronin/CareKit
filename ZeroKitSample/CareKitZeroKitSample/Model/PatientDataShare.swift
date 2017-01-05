import ZeroKit
import CareKit
import CloudKit

/**
 The `PatientDataShare` class represents tresor sharing status between the patient and the doctor. The patient can share their assessments and interventions tresor with the doctor.
 */
class PatientDataShare: NSObject {
    let patient: User
    let doctor: User
    
    private(set) var isAssessmentsTresorShared: Bool
    private(set) var isInterventionsTresorShared: Bool
    
    let zeroKit = AppDelegate.current.zeroKit!
    let appMock = AppDelegate.current.appMock!
    
    init(patient: User,
         doctor: User,
         assessmentsShared: Bool,
         interventionsShared: Bool) {
        
        self.patient = patient
        self.doctor = doctor
        self.isAssessmentsTresorShared = assessmentsShared
        self.isInterventionsTresorShared = interventionsShared
        
        super.init()
    }
    
    func synchronouslyShare(assessments share: Bool) throws {
        assert(!Thread.isMainThread, "Deadlocks when called on main thread")
        
        var outError: Error?
        
        let sema = DispatchSemaphore(value: 0)
        
        self.share(assessments: share) { (success, error) in
            outError = error
            sema.signal()
        }
        
        sema.wait()
        
        if let error = outError {
            throw error
        }
    }
    
    func synchronouslyShare(interventions share: Bool) throws {
        assert(!Thread.isMainThread, "Deadlocks when called on main thread")
        
        var outError: Error?
        
        let sema = DispatchSemaphore(value: 0)
        
        self.share(interventions: share) { (success, error) in
            outError = error
            sema.signal()
        }
        
        sema.wait()
        
        if let error = outError {
            throw error
        }
    }
    
    func share(interventions share: Bool, completion: @escaping (Bool, Error?) -> Void) {
        guard let interventionsTresor = patient.interventionsTresor else {
            completion(false, CareKitZeroKitError.notFoundError)
            return
        }
        
        self.share(tresor: interventionsTresor.tresorId, share: share) { success, error in
            CloudKitStore.update(patientDataShare: self, assessmentsShared: nil, interventionsShared: share) { success, error in
                if success {
                    self.isInterventionsTresorShared = share
                }
                completion(success, error)
            }
        }
    }
    
    func share(assessments share: Bool, completion: @escaping (Bool, Error?) -> Void) {
        guard let assessmentsTresor = patient.assessmentsTresor else {
            completion(false, CareKitZeroKitError.notFoundError)
            return
        }
        
        self.share(tresor: assessmentsTresor.tresorId, share: share) { success, error in
            CloudKitStore.update(patientDataShare: self, assessmentsShared: share, interventionsShared: nil) { success, error in
                if success {
                    self.isAssessmentsTresorShared = share
                }
                completion(success, error)
            }
        }
    }
    
    private func share(tresor tresorId: String, share: Bool, completion: @escaping (Bool, Error?) -> Void) {
        if share {
            self.share(tresor: tresorId, completion: completion)
        } else {
            self.kick(fromTresor: tresorId, completion: completion)
        }
    }
    
    private func share(tresor tresorId: String, completion: @escaping (Bool, Error?) -> Void) {
        zeroKit.share(tresorWithId: tresorId, withUser: doctor.userId) { operationId, error in
            guard error == nil else {
                if error! == ZeroKitError.alreadyMember {
                    completion(true, nil)
                } else {
                    completion(false, error)
                }
                return
            }
            
            self.appMock.approveShare(operationId!, approve: true) { success in
                if success {
                    completion(true, nil)
                } else {
                    completion(false, CareKitZeroKitError.adminCallError)
                }
            }
        }
    }
    
    private func kick(fromTresor tresorId: String, completion: @escaping (Bool, Error?) -> Void) {
        zeroKit.kick(userWithId: doctor.userId, fromTresor: tresorId) { operationId, error in
            guard error == nil else {
                if error! == ZeroKitError.notMember {
                    completion(true, nil)
                } else {
                    completion(false, error)
                }
                return
            }
            
            self.appMock.approveKick(operationId!, approve: true) { success in
                if success {
                    completion(true, nil)
                } else {
                    completion(false, CareKitZeroKitError.adminCallError)
                }
            }
        }
    }
    
    // MARK: CKRecord transform
    
    static let recordType = "PatientDataShare"
    
    enum RecordAttr: String {
        case patientUser
        case doctorUser
        case isInterventionsTresorShared
        case isAssessmentsTresorShared
    }
    
    class func recordID(withPatient patient: User, doctor: User) -> CKRecordID {
        return CKRecordID(recordName: "\(PatientDataShare.recordType)_\(patient.userId)_\(doctor.userId)")
    }
    
    var recordID: CKRecordID {
        return PatientDataShare.recordID(withPatient: patient, doctor: doctor)
    }
    
    func toCKRecord(withInterventionsShared interventionsShared: Bool? = nil, assessmentsShared: Bool? = nil) -> CKRecord {
        let record = CKRecord(recordType: PatientDataShare.recordType, recordID: recordID)
        
        record[RecordAttr.patientUser.rawValue] = CKReference(recordID: self.patient.recordID, action: .none)
        record[RecordAttr.doctorUser.rawValue] = CKReference(recordID: self.doctor.recordID, action: .none)
        
        if let interventionsShared = interventionsShared {
            record[RecordAttr.isInterventionsTresorShared.rawValue] = NSNumber(value: interventionsShared) as CKRecordValue
        } else {
            record[RecordAttr.isInterventionsTresorShared.rawValue] = NSNumber(value: isInterventionsTresorShared) as CKRecordValue
        }
        
        if let assessmentsShared = assessmentsShared {
            record[RecordAttr.isAssessmentsTresorShared.rawValue] = NSNumber(value: assessmentsShared) as CKRecordValue
        } else {
            record[RecordAttr.isAssessmentsTresorShared.rawValue] = NSNumber(value: isAssessmentsTresorShared) as CKRecordValue
        }
        
        return record
    }
    
    convenience init(patient: User,
                     doctor: User,
                     record: CKRecord) {
        
        let assessmentsShared = (record[RecordAttr.isAssessmentsTresorShared.rawValue] as! NSNumber).boolValue
        let interventionsShared = (record[RecordAttr.isInterventionsTresorShared.rawValue] as! NSNumber).boolValue
        
        self.init(patient: patient,
                  doctor: doctor,
                  assessmentsShared: assessmentsShared,
                  interventionsShared: interventionsShared)
    }
}
