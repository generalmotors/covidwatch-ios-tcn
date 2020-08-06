/*******************************************************************************
 * EBMBLEManager.swift
 *
* Title:			Contact Tracing
* Description:		Contact Tracing Monitoring and Reporting App
*						This file contains the manager for BLE connectivity
 * Author:			Eric Crichlow
 * Version:			1.0
 *	05/20/20		*	EGC	*	File creation date
 *	06/10/20		*	EGC	*	Retooled to only support identifying and programming iBeacons
 *******************************************************************************/

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

class BLEManager : NSObject, CLLocationManagerDelegate, CBCentralManagerDelegate //, CBPeripheralManagerDelegate, CBPeripheralDelegate
{

	static let sharedManager = BLEManager()

	var delegateList = NSPointerArray.weakObjects()
	var locationManager : CLLocationManager!
// 6-10-20 - EGC - No longer broadcasting beacon, just using BLEManager to register iBeacons
//	var centralManager : CBCentralManager!
//	var peripheralManager: CBPeripheralManager!
//	var peripheralService : CBMutableService!
	var deviceList = [CLBeacon: NSNumber]()
	var deviceRSSIValues = [CLBeacon: [NSNumber]]()
//	var currentPeripheral : CBPeripheral?
//	var RXSerivce : CBService?
//	var RXCharacteristic : CBCharacteristic?
//	var TXCharacteristic : CBCharacteristic?
//	var RXDescriptor : CBDescriptor?
	var waitingToScan = false
	var availableToStartScanning = false
	var serviceUUID : CBUUID!
	var deviceSearchTimer : Timer?
	var centralManager : CBCentralManager!
	var discoveredBeacons = [CLBeacon: [Int]]()

	override init()
	{

		super.init()

// 6-10-20 - EGC - No longer broadcasting beacon, just using BLEManager to register iBeacons
//		centralManager = CBCentralManager.init(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "GMSafetyTestManager"])
//		peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
		locationManager = CLLocationManager()
		locationManager.delegate = self
		locationManager.requestAlwaysAuthorization()
		serviceUUID = CBUUID(string: AppConfigurationManager.testBeaconUUIDString)
		centralManager = CBCentralManager.init(delegate: self, queue: nil, options: nil)
//		peripheralService = CBMutableService(type: serviceUUID, primary: true)
//		let characteristic = CBMutableCharacteristic.init(type: CBUUID(string: AppConfigurationManager.testCharacteristicUUIDString), properties: [.read, .write, .notify], value: nil, permissions: [CBAttributePermissions.readable, CBAttributePermissions.writeable])
//		peripheralService.characteristics = []
//		peripheralService.characteristics?.append(characteristic)
//		peripheralManager.add(peripheralService)
		LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager initialized"))
	}

	// MARK: Business logic

