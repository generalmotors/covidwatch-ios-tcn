
//
//  Created by Zsombor Szabo on 11/03/2020.
//

import Foundation
import CoreBluetooth
import CoreLocation
#if canImport(UIKit) && !os(watchOS)
import UIKit.UIApplication
#endif

extension TimeInterval {
    
    /// The time interval after which the peripheral connecting operation will time out and canceled.
    public static let peripheralConnectingTimeout: TimeInterval = 8
    
}

extension CBCentralManager {
    
    #if os(watchOS) || os(tvOS)
    public static let maxNumberOfConcurrentPeripheralConnections = 2
    #else
    /// The maximum number of concurrent peripheral connections we allow the central manager to have,
    /// based on platform (and other) limitations.
    public static let maxNumberOfConcurrentPeripheralConnections = 5
    #endif
    
}

/// A Bluetooth service that implements the TCN protocol.
class TCNBluetoothServiceImpl: NSObject, CLLocationManagerDelegate
{
    
    weak var service: TCNBluetoothService?
    
    private var dispatchQueue: DispatchQueue = DispatchQueue(
        label: TCNConstants.domainNameInReverseDotNotationString
    )
    
    private var centralManager: CBCentralManager?

// 06-04-20 - EGC - Adding scanning for iBeacons
    private var locationManager : CLLocationManager!
    private var discoveredBeacons = Set<CLBeacon>()

    private var restoredPeripherals: [CBPeripheral]?
    
    private var discoveredPeripherals = Set<CBPeripheral>()
    
    private var connectingTimeoutTimersForPeripheralIdentifiers =
        [UUID : Timer]()
    
    private var connectingPeripheralIdentifiers = Set<UUID>() {
        didSet {
            self.configureBackgroundTaskIfNeeded()
        }
    }
    
    private var connectedPeripheralIdentifiers = Set<UUID>() {
        didSet {
            self.configureBackgroundTaskIfNeeded()
        }
    }
    
    private var shortTemporaryIdentifiersOfPeripheralsToWhichWeDidWriteTCNTo = Set<Data>()
    
    private var connectingConnectedPeripheralIdentifiers: Set<UUID> {
        self.connectingPeripheralIdentifiers.union(
            self.connectedPeripheralIdentifiers
        )
    }
    private var unregisteredBeacons = [String : Date]()
    
    private var foundBeacons = [String : Data]()
    
    private var discoveringServicesPeripheralIdentifiers = Set<UUID>()
    
    private var characteristicsBeingRead = Set<CBCharacteristic>()
    
    private var characteristicsBeingWritten = Set<CBCharacteristic>()
    
    private var peripheralManager: CBPeripheralManager?
    
    private var tcnsForRemoteDeviceIdentifiers = [UUID : Data]()
    
    private var estimatedDistancesForRemoteDeviceIdentifiers = [UUID : Double]()
    private var contactDeviceIdForRemoteDeviceIdentifiers = [UUID : UInt32]()

    private var peripheralsToReadTCNFrom = Set<CBPeripheral>()
    
    private var peripheralsToWriteTCNTo = Set<CBPeripheral>()
    
    private var peripheralsToConnect: Set<CBPeripheral> {
        return Set(peripheralsToReadTCNFrom).union(Set(peripheralsToWriteTCNTo))
    }
    
