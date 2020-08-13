/*******************************************************************************
 * EBMBLEManager.swift
 *
 * Author:			Eric Crichlow
*/

import Foundation
import CoreBluetooth
import CoreLocation

protocol BLEManagerDelegate : class
{
	func BLEBluetoothManagerLogMessage(message: String)
	func BLEBluetoothManagerError(error: Error)
	func BLEBluetoothManagerDiscoveredDevicesUpdated(devices: [CLBeacon: NSNumber])
	func BLEBluetoothManagerDeterminedClosestBeacon(beacon: CLBeacon)
}

class BLEManager : NSObject, CLLocationManagerDelegate, CBCentralManagerDelegate
{
	static let sharedManager = BLEManager()

	var delegateList = NSPointerArray.weakObjects()
	var locationManager : CLLocationManager!
	var deviceList = [CLBeacon: NSNumber]()
	var deviceRSSIValues = [CLBeacon: [NSNumber]]()
    var beaconRegion : CLBeaconRegion?
	var waitingToScan = false
	var availableToStartScanning = false
	var serviceUUID : CBUUID!
	var deviceSearchTimer : Timer?
	var centralManager : CBCentralManager!
	var discoveredBeacons = [CLBeacon: [Int]]()

	override init()
	{

		super.init()
		locationManager = CLLocationManager()
		locationManager.delegate = self
		locationManager.requestAlwaysAuthorization()
		serviceUUID = CBUUID(string: TCNConstants.BeaconUUIDString)
		centralManager = CBCentralManager.init(delegate: self, queue: nil, options: nil)
		LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager initialized"))
	}

	// MARK: Business logic

	func registerDelegate(delegate: BLEManagerDelegate)
	{   deviceSearchTimer = nil
		for nextDelegate in delegateList.allObjects
		{
			let del = nextDelegate as! BLEManagerDelegate
			if del === delegate
			{
				return
			}
		}
		let pointer = Unmanaged.passUnretained(delegate as AnyObject).toOpaque()
		LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager delegate registered"))
		delegateList.addPointer(pointer)
	}

	func unregisterDelegate(delegate: BLEManagerDelegate)
	{
		var index = 0
		for nextDelegate in delegateList.allObjects
		{
			let del = nextDelegate as! BLEManagerDelegate
			if del === delegate
			{
				break
			}
			index += 1
		}
		if index < delegateList.count
		{
			delegateList.removePointer(at: index)
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager delegate unregistered"))
		}
	}

	public func startBeaconScanning()
	{
		if let serviceuuid = serviceUUID, let uuid = UUID(uuidString: serviceuuid.uuidString)
		{
			beaconRegion = CLBeaconRegion(uuid: uuid, identifier: "")
            let beaconConstraint = CLBeaconIdentityConstraint(uuid: uuid)
            if let region = beaconRegion {
                locationManager.startMonitoring(for: region)
                locationManager.startRangingBeacons(satisfying: beaconConstraint)
            }
		}
	}

	// MARK: Delegate callbacks

	func transmitLogMessage(_ message: String)
	{
		delegateList.compact()
		for nextDelegate in delegateList.allObjects
		{
			let delegate = nextDelegate as! BLEManagerDelegate
			delegate.BLEBluetoothManagerLogMessage(message: message)
		}
	}

	func transmitError(_ error: Error)
	{
		delegateList.compact()
		for nextDelegate in delegateList.allObjects
		{
			let delegate = nextDelegate as! BLEManagerDelegate
			delegate.BLEBluetoothManagerError(error: error)
		}
	}

	func transmitDiscoveredDevicesUpdated(_ devices: [CLBeacon: NSNumber])
	{
		delegateList.compact()
		for nextDelegate in delegateList.allObjects
		{
			let delegate = nextDelegate as! BLEManagerDelegate
			delegate.BLEBluetoothManagerDiscoveredDevicesUpdated(devices: devices)
		}
	}

	func transmitDeterminedClosestBeacon( _ beacon: CLBeacon)
	{
		delegateList.compact()
		for nextDelegate in delegateList.allObjects
		{
			let delegate = nextDelegate as! BLEManagerDelegate
			delegate.BLEBluetoothManagerDeterminedClosestBeacon(beacon: beacon)
		}
	}

	// MARK: CLLocationManager Delegate methods

	func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
	{
		if status == .authorizedAlways
		{
			if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self)
			{
				if CLLocationManager.isRangingAvailable()
				{
					startBeaconScanning()
				}
			}
		}
	}

	func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion)
	{
        if deviceSearchTimer == nil
        {
            deviceSearchTimer = Timer.scheduledTimer(withTimeInterval: AppConfigurationManager.beaconScanPeriod, repeats: false)
            {
                timer in
                   for beacon in beacons
                    {
                        switch beacon.proximity {
                        case .immediate:
                            self.centralManager.stopScan()
                            self.locationManager.stopUpdatingLocation()
                            self.locationManager.stopMonitoring(for: self.beaconRegion!)
                            self.transmitDeterminedClosestBeacon(beacon)
                            break
                        @unknown default:
                            self.transmitError(TCNError.NotFound)
                        }
                    }
                self.transmitError(TCNError.NotFound)
                }
           
        }     
    }

	// MARK: CBCentralManager Delegate methods
	
	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber)
	{
	}

	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
	{
        if let name = peripheral.name {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager did connect to peripheral: \(name)"))
        }
	}

	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
	{
        if let name = peripheral.name {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager disconnected from peripheral: \(name)"))
        }
	}

	func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?)
	{
        if let failure = error, let name = peripheral.name
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager failed to connect to peripheral: \(name)"))
			transmitError(failure)
		}
	}

	func centralManagerDidUpdateState(_ central: CBCentralManager)
	{
		if central.state == .poweredOn
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBCentralManager powered on"))
		}
		else if central.state == .poweredOff
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBCentralManager powered off"))
		}
	}

	func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any])
	{
		LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBCentralManager will restore state"))
	}
}
