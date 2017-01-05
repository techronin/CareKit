import CloudKit

/**
 Protocol for classes that can be converted to CKRecord
 */
protocol CloudRecordConvertible {
    var recordID: CKRecordID { get }
    func record(completion: @escaping (CKRecord?, Error?) -> Void)
}