    private func configureBackgroundTaskIfNeeded() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst) && !os(watchOS)
        if self.connectingPeripheralIdentifiers.isEmpty &&
            self.connectedPeripheralIdentifiers.isEmpty {
            self.endBackgroundTaskIfNeeded()
        }
        else {
            self.beginBackgroundTaskIfNeeded()
        }
        #endif
    }
    
    // macCatalyst apps do not need background tasks.
    // watchOS apps do not have background tasks.
    #if canImport(UIKit) && !targetEnvironment(macCatalyst) && !os(watchOS)
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    
    private func beginBackgroundTaskIfNeeded() {
        guard self.backgroundTaskIdentifier == nil else { return }
        self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Did expire background task=\(self.backgroundTaskIdentifier?.rawValue ?? 0)"))
            self.endBackgroundTaskIfNeeded()
        }
        if let task = self.backgroundTaskIdentifier {
            if task == .invalid {
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, level: .error, message: "Begin background task failed"))
            }
            else {
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Begin background task=\(task.rawValue)"))
            }
        }
    }
    
    private func endBackgroundTaskIfNeeded() {
        if let identifier = self.backgroundTaskIdentifier {
            UIApplication.shared.endBackgroundTask(identifier)
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "End background task=\(self.backgroundTaskIdentifier?.rawValue ?? UIBackgroundTaskIdentifier.invalid.rawValue)"))
            self.backgroundTaskIdentifier = nil
        }
    }
    #endif
    
    override init() {
        super.init()
        // macCatalyst apps do not need background support.
        // watchOS apps do not have background support.
        #if canImport(UIKit) && !targetEnvironment(macCatalyst) && !os(watchOS)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillEnterForegroundNotification(_:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif

// 06-04-20 - EGC - Adding scanning for iBeacons
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
    }
    
    deinit {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst) && !os(watchOS)
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }
    
    // MARK: - Notifications
    
    @objc func applicationWillEnterForegroundNotification(
        _ notification: Notification
    ) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Application will enter foreground"))
        self.dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            // Bug workaround: If the user toggles Bluetooth while the app was
            // in the background, then scanning fails when the app becomes
            // active. Restart Bluetooth scanning to work around this issue.
            if self.centralManager?.isScanning ?? false {
                self.centralManager?.stopScan()
                self._startScan()
                self._startBeaconScan()
            }
        }
    }
    
    // MARK: -
    
    /// Returns true if the service is started.
    var isStarted: Bool {
        return self.centralManager != nil
    }
    
    /// Starts the service.
    func start() {
        self.dispatchQueue.async {
            guard self.centralManager == nil else {
                return
            }
            self.centralManager = CBCentralManager(
                delegate: self,
                queue: self.dispatchQueue,
                options: [
                    CBCentralManagerOptionRestoreIdentifierKey:
                        TCNConstants.domainNameInReverseDotNotationString,
                    // Warn user if Bluetooth is turned off.
                    CBCentralManagerOptionShowPowerAlertKey :
                        NSNumber(booleanLiteral: true),
                ]
            )
            self.peripheralManager = CBPeripheralManager(
                delegate: self,
                queue: self.dispatchQueue,
                options: [
                    CBPeripheralManagerOptionRestoreIdentifierKey:
                        TCNConstants.domainNameInReverseDotNotationString
                ]
            )
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Service started"))
        }
    }
    
    /// Stops the service.
    func stop() {
        self.dispatchQueue.async {
            self.stopCentralManager()
            self.centralManager?.delegate = nil
            self.centralManager = nil
            self.stopPeripheralManager()
            self.peripheralManager?.delegate = nil
            self.peripheralManager = nil
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Service stopped"))
// 06-04-20 - EGC - Adding scanning for iBeacons
            self.discoveredBeacons.removeAll()
        }
    }
    
    private func stopCentralManager() {
        self.connectingTimeoutTimersForPeripheralIdentifiers.values.forEach {
            $0.invalidate()
        }
        self.connectingTimeoutTimersForPeripheralIdentifiers.removeAll()
        self.discoveredPeripherals.forEach { self.flushPeripheral($0) }
        self.discoveredPeripherals.removeAll()
        self.connectingPeripheralIdentifiers.removeAll()
        self.connectedPeripheralIdentifiers.removeAll()
        self.discoveringServicesPeripheralIdentifiers.removeAll()
        self.characteristicsBeingRead.removeAll()
        self.characteristicsBeingWritten.removeAll()
        self.peripheralsToReadTCNFrom.removeAll()
        self.unregisteredBeacons.removeAll()
        self.peripheralsToWriteTCNTo.removeAll()
        self.shortTemporaryIdentifiersOfPeripheralsToWhichWeDidWriteTCNTo.removeAll()
        self.tcnsForRemoteDeviceIdentifiers.removeAll()
        self.estimatedDistancesForRemoteDeviceIdentifiers.removeAll()
        self.contactDeviceIdForRemoteDeviceIdentifiers.removeAll()
        if self.centralManager?.isScanning ?? false {
            self.centralManager?.stopScan()
        }
    }
    
    private func stopPeripheralManager() {
        if self.peripheralManager?.isAdvertising ?? false {
            self.peripheralManager?.stopAdvertising()
        }
        if self.peripheralManager?.state == .poweredOn {
            self.peripheralManager?.removeAllServices()
        }
    }
    
    private func connectPeripheralsIfNeeded() {
        guard self.peripheralsToConnect.count > 0 else {
            return
        }
        guard self.connectingConnectedPeripheralIdentifiers.count <
            CBCentralManager.maxNumberOfConcurrentPeripheralConnections else {
                return
        }
        let disconnectedPeripherals = self.peripheralsToConnect.filter {
            $0.state == .disconnected || $0.state == .disconnecting
        }
        disconnectedPeripherals.prefix(
            CBCentralManager.maxNumberOfConcurrentPeripheralConnections -
                self.connectingConnectedPeripheralIdentifiers.count
        ).forEach {
            self.connectIfNeeded(peripheral: $0)
        }
    }
    
    private func connectIfNeeded(peripheral: CBPeripheral) {
        guard let centralManager = centralManager else {
            return
        }
        if peripheral.state != .connected {
            if peripheral.state != .connecting {
                self.centralManager?.connect(peripheral, options: nil)
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Central manager connecting peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")')"))
                self.setupConnectingTimeoutTimer(for: peripheral)
                self.connectingPeripheralIdentifiers.insert(peripheral.identifier)
            }
        }
        else {
            self._centralManager(centralManager, didConnect: peripheral)
        }
    }
    
    private func setupConnectingTimeoutTimer(for peripheral: CBPeripheral) {
        let timer = Timer.init(
            timeInterval: .peripheralConnectingTimeout,
            target: self,
            selector: #selector(_connectingTimeoutTimerFired(timer:)),
            userInfo: ["peripheral" : peripheral],
            repeats: false
        )
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier]?.invalidate()
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier] = timer
    }
    
    @objc private func _connectingTimeoutTimerFired(timer: Timer) {
        let userInfo = timer.userInfo
        self.dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            guard let dict = userInfo as? [AnyHashable : Any],
                let peripheral = dict["peripheral"] as? CBPeripheral else {
                    return
            }
            if peripheral.state != .connected {
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Connecting did time out for peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")')"))
                self.flushPeripheral(peripheral)
            }
        }
    }
    
    private func flushPeripheral(_ peripheral: CBPeripheral) {
        self.peripheralsToReadTCNFrom.remove(peripheral)
        self.peripheralsToWriteTCNTo.remove(peripheral)
        self.tcnsForRemoteDeviceIdentifiers[peripheral.identifier] = nil
        self.estimatedDistancesForRemoteDeviceIdentifiers[peripheral.identifier] = nil
        self.contactDeviceIdForRemoteDeviceIdentifiers[peripheral.identifier] = nil
        self.discoveredPeripherals.remove(peripheral)
        self.cancelConnectionIfNeeded(for: peripheral)
    }
    
    private func cancelConnectionIfNeeded(for peripheral: CBPeripheral) {
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier]?.invalidate()
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier] = nil
        if peripheral.state == .connecting || peripheral.state == .connected {
            self.centralManager?.cancelPeripheralConnection(peripheral)
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Central manager cancelled peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') connection"))
        }
        peripheral.delegate = nil
        self.connectingPeripheralIdentifiers.remove(peripheral.identifier)
        self.connectedPeripheralIdentifiers.remove(peripheral.identifier)
        self.discoveringServicesPeripheralIdentifiers.remove(peripheral.identifier)
        peripheral.services?.forEach {
            $0.characteristics?.forEach {
                self.characteristicsBeingRead.remove($0)
                self.characteristicsBeingWritten.remove($0)
            }
        }
        self.connectPeripheralsIfNeeded()
    }
}

