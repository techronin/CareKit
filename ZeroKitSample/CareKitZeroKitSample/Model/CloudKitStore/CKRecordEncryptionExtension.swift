import CloudKit
import ZeroKit

typealias RecordEncryptionCallback = (CKRecord?, Error?) -> Void
typealias ValueEncryptionCallback = (CKRecordValue?, Error?) -> Void

/**
 `CKRecord` extension to support data encryption and decryption with ZeroKit on a record object.
 */
extension CKRecord {
    
    private var zeroKit: ZeroKit {
        return AppDelegate.current.zeroKit!
    }
    
    // MARK: Encrypt
    
    /**
     Encrypt the data in the record that is stored by keys that are marked to be encrypted.
     
     - parameter tresor: The tresor to use for encryption.
     - parameter keysToEncrypt: Array containing the keys for which data has to be encrypted.
     - parameter completion: Called when encryption finishes or an error occurs.
     */
    func encryptedRecord(inTresor tresor: Tresor, keysToEncrypt: [String], completion: @escaping RecordEncryptionCallback) {
        // Perform encryption on a copy of the record
        let recordCopy = self.copy() as! CKRecord
        encrypt(record: recordCopy, inTresor: tresor, keysToEncrypt: keysToEncrypt, completion: completion)
    }
    
    /**
     This method encrypts entries in the record for each key that is contained in the `keysToEncrypt` array. Encryption happens asynchronously so this method is called recursively after each encryption step.
     */
    private func encrypt(record: CKRecord, inTresor tresor: Tresor, keysToEncrypt: [String], completion: @escaping RecordEncryptionCallback) {
        
        // Find the key for the next value in CKRecord that needs to be encrypted
        let keys = nextKeyForEncryption(forRecord: record, keysForEncryption: keysToEncrypt)
        
        if let key = keys.nextKey, let plainValue = record[key] {
            
            // Encrypt the value for the previously found key
            self.encrypt(plainValue: plainValue, inTresor: tresor) { cipherValue, error in
                guard error == nil else {
                    // An error occurred while encrypting the value. Abort the encryption process.
                    completion(nil, error)
                    return
                }
                
                // Replace the plain value with the encrypted value
                record[key] = cipherValue!
                
                // Continue encrypting the remaining values in the record
                self.encrypt(record: record, inTresor: tresor, keysToEncrypt: keys.remainingKeys, completion: completion)
            }
            
        } else {
            
            // No more data has to be encrypted
            completion(record, nil)
        }
    }
    
    private func encrypt(plainValue: CKRecordValue, inTresor tresor: Tresor, completion: @escaping ValueEncryptionCallback) {
        if let plainText = plainValue as? String {
            zeroKit.encrypt(plainText: plainText, inTresor: tresor.tresorId) { cipherText, error in
                guard error == nil else {
                    completion(nil, error)
                    return
                }
                
                completion(cipherText! as CKRecordValue, nil)
            }
            
        } else if let plainData = plainValue as? Data {
            zeroKit.encrypt(plainData: plainData, inTresor: tresor.tresorId) { cipherData, error in
                guard error == nil else {
                    completion(nil, error)
                    return
                }
                
                completion(cipherData! as CKRecordValue, nil)
            }
            
        } else {
            completion(nil, CareKitZeroKitError.encryptionError)
        }
    }
    
    
    // MARK: Decrypt
    
    /**
     Decrypt the data in the record that is stored by keys that are marked to be decrypted.
     
     - parameter tresor: The tresor to use for decryption.
     - parameter keysToDecrypt: Array containing the keys for which data has to be decrypted.
     - parameter completion: Called when decryption finishes or an error occurs.
     */
    func decryptedRecord(withKeysToDecrypt keysToDecrypt: [String], completion: @escaping RecordEncryptionCallback) {
        // Perform decryption on a copy of the record
        let recordCopy = self.copy() as! CKRecord
        decrypt(record: recordCopy, keysToDecrypt: keysToDecrypt, completion: completion)
    }
    
    /**
     This method decrypts entries in the record for each key that is contained in the `keysToDecrypt` array. Decryption happens asynchronously so this method is called recursively after each decryption step.
     */
    private func decrypt(record: CKRecord, keysToDecrypt: [String], completion: @escaping RecordEncryptionCallback) {
        
        // Find the key for the next value in CKRecord that needs to be decrypted
        let keys = nextKeyForEncryption(forRecord: record, keysForEncryption: keysToDecrypt)
        
        if let key = keys.nextKey, let cipherValue = record[key] {
            
            // Decrypt the value for the previously found key
            self.decrypt(cipherValue: cipherValue) { plainValue, error in
                guard error == nil else {
                    // An error occurred while decrypting the value. Abort the decryption process.
                    completion(nil, error)
                    return
                }
                
                // Replace the encrypted value with the plain value
                record[key] = plainValue!
                
                // Continue decrypting the remaining values in the record
                self.decrypt(record: record, keysToDecrypt: keys.remainingKeys, completion: completion)
            }
            
        } else {
            
            // No more data has to be decrypted
            completion(record, nil)
        }
    }
    
    private func decrypt(cipherValue: CKRecordValue, completion: @escaping ValueEncryptionCallback) {
        if let cipherText = cipherValue as? String {
            zeroKit.decrypt(cipherText: cipherText) { plainText, error in
                guard error == nil else {
                    completion(nil, error)
                    return
                }
                
                completion(plainText! as CKRecordValue, nil)
            }
            
        } else if let cipherData = cipherValue as? Data {
            zeroKit.decrypt(cipherData: cipherData) { plainData, error in
                guard error == nil else {
                    completion(nil, error)
                    return
                }
                
                completion(plainData! as CKRecordValue, nil)
            }
            
        } else {
            completion(nil, CareKitZeroKitError.decryptionError)
        }
    }
    
    
    // MARK: Helpers
    
    private func nextKeyForEncryption(forRecord record: CKRecord, keysForEncryption: [String]) -> (nextKey: String?, remainingKeys: [String]) {
        var nextKey: String? = nil
        var remainingKeys = keysForEncryption
        
        for key in keysForEncryption {
            remainingKeys.removeFirst()
            if record[key] != nil {
                nextKey = key
                break
            }
        }
        
        return (nextKey, remainingKeys)
    }
}
