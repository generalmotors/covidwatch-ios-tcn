//
//  Created by Zsombor Szabo on 08/04/2020.
//

import Foundation

/// A struct that contains the constants defined in the TCN protocol.
public struct TCNConstants {
    
    /// The domain name in reverse dot notation of the TCN coalition.
    public static let domainNameInReverseDotNotationString = "org.tcn-coalition"
    
    /// The string representation of the 16-bit UUID of the BLE service.
    public static let UUIDServiceString = "C019"
    
    //10 minutes before next check of unregistered beacon TCN from backend
    public static let unregisteredBeaconCheckInterval : Double = 10 * 60

// 06-04-20 - EGC - Adding scanning for iBeacons
	public static let UUIDBeaconServiceString = "0000c019-0000-1000-8000-00805f9b34fb"
	static let testBeaconIdentifier = "SafetyBeaconIdentifier"
	public static let tcnBeaconService = UUID(uuidString: TCNConstants.UUIDBeaconServiceString)!

    /// The string representation of the 128-bit UUID of the BLE characteristic exposed by the primary
    /// peripheral service in connection-oriented mode.
    public static let UUIDCharacteristicString = "D61F4F27-3D6B-4B04-9E46-C9D2EA617F62"
    
}
