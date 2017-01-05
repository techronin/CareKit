import Foundation

enum CareKitZeroKitError: Int, Error {
    case encryptionError = 1    // Error occurred during encryption
    case decryptionError        // Error occurred during decryption
    case notFoundError
    case inconsistencyError     // The decrypted data does not match the queried data
    case adminCallError         // An error occurred when performing an administrative call
}
