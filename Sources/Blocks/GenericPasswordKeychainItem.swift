import Foundation

private func throwIfNotSuccess(_ status: OSStatus) throws {
    guard status != errSecSuccess else { return }
    throw KeychainError.keychainError(status: status)
}

public enum KeychainError: Error {
    case invalidData
    case keychainError(status: OSStatus)
}

extension Dictionary {
    func adding(key: Key, value: Value) -> Dictionary {
        var copy = self
        copy[key] = value
        return copy
    }
}

public final class GenericPasswordKeychainItem {
    private let label: String
    private let account: String

    public init(label: String, account: String) {
        self.label = label
        self.account = account
    }

    private var baseDictionary: [String: AnyObject] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account as CFString,
            kSecAttrLabel as String: label as CFString
        ]
    }

    private var query: [String: AnyObject] {
        baseDictionary.adding(key: kSecMatchLimit as String, value: kSecMatchLimitOne)
    }

    public func delete() throws {
        let status = SecItemDelete(baseDictionary as CFDictionary)
        guard status != errSecItemNotFound else { return }
        try throwIfNotSuccess(status)
    }

    public func read() throws -> String? {
        let query = query.adding(key: kSecReturnData as String, value: true as AnyObject)
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { return nil }
        try throwIfNotSuccess(status)
        guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    public func write(_ secret: String) throws {
        let currentValue = try read()
        if currentValue == nil {
            try add(secret)
        } else {
            try update(secret)
        }
    }

    private func update(_ secret: String) throws {
        let dictionary: [String: AnyObject] = [
            kSecValueData as String: secret.data(using: String.Encoding.utf8)! as AnyObject
        ]
        try throwIfNotSuccess(SecItemUpdate(baseDictionary as CFDictionary, dictionary as CFDictionary))
    }

    private func add(_ secret: String) throws {
        let dictionary = baseDictionary.adding(
            key: kSecValueData as String,
            value: secret.data(using: .utf8)! as AnyObject
        )
        try throwIfNotSuccess(SecItemAdd(dictionary as CFDictionary, nil))
    }
}