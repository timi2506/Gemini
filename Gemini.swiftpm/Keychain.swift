import Foundation
import KeychainSwift

@propertyWrapper
class KeychainText {
    private let key: String
    private let keychain = KeychainSwift()
    private var defaultValue: String
    
    init(_ key: String, defaultValue: String = "") {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    var wrappedValue: String {
        get {
            keychain.get(key) ?? defaultValue
        }
        set {
            keychain.set(newValue, forKey: key)
        }
    }
}