extension TCNBluetoothServiceImpl: CBCentralManagerDelegate {
    
    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String : Any]
    ) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Central manager will restore state=\(dict.description)"))
        // Store the peripherals so we can cancel the connections to them when
        // the central manager's state changes to `poweredOn`.
        self.restoredPeripherals =
            dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Central manager did update state=\(String(describing: central.state.rawValue))"))
        self.stopCentralManager()
        switch central.state {
            case .poweredOn:
                self.restoredPeripherals?.forEach({
                    central.cancelPeripheralConnection($0)
                })
                self.restoredPeripherals = nil
                self._startScan()
                self._startBeaconScan()
            default:
                ()
        }
    }
    
    private func _startScan() {
        guard let central = self.centralManager else { return }
        #if targetEnvironment(macCatalyst)
        // CoreBluetooth on macCatalyst doesn't discover the peripheral services
        // of iOS apps in the background-running or suspended state.
        // Therefore we scan for everything.
        let services: [CBUUID]? = nil
        #else
        let services: [CBUUID] = [.tcnService]
        #endif
        let options: [String : Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey :
                NSNumber(booleanLiteral: true)
        ]
        central.scanForPeripherals(
            withServices: services,
            options: options
        )
        #if targetEnvironment(macCatalyst)
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Central manager scanning for peripherals with services=\(services ?? "") options=\(options.description)"))
        #else
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Central manager scanning for peripherals with services=\(services) options=\(options.description)"))
        #endif
    }

