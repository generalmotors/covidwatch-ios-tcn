//
//  KeychainManager.swift
//  CovidWatch
//
//  Created by Christopher McGraw on 6/2/20.
//

import Security

// TODO: Ideally we would have error handling for this class
class KeychainManager {

    @discardableResult class func set(value: String, key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        _ = SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    class func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8) else {
                return nil
        }
        return value
    }

}

extension String {

    static let phoneNumberKey = "phoneNumber"

}
