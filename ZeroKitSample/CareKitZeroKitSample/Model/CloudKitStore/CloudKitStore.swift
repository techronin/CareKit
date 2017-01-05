import CloudKit
import ZeroKit

/**
 Handles fetching and saving data in the cloud that is not encrypted by the user.
 */
class CloudKitStore: NSObject {
    
    private static let queue = DispatchQueue(label: "com.tresorit.CloudKitStore")
    private static let publicDB = CKContainer.default().publicCloudDatabase
    
    // MARK: Users
    
    class func save(user: User, completion: @escaping (Bool, Error?) -> Void) {
        update(interventionsTresorId: nil, assessmentsTresorId: nil, forUser: user, completion: completion)
    }
    
    class func update(interventionsTresorId: String?, assessmentsTresorId: String?, forUser user: User, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global().async {
            var outError: Error? = nil
            
            do {
                let record = user.toCKRecord(withNewInterventionsTresorId: interventionsTresorId,
                                             newAssessmentsTresorId: assessmentsTresorId)
                
                _ = try self.publicDB.synchronously(saveRecords: [record], deleteRecords: nil, savePolicy: .allKeys)
            } catch {
                outError = error
            }
            
            self.queue.async {
                completion(outError == nil, outError)
            }
        }
    }
    
    class func fetch(userForUsername username: String, completion: @escaping (Bool, User?, Error?) -> Void) {
        DispatchQueue.global().async {
            var outError: Error?
            var user: User?
            
            do {
                let recordId = CKRecordID(recordName: username)
                if let record = try self.publicDB.synchronouslyFetch(withRecordID: recordId) {
                    user = User(record: record)
                }
            } catch {
                outError = error
            }
            
            self.queue.async {
                completion(outError == nil, user, outError)
            }
        }
    }
    
    
    // MARK: Share
    
    class func save(patientDataShare: PatientDataShare, completion: @escaping (Bool, Error?) -> Void) {
        self.update(patientDataShare: patientDataShare, assessmentsShared: nil, interventionsShared: nil, completion: completion)
    }
    
    class func update(patientDataShare: PatientDataShare, assessmentsShared: Bool?, interventionsShared: Bool?, completion: @escaping (Bool, Error?) -> Void) {
        let record = patientDataShare.toCKRecord(withInterventionsShared: interventionsShared, assessmentsShared: assessmentsShared)
        let opertation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        opertation.savePolicy = .allKeys
        
        opertation.modifyRecordsCompletionBlock = { _, _, error in
            self.queue.async {
                completion(error == nil, error)
            }
        }
        
        self.publicDB.add(opertation)
    }
    
    class func remove(patientDataShare: PatientDataShare, completion: @escaping (Bool, Error?) -> Void) {
        self.publicDB.delete(withRecordID: patientDataShare.recordID) { recordID, error in
            completion(error == nil, error)
        }
    }
    
    class func fetch(dataShareForPatient patient: User, doctor: User, zeroKit: ZeroKit, appMock: ExampleAppMock, completion: @escaping (Bool, PatientDataShare?, Error?) -> Void) {
        self.publicDB.fetch(withRecordID: PatientDataShare.recordID(withPatient: patient, doctor: doctor)) { record, error in
            var share: PatientDataShare?
            if let record = record {
                share = PatientDataShare(patient: patient, doctor: doctor, record: record)
            }
            
            var outError = error
            
            if let ckError = error as? CKError,
                ckError.code == .unknownItem {
                // No share exists
                outError = nil
            }
            
            self.queue.async {
                completion(outError == nil, share, outError)
            }
        }
    }
    
    class func fetch(dataSharesForPatient patient: User, completion: @escaping (Bool, [PatientDataShare]?, Error?) -> Void) {
        DispatchQueue.global().async {
            var outError: Error?
            var outShares: [PatientDataShare]?
            
            do {
                let patientRef = CKReference(recordID: patient.recordID, action: .none)
                let predicate = NSPredicate(format: "%K = %@", PatientDataShare.RecordAttr.patientUser.rawValue, patientRef)
                let query = CKQuery(recordType: PatientDataShare.recordType, predicate: predicate)
                
                let records = try self.publicDB.synchronouslyPerform(query: query, inZoneWith: nil)
                
                outShares = try records.map { (rec) -> PatientDataShare in
                    let doctorRef = rec[PatientDataShare.RecordAttr.doctorUser.rawValue] as! CKReference
                    let doctorRecord = try self.publicDB.synchronouslyFetch(withRecordID: doctorRef.recordID)!
                    let doctor = User(record: doctorRecord)
                    return PatientDataShare(patient: patient, doctor: doctor, record: rec)
                }
                
            } catch {
                outError = error
            }
            
            self.queue.async {
                completion(outError == nil, outShares, outError)
            }
        }
    }
    
    class func fetch(patientDataSharesForDoctor doctor: User, completion: @escaping (Bool, [PatientDataShare]?, Error?) -> Void) {
        DispatchQueue.global().async {
            var outError: Error?
            var outShares: [PatientDataShare]?
            
            do {
                let doctorRef = CKReference(recordID: doctor.recordID, action: .none)
                let predicate = NSPredicate(format: "%K = %@", PatientDataShare.RecordAttr.doctorUser.rawValue, doctorRef)
                let query = CKQuery(recordType: PatientDataShare.recordType, predicate: predicate)
                
                let records = try self.publicDB.synchronouslyPerform(query: query, inZoneWith: nil)
                
                outShares = try records.map { (rec) -> PatientDataShare in
                    let patientRef = rec[PatientDataShare.RecordAttr.patientUser.rawValue] as! CKReference
                    let patientRecord = try self.publicDB.synchronouslyFetch(withRecordID: patientRef.recordID)!
                    let patient = User(record: patientRecord)
                    return PatientDataShare(patient: patient, doctor: doctor, record: rec)
                }
                
            } catch {
                outError = error
            }
            
            self.queue.async {
                completion(outError == nil, outShares, outError)
            }
        }
    }
    
    class func createDatabaseSchema() throws {
        /* 
         This will add record types to CloudKit if they do not yet exist.
         This only works in the development CloudKit environment and helps setting up the sample app.
         */
        
        let patient = User(userId: "dummyPatient@tresorit.io", username: "DummyPatientUser", type: .patient, interventionsTresorId: "DummyInterventions", assessmentsTresorId: "DummyAssessments")
        let doctor = User(userId: "dummyDoctor@tresorit.io", username: "DummyDoctorUser", type: .doctor, interventionsTresorId: nil, assessmentsTresorId: nil)
        let share = PatientDataShare(patient: patient, doctor: doctor, assessmentsShared: true, interventionsShared: true)
        
        let activityRecord = CloudCarePlanActivity.dummyRecord
        let eventRecord = CloudCarePlanEvent.dummyRecord
        
        let records = [patient.toCKRecord(), doctor.toCKRecord(), share.toCKRecord(), activityRecord, eventRecord]
        let recordIds = records.map { return $0.recordID }
        
        _ = try publicDB.synchronously(saveRecords: records, deleteRecords: nil)
        _ = try publicDB.synchronously(saveRecords: nil, deleteRecords: recordIds)
    }
    
    class func checkAccountStatus(completion: @escaping (Bool) -> Void) {
        CKContainer.default().accountStatus { accountStatus, error in
            if let error = error {
                print("Error checking account status: \(error)")
            }
            
            switch accountStatus {
            case .available:
                completion(true)
                
            case .couldNotDetermine: fallthrough
            case .noAccount: fallthrough
            case .restricted:
                completion(false)
            }
        }
    }
}