// 06-04-20 - EGC - Adding scanning for iBeacons
    private func _startBeaconScan()
    {
        if let uuid = UUID(uuidString: TCNConstants.BeaconUUIDString) {
            let beaconRegion = CLBeaconRegion(uuid: uuid, identifier: TCNConstants.testBeaconIdentifier)
            let beaconIdentityConstraint = CLBeaconIdentityConstraint(uuid: uuid)
            locationManager.startMonitoring(for: beaconRegion)
            locationManager.startRangingBeacons(satisfying: beaconIdentityConstraint)
            locationManager.startUpdatingLocation()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Only Android can enable advertising data in the service data field.
        let isAndroid = ((advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID : Data])?[.tcnService] != nil)
        
        var deviceModelId: UInt32 = 0
        if let serviceData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, serviceData.count >= 2 {
            let mID = Data(serviceData[0..<2])

            deviceModelId = UInt32(mID[0]) | (UInt32(mID[1]) << 8)
        }
        
        let estimatedDistanceMeters = getEstimatedDistanceMeters(
            RSSI: RSSI.doubleValue,
            measuredRSSIAtOneMeter: getMeasuredRSSIAtOneMeter(
                advertisementData: advertisementData,
                hintIsAndroid: isAndroid
            )
        )
        self.estimatedDistancesForRemoteDeviceIdentifiers[peripheral.identifier] = estimatedDistanceMeters
        self.contactDeviceIdForRemoteDeviceIdentifiers[peripheral.identifier] = deviceModelId
        
//        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Central manager did discover peripheral (uuid=\(peripheral.identifier.description) new=\(!self.discoveredPeripherals.contains(peripheral)) name='\(peripheral.name ?? "")) RSSI=\(RSSI.intValue) (estimatedDistance=\(String(format: "%.2f", estimatedDistanceMeters))) advertisementData=\(advertisementData.description)"))
        
        self.discoveredPeripherals.insert(peripheral)
        
        // Did we find a TCN from the peripheral already?
        if let tcn = self.tcnsForRemoteDeviceIdentifiers[peripheral.identifier] {
            self.didFindTCN(tcn, estimatedDistance: self.estimatedDistancesForRemoteDeviceIdentifiers[peripheral.identifier], deviceId: deviceModelId)
        }
        else {
            let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
            
            // Check if we can extract TCN from service data
            // The service data = bridged TCN + first 4 bytes of the current TCN.
            // When the Android bridges a TCN of nearby iOS devices, the
            // last 4 bytes are different than the first 4 bytes.
            if let serviceData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, serviceData.count >= 18 {
                
                let tcn = Data(serviceData[2..<18])
                self.tcnsForRemoteDeviceIdentifiers[peripheral.identifier] = tcn
                self.didFindTCN(tcn, estimatedDistance: self.estimatedDistancesForRemoteDeviceIdentifiers[peripheral.identifier], deviceId: deviceModelId)
                
                if serviceData.count == 22 {
                    let shortTemporaryIdentifier = Data(serviceData[18..<22])
                                    
                    // The remote device is an Android one. Write a TCN to it,
                    // because it can not find the TCN of this iOS device while this
                    // iOS device is in the background, which is most of the time.
                    // But only write if we haven't already.
                    if isConnectable && !self.shortTemporaryIdentifiersOfPeripheralsToWhichWeDidWriteTCNTo.contains(shortTemporaryIdentifier)  {
                        self.peripheralsToWriteTCNTo.insert(peripheral)
                        self.connectPeripheralsIfNeeded()
                        if self.shortTemporaryIdentifiersOfPeripheralsToWhichWeDidWriteTCNTo.count > 65536 {
                            // Ensure our list doesn't grow too much...
                            self.shortTemporaryIdentifiersOfPeripheralsToWhichWeDidWriteTCNTo.removeFirst()
                        }
                        self.shortTemporaryIdentifiersOfPeripheralsToWhichWeDidWriteTCNTo.insert(shortTemporaryIdentifier)
                    }
                }
            }
            else {
                if isConnectable {
                    // The remote device is an iOS one. Read its TCN.
                    self.peripheralsToReadTCNFrom.insert(peripheral)
                    self.connectPeripheralsIfNeeded()
                }
            }
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Central manager did connect peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")')"))
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier]?.invalidate()
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier] = nil
        self.connectingPeripheralIdentifiers.remove(peripheral.identifier)
        // Bug workaround: Ignore duplicate connect callbacks from CoreBluetooth.
        guard !self.connectedPeripheralIdentifiers.contains(
            peripheral.identifier) else {
                return
        }
        self.connectedPeripheralIdentifiers.insert(peripheral.identifier)
        self._centralManager(central, didConnect: peripheral)
    }
    
    func _centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        self.discoverServices(for: peripheral)
    }
    
    private func discoverServices(for peripheral: CBPeripheral) {
        guard !self.discoveringServicesPeripheralIdentifiers.contains(
            peripheral.identifier) else {
                return
        }
        self.discoveringServicesPeripheralIdentifiers.insert(peripheral.identifier)
        peripheral.delegate = self
        if peripheral.services == nil {
            let services: [CBUUID] = [.tcnService]
            peripheral.discoverServices(services)
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') discovering services=\(services)"))
        }
        else {
            self._peripheral(peripheral, didDiscoverServices: nil)
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, level: .error, message: "Central manager did fail to connect peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') error=\(String(describing: error))"))
        if #available(iOS 12.0, macOS 10.14, macCatalyst 13.0, tvOS 12.0,
            watchOS 5.0, *) {
            if let error = error as? CBError,
                error.code == CBError.operationNotSupported {
                self.peripheralsToReadTCNFrom.remove(peripheral)
                self.peripheralsToWriteTCNTo.remove(peripheral)
            }
        }
        self.cancelConnectionIfNeeded(for: peripheral)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        if let error = error {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, level: .error, message: "Central manager did disconnect peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') error=\(String(describing: error))"))
        }
        else {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Central manager did disconnect peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")')"))
        }
        self.cancelConnectionIfNeeded(for: peripheral)
    }
}

