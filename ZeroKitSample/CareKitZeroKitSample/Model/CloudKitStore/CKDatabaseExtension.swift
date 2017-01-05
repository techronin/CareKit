import CloudKit

extension CKDatabase {
    func synchronouslyPerform(query: CKQuery, inZoneWith zoneID: CKRecordZoneID?) throws -> [CKRecord] {
        
        var records: [CKRecord]?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        self.perform(query, inZoneWith: zoneID) {
            records = $0
            error = $1
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = error {
            throw error
        }
        
        return records ?? []
    }
    
    func synchronouslyFetch(withRecordID recordID: CKRecordID) throws -> CKRecord? {
        
        var record: CKRecord?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        self.fetch(withRecordID: recordID) {
            record = $0
            error = $1
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = error {
            throw error
        }
        
        return record
    }
    
    func synchronously(saveRecords: [CKRecord]?, deleteRecords: [CKRecordID]?, savePolicy: CKRecordSavePolicy? = nil) throws -> (saveRecords: [CKRecord]?, deleteRecords: [CKRecordID]?) {
        
        var savedRecords: [CKRecord]?
        var deletedRecords: [CKRecordID]?
        var error: NSError?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let operation = CKModifyRecordsOperation(recordsToSave: saveRecords, recordIDsToDelete: deleteRecords)
        
        if let savePolicy = savePolicy {
            operation.savePolicy = savePolicy
        }
        
        operation.modifyRecordsCompletionBlock = {
            savedRecords = $0
            deletedRecords = $1
            error = $2 as NSError?
            semaphore.signal()
        }
        
        self.add(operation)
        
        semaphore.wait()
        
        if let error = error {
            throw error
        }
        
        return (savedRecords, deletedRecords)
    }
}
