//
//  Created by Zsombor Szabo on 08/04/2020.
//

import Foundation

/// A type that can convert itself into and out of a little endian byte buffer.
public protocol DataRepresentable {
    
    /// Initialize an instance from a little endian byte buffer.
    ///
    /// - Parameter dataRepresentation: A little endian byte buffer.
    init<D>(dataRepresentation: D) throws where D: ContiguousBytes
    
    /// Returns a little endian byte buffer.
    var tcnDataRepresentation: Data { get }
}

extension DataRepresentable {
    
    public init<D>(dataRepresentation: D) throws where D: ContiguousBytes {
        self = try dataRepresentation.withUnsafeBytes {
            guard $0.count == MemoryLayout<Self>.size,
                let baseAddress = $0.baseAddress else {
                    throw CocoaError(.coderInvalidValue)
            }
            return baseAddress.bindMemory(to: Self.self, capacity: 1).pointee
        }
    }
    
    public var tcnDataRepresentation: Data {
        var value = self
        return withUnsafePointer(to: &value) {
            return Data(buffer: UnsafeBufferPointer(start: $0, count: 1))
        }
    }
}