extension TCNBluetoothServiceImpl: CBPeripheralDelegate {
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let error = error {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, level: .error, message:
                    "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') did discover services error=\(String(describing: error))"))
        }
        else {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') did discover services"))
        }
        self._peripheral(peripheral, didDiscoverServices: error)
    }
    
    func _peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        self.discoveringServicesPeripheralIdentifiers.remove(peripheral.identifier)
        guard error == nil else {
            self.cancelConnectionIfNeeded(for: peripheral)
            return
        }
        guard let services = peripheral.services, services.count > 0 else {
            self.peripheralsToReadTCNFrom.remove(peripheral)
            self.peripheralsToWriteTCNTo.remove(peripheral)
            self.cancelConnectionIfNeeded(for: peripheral)
            return
        }
        let servicesWithCharacteristicsToDiscover = services.filter {
            $0.characteristics == nil
        }
        if servicesWithCharacteristicsToDiscover.count == 0 {
            self.startTransfers(for: peripheral)
        }
        else {
            servicesWithCharacteristicsToDiscover.forEach { service in
                let characteristics: [CBUUID] = [.tcnCharacteristic]
                peripheral.discoverCharacteristics(characteristics, for: service)
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') discovering characteristics=\(characteristics.description) for service=\(service.description)"))
            }
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error = error {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, level: .error, message: "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') did discover characteristics for service=\(service.description) error=\(String(describing: error))"))
        }
        else {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') did discover characteristics for service=\(service.description)"))
        }
        guard error == nil, let services = peripheral.services else {
            self.cancelConnectionIfNeeded(for: peripheral)
            return
        }
        let servicesWithCharacteristicsToDiscover = services.filter {
            $0.characteristics == nil
        }
        // Have we discovered the characteristics of all the services, yet?
        if servicesWithCharacteristicsToDiscover.count == 0 {
            self.startTransfers(for: peripheral)
        }
    }
    
    private func shouldReadTCN(from peripheral: CBPeripheral) -> Bool {
        return self.peripheralsToReadTCNFrom.contains(peripheral)
    }
    
    private func shouldWriteTCN(to peripheral: CBPeripheral) -> Bool {
        return self.peripheralsToWriteTCNTo.contains(peripheral)
    }
    
    private func startTransfers(for peripheral: CBPeripheral) {
        guard let services = peripheral.services else {
            self.cancelConnectionIfNeeded(for: peripheral)
            return
        }
        services.forEach { service in
            self._peripheral(
                peripheral,
                didDiscoverCharacteristicsFor: service,
                error: nil
            )
        }
    }
    
    func _peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else {
            self.cancelConnectionIfNeeded(for: peripheral)
            return
        }
        
        if let tcnCharacteristic = service.characteristics?.first(where: {
            $0.uuid == .tcnCharacteristic
        }) {
            // Read the number, if needed.
            if self.shouldReadTCN(from: peripheral) {
                if !self.characteristicsBeingRead.contains(tcnCharacteristic) {
                    self.characteristicsBeingRead.insert(tcnCharacteristic)
                    
                    peripheral.readValue(for: tcnCharacteristic)
                    LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') reading value for characteristic=\(tcnCharacteristic.description) for service=\(service.description)"))
                }
            } // Write the number, if needed.
            else if self.shouldWriteTCN(to: peripheral) {
                if !self.characteristicsBeingWritten.contains(tcnCharacteristic) {
                    self.characteristicsBeingWritten.insert(tcnCharacteristic)
                    
                    let tcn = generateTCN()
                    let value = tcn
                    
                    peripheral.writeValue(
                        value,
                        for: tcnCharacteristic,
                        type: .withResponse
                    )
                    LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') writing value for characteristic=\(tcnCharacteristic.description) for service=\(service.description)"))
                }
                
            }
        }
        else {
            self.cancelConnectionIfNeeded(for: peripheral)
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, level: .error, message: "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') did update value for characteristic=\(characteristic.description) for service=\(characteristic.service.description) error=\(String(describing: error))"))
        }
        else {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') did update value=\(String(format: "%{iec-bytes}d", characteristic.value?.count ?? 0)) for characteristic=\(characteristic.description) for service=\(characteristic.service.description)"))
        }
        self.characteristicsBeingRead.remove(characteristic)
        do {
            guard error == nil else {
                return
            }
            guard let value = characteristic.value, value.count >= 16 else {
                throw CBATTError(.invalidPdu)
            }
            let tcn = Data(value[0..<16])
            self.tcnsForRemoteDeviceIdentifiers[peripheral.identifier] = tcn
            self.didFindTCN(tcn, estimatedDistance: self.estimatedDistancesForRemoteDeviceIdentifiers[peripheral.identifier], deviceId: self.contactDeviceIdForRemoteDeviceIdentifiers[peripheral.identifier])
        }
        catch {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, level: .error, message: "Processing value failed=\(String(describing: error))"))
        }
        let allCharacteristics = peripheral.characteristics(with: .tcnCharacteristic)
        if self.characteristicsBeingRead
            .intersection(allCharacteristics).isEmpty {
            self.peripheralsToReadTCNFrom.remove(peripheral)
            self.cancelConnectionIfNeeded(for: peripheral)
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, level: .error, message:
                    "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') did write value for characteristic=\(characteristic.description) for service=\(characteristic.service.description) error=\(String(describing: error))"))
        }
        else {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') did write value for characteristic=\(characteristic.description) for service=\(characteristic.service.description)"))
        }
        self.characteristicsBeingWritten.remove(characteristic)
        let allCharacteristics = peripheral.characteristics(with: .tcnCharacteristic)
        if self.characteristicsBeingWritten
            .intersection(allCharacteristics).isEmpty {
            self.peripheralsToWriteTCNTo.remove(peripheral)
            self.cancelConnectionIfNeeded(for: peripheral)
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didModifyServices invalidatedServices: [CBService]
    ) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral (uuid=\(peripheral.identifier.description) name='\(peripheral.name ?? "")') did modify services=\(invalidatedServices)"))
        if invalidatedServices.contains(where: {$0.uuid == .tcnService}) {
            self.flushPeripheral(peripheral)
        }
    }
}