	func registerDelegate(delegate: BLEManagerDelegate)
	{
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

// 6-10-20 - EGC - No longer broadcasting beacon, just using BLEManager to register iBeacons
/*
	func startInteractions()
	{
		LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager starting interactions"))
		startBroadcast()
//		startBeacon()
		startScan()
	}

	func startScan()
	{
		if centralManager.state != CBManagerState.poweredOff
		{
			if availableToStartScanning
			{
				deviceList.removeAll()
				deviceRSSIValues.removeAll()
				LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager starting scanning"))
//				centralManager.scanForPeripherals(withServices: [CBUUID.init(string: AppConfigurationManager.testServiceUUIDString), CBUUID.init(string: AppConfigurationManager.testBeaconUUIDString)], options: nil)
				centralManager.scanForPeripherals(withServices: nil, options: nil)
			}
			else
			{
				waitingToScan = true
			}
		}
	}

	func stopScan()
	{
		if centralManager.state != CBManagerState.poweredOff
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager stopping scanning"))
			centralManager.stopScan()
		}
	}

	func startBroadcast()
	{
		LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager starting broadcasting"))
		peripheralService = CBMutableService(type: serviceUUID, primary: true)
		peripheralManager.startAdvertising([CBAdvertisementDataLocalNameKey: "SafetyAdvertisement", CBAdvertisementDataServiceUUIDsKey : [serviceUUID]])
	}

	func startBeacon()
	{
		if let uuid = UUID(uuidString: AppConfigurationManager.testBeaconUUIDString)
		{
			let region = CLBeaconRegion(proximityUUID: uuid, identifier: AppConfigurationManager.testBeaconIdentifier)
			let peripheralData = region.peripheralData(withMeasuredPower: nil)
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager starting advertising iBeacon"))
			peripheralManager.startAdvertising(((peripheralData as NSDictionary) as! [String : Any]))
		}
	}

	func connectDevice(peripheral: CBPeripheral)
	{
		if centralManager.state != CBManagerState.poweredOff
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager connecting device"))
			centralManager.connect(peripheral, options: nil)
			currentPeripheral = peripheral
		}
	}

	func disconnectDevice()
	{
		if let connectedPeripheral = currentPeripheral
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "BLEManager disconnecting from device"))
			centralManager.cancelPeripheralConnection(connectedPeripheral)
		}
	}
*/

	public func startBeaconScanning()
	{
		if let serviceuuid = serviceUUID, let uuid = UUID(uuidString: serviceuuid.uuidString)
		{
			let beaconRegion = CLBeaconRegion(uuid: uuid, identifier: "")
            let beaconConstraint = CLBeaconIdentityConstraint(uuid: uuid)
			locationManager.startMonitoring(for: beaconRegion)
            locationManager.startRangingBeacons(satisfying: beaconConstraint)
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
				var closestBeacon : CLBeacon?
				var closestRSSI = -1000
				self.centralManager.stopScan()
				for nextBeacon in self.discoveredBeacons.keys
				{
					var averageRSSI = -1000
					if let rssiArray = self.discoveredBeacons[nextBeacon]
					{
						averageRSSI = 0
						for nextRSSI in rssiArray
						{
							averageRSSI += nextRSSI
						}
						averageRSSI = averageRSSI / rssiArray.count
					}
					if averageRSSI > closestRSSI
					{
						closestRSSI = averageRSSI
						closestBeacon = nextBeacon
					}
				}
				if let closest = closestBeacon
				{
					self.transmitDeterminedClosestBeacon(closest)
				}
			}
		}
		for nextBeacon in beacons
		{
			if discoveredBeacons.keys.contains(nextBeacon) == false
			{
				discoveredBeacons[nextBeacon] = [nextBeacon.rssi]
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

/*

	// MARK: CBPeripheralManager Delegate methods

	func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager)
	{
		if peripheral.state == .poweredOn
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBPeripheralManager powered on"))
        }
	}

	func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?)
	{
		if let error = error
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBPeripheralManager failed to start broadcasting with error: \(error.localizedDescription)"))
		}
		else
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBPeripheralManager started broadcasting"))
		}
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any])
	{
		LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBPeripheralManager will restore state"))
	}

	// MARK: CBPeripheral Delegate methods

	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
	{
		if let error = error
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBPeripheralManager failed to discover services with error: \(error.localizedDescription)"))
		}
		else
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBPeripheralManager discovered services"))
		}
		if let discoveredServices = peripheral.services
		{
			for nextService in discoveredServices
			{
				if nextService.uuid.uuidString == AppConfigurationManager.testServiceUUIDString || nextService.uuid.uuidString == AppConfigurationManager.testServiceAbbreviatedUUIDString
				{
					RXSerivce = nextService
					peripheral.discoverCharacteristics([CBUUID.init(string: AppConfigurationManager.testCharacteristicUUIDString), CBUUID.init(string: AppConfigurationManager.testCharacteristicUUIDString)], for: nextService)
					break
				}
			}
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
	{
		if let error = error
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBPeripheralManager failed to discover characteristics with error: \(error.localizedDescription)"))
		}
		else
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBPeripheralManager discovered characteristics"))
		}
		if let characteristics = service.characteristics
		{
			for nextCharactetistic in characteristics
			{
				if nextCharactetistic.uuid.uuidString == AppConfigurationManager.testCharacteristicUUIDString || nextCharactetistic.uuid.uuidString == AppConfigurationManager.testCharacteristicAbbreviatedUUIDString
				{
					RXCharacteristic = nextCharactetistic
					peripheral.discoverDescriptors(for: nextCharactetistic)
					peripheral.setNotifyValue(true, for: nextCharactetistic)
				}
			}
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?)
	{
		if characteristic == RXCharacteristic
		{
			if let descriptors = characteristic.descriptors
			{
				for nextDescriptor in descriptors
				{
				}
			}
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
	{
		guard let rxChar = RXCharacteristic
			else
				{
				return
				}
		if characteristic.uuid.uuidString == rxChar.uuid.uuidString
		{
			if let packet = characteristic.value
			{
			}
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?)
	{
	
	}

	func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?)
	{
		if let error = error
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBPeripheralManager failed to read RSSI with error: \(error.localizedDescription)"))
		}
		else
		{
			LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "CBPeripheralManager read RSSI"))
		}
	}
*/

}
