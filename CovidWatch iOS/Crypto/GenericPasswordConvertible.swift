//
// Copyright © 2019 Apple Inc., IZE Ltd. and the project authors
// Licensed under MIT License
//
// See LICENSE.txt for license information.
//

import Foundation
import CryptoKit

/// The interface needed for SecKey conversion.
public protocol GenericPasswordConvertible: CustomStringConvertible {
    /// Creates a key from a raw representation.
    init<D>(rawRepresentation data: D) throws where D: ContiguousBytes
    
    /// Creates a new key.
    init() throws
    
    /// A raw representation of the key.
    var rawRepresentation: Data { get }
}

extension GenericPasswordConvertible {
    /// A string version of the key for visual inspection.
    /// IMPORTANT: Never log the actual key data.
    public var description: String {
        return self.rawRepresentation.withUnsafeBytes { bytes in
            return "Key representation contains \(bytes.count) bytes."
        }
    }
}

// Declare that the Curve25519 keys are generic passord convertible.
extension Curve25519.KeyAgreement.PrivateKey: GenericPasswordConvertible {}
extension Curve25519.Signing.PrivateKey: GenericPasswordConvertible {}

// Ensure that Secure Enclave keys are generic password convertible.
extension SecureEnclave.P256.KeyAgreement.PrivateKey:
GenericPasswordConvertible {
    public init<D>(rawRepresentation data: D) throws where D: ContiguousBytes {
        try self.init(dataRepresentation: data.dataRepresentation)
    }
        
    public init() throws {
        // swiftlint:disable force_unwrapping
        try self.init(
            compactRepresentable: true,
            accessControl: SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                [.privateKeyUsage],
                nil
                )!,
            authenticationContext: nil
        )
    }
    
    public var rawRepresentation: Data {
        // Contiguous bytes repackaged as a Data instance.
        return dataRepresentation
    }
}

extension SecureEnclave.P256.Signing.PrivateKey: GenericPasswordConvertible {
    public init<D>(rawRepresentation data: D) throws where D: ContiguousBytes {
        try self.init(dataRepresentation: data.dataRepresentation)
    }
    
    public init() throws {
        try self.init(
            compactRepresentable: true,
            accessControl: SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                [.privateKeyUsage],
                nil
                )!,
            authenticationContext: nil
        )
    }
    
    public var rawRepresentation: Data {
        return dataRepresentation // Contiguous bytes repackaged as a Data instance.
    }
}

extension ContiguousBytes {
    /// A Data instance created safely from the contiguous bytes without making any copies.
    var dataRepresentation: Data {
        return self.withUnsafeBytes { bytes in
            let cfdata = CFDataCreateWithBytesNoCopy(
                nil,
                bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                bytes.count,
                kCFAllocatorNull
            )
            return ((cfdata as NSData?) as Data?) ?? Data()
        }
    }
}