extension TCNBluetoothServiceImpl: CBPeripheralManagerDelegate {
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        willRestoreState dict: [String : Any]
    ) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral manager will restore state=\(dict.description)"))
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral manager did update state=\(String(describing: peripheral.state.rawValue))"))
        self._peripheralManagerDidUpdateState(peripheral)
    }
    
    func _peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        //    if #available(OSX 10.15, macCatalyst 13.1, iOS 13.1, tvOS 13.0, watchOS 6.0, *) {
        //      self.service?.bluetoothAuthorization =
        //        BluetoothAuthorization(
        //          cbManagerAuthorization: CBManager.authorization
        //        ) ?? .notDetermined
        //    }
        //    else if #available(OSX 10.15, macCatalyst 13.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
        //      self.service?.bluetoothAuthorization =
        //        BluetoothAuthorization(
        //          cbManagerAuthorization: peripheral.authorization
        //        ) ?? .notDetermined
        //    }
        //    else if #available(OSX 10.13, iOS 9.0, *) {
        //      self.service?.bluetoothAuthorization =
        //        BluetoothAuthorization(
        //          cbPeripheralManagerAuthorizationStatus:
        //          CBPeripheralManager.authorizationStatus()
        //        ) ?? .notDetermined
        //    }
        self.stopPeripheralManager()
        switch peripheral.state {
            case .poweredOn:
                let service = CBMutableService.tcnPeripheralService
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral manager adding service=\(service.description)"))
                peripheral.add(service)
            default:
                ()
        }
    }
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: Error?
    ) {
        if let error = error {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, level: .error, message: "Peripheral manager did add service=\(service.description) error=\(String(describing: error))"))
        }
        else {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral manager did add service=\(service.description)"))
            self.startAdvertising()
        }
    }
    
    private func startAdvertising() {
        ProfileMapping.shared.loadDefaultPhoneModels()
        let modelID = ProfileMapping.shared.deviceModelNumber
        let advertisementData: [String : Any] = [
            CBAdvertisementDataServiceUUIDsKey : [CBUUID.tcnService],
            CBAdvertisementDataLocalNameKey : modelID,
            // iOS 13.4 (and older) does not support advertising service data
            // for third-party apps.
            // CBAdvertisementDataServiceDataKey : self.generateTCN()
        ]
        self.peripheralManager?.startAdvertising(advertisementData)
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral manager starting advertising advertisementData=\(advertisementData.description)"))
    }
    
    func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: Error?
    ) {
        if let error = error {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, level: .error, message: "Peripheral manager did start advertising error=\(String(describing: error))"))
        }
        else {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral manager did start advertising"))
        }
    }
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveRead request: CBATTRequest
    ) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral manager did receive read request=\(request.description)"))
        
        let tcn = generateTCN()
        request.value = tcn
        
        peripheral.respond(to: request, withResult: .success)
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral manager did respond to read request with result=\(CBATTError.success.rawValue)"))
    }
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral manager did receive write requests=\(requests.description)"))
        
        for request in requests {
            do {
                guard request.characteristic.uuid == .tcnCharacteristic else {
                    throw CBATTError(.requestNotSupported)
                }
                guard let value = request.value, value.count >= 16 else {
                    throw CBATTError(.invalidPdu)
                }
                let tcn = Data(value[0..<16])
                self.tcnsForRemoteDeviceIdentifiers[request.central.identifier] = tcn
                self.didFindTCN(tcn, estimatedDistance: self.estimatedDistancesForRemoteDeviceIdentifiers[request.central.identifier], deviceId: self.contactDeviceIdForRemoteDeviceIdentifiers[request.central.identifier])
            }
            catch {
                var result = CBATTError.invalidPdu
                if let error = error as? CBATTError {
                    result = error.code
                }
                peripheral.respond(to: request, withResult: result)
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral manager did respond to request=\(request.description) with result=\(result.rawValue)"))
                return
            }
        }
        
        if let request = requests.first {
            peripheral.respond(to: request, withResult: .success)
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Peripheral manager did respond to request=\(request.description) with result=\(CBATTError.success.rawValue)"))
        }
    }

// 06-04-20 - EGC - Adding scanning for iBeacons
    // MARK: CLLocationManager Delegate methods

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
    {
        if status == .authorizedAlways
        {
            if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self)
            {
                if CLLocationManager.isRangingAvailable()
                {
                    _startBeaconScan()
                }
            }
        }
        else if status == .notDetermined
        {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "TCNBluetoothServiceUmpl LocationManager failed with error: \(error.localizedDescription)"))
    }

    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion)
    {
        for beacon in beacons
        {
            let estimatedDistanceMeters = getEstimatedDistanceMeters(RSSI: Double(beacon.rssi))
            self.estimatedDistancesForRemoteDeviceIdentifiers[beacon.uuid] = estimatedDistanceMeters
            
            //generate beaconId from major and minor
            let major = beacon.major
            let minor = beacon.minor
            let beaconId = minor.stringValue + major.stringValue
            //determine beacon deviceId
            var deviceId: UInt32 = 0
            let beaconUuid = beacon.uuid.uuidString
            switch(beaconUuid) {
            case TCNConstants.BeaconUUIDString:
                deviceId = UInt32(10)
                break
            case TCNConstants.LOBeaconUUIDString:
                deviceId = UInt32(11)
                break
            case TCNConstants.IOSBeaconUUIDString:
                deviceId = UInt32(12)
                break
            case TCNConstants.HIDBeaconUUIDString:
                deviceId = UInt32(13)
                break
            default:
                deviceId = UInt32(0)
            }
            //check if beacon is a registered beacon
            if FMPersistenceManager.sharedManager.checkForValue(name: AppConfigurationManager.persistenceFieldDiscoveredBeacons, from: .UserDefaults)
            {
                let readResponse = FMPersistenceManager.sharedManager.readValue(name: AppConfigurationManager.persistenceFieldDiscoveredBeacons, from: .UserDefaults)
                let readResult = readResponse.result
                if readResult == .Success
                {
                    let registeredBeacons = readResponse.value as! [String]
                    if registeredBeacons.contains(beaconId) == true
                    {
                        //skip if beacon detected is our registered beacon
                        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Skipping registered beacon with id: \(beaconId)"))
                        continue
                        }
                    }
                }
                if let foundTcn = self.foundBeacons[beaconId] {
                    
                    // Already know the TCN for this beacon, show it as found
                     self.discoveredBeacons.insert(beacon)
                   // Did we find a TCN from the beacon already?
                    self.didFindTCN(foundTcn, estimatedDistance: self.estimatedDistancesForRemoteDeviceIdentifiers[beacon.uuid], deviceId: deviceId)
                    continue
                    
                } else {
                    //check if beacon is registered, if not wait 10
                    if(self.unregisteredBeacons[beaconId] == nil) {
                        self.retrieveBeaconTCN(beaconId: beaconId, beacon: beacon, deviceId: deviceId)
                    } else {
                        if let lastCheck = self.unregisteredBeacons[beaconId]{
                            if((lastCheck.addingTimeInterval(TimeInterval(TCNConstants.unregisteredBeaconCheckInterval))) <= Date()) {
                                self.retrieveBeaconTCN(beaconId: beaconId, beacon: beacon, deviceId: deviceId)
                        }
                    }
                }
            }
        }
    }
    
    func retrieveBeaconTCN(beaconId : String, beacon : CLBeacon, deviceId: UInt32) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .transmission, message: "Requesting TCN for beacon with id: \(beaconId)"))
        let getTcnReqest = GetTCNRequest(beaconId: beaconId)
        Network.request(router: getTcnReqest) { (result: Result<GetTCNModel, Error>) in
            guard case .success(_) = result else {
                self.unregisteredBeacons[beaconId] = Date()
                return
            }
            do {
                let tcnBase64 = try result.get().tcnBase64
                let tcnData = Data(base64Encoded: tcnBase64)!
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .reception, message: "Recieve beacon TCN from server:  \(tcnBase64)"))
                //self.discoveredBeacons.insert(beacon)
                self.foundBeacons[beaconId] = tcnData
                self.didFindTCN(tcnData, estimatedDistance: self.estimatedDistancesForRemoteDeviceIdentifiers[beacon.uuid], deviceId: deviceId)
                self.unregisteredBeacons[beaconId] = nil
            } catch {
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .error, message: "Error retrieve beacon TCN from server"))
                
                }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
      guard let _ = locations.last else {
        return
      }
      
      
      if UIApplication.shared.applicationState == .active {
        //foreground
      } else {
        //background
      }
    }
}
