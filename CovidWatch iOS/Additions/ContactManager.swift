/*******************************************************************************
* LogManager.swift
* Author:            Eric Crichlow
* Version:            1.0
********************************************************************************
*    04/14/19        *    EGC    *    File creation date
*******************************************************************************/

import Foundation
import CryptoKit
import CoreData

protocol ContactManagerDelegate : class
{
    func contactManagerRecordedContact(identifier: String, info: [String: Any])
    func contactInRange(estimatedDistance: Double)
    func contactsLeftRange()
}

public class ContactManager: NSObject
{

    // TCN integration
    var tcnBluetoothService: TCNBluetoothService?
    var advertisedTcns = [Data]()
    var beaconRegisteredFlag = false

//    private var scannedContacts = [String: [Double]]()
    private var scannedContacts = [String: [[String: Any]]]()
    private var encounteredContacts = [String: [String: Any]]()
    private var recordedContacts = [String]()
    private var delegateList = NSPointerArray.weakObjects()
    private var noContactsTimer: Timer?
    private var lastLocalNotificationDate: Date?
    private var samplingStartTime: Date

    public static let sharedManager = ContactManager()

    override init()
    {
        samplingStartTime = Date()
    }

    // MARK: Business Logic

    func registerDelegate(delegate: ContactManagerDelegate)
    {
        for nextDelegate in delegateList.allObjects
        {
            let del = nextDelegate as! ContactManagerDelegate
            if del === delegate
            {
                return
            }
        }
        let pointer = Unmanaged.passUnretained(delegate as AnyObject).toOpaque()
        delegateList.addPointer(pointer)
    }

    func unregisterDelegate(delegate: ContactManagerDelegate)
    {
        var index = 0
        for nextDelegate in delegateList.allObjects
        {
            let del = nextDelegate as! ContactManagerDelegate
            if del === delegate
            {
                break
            }
            index += 1
        }
        if index < delegateList.count
        {
            delegateList.removePointer(at: index)
        }
    }

    // TODO: Okay, this function does more contct processing than just starting tracking. Need to extract the other stuff into a processing contact method
    @discardableResult public func startTrackingContactIfNew(identifier: String, distance: Double) -> Bool
    {
        let keys = encounteredContacts.keys
        transmitContactsInRange(distance)
        // May want to consider bailing out here if contact isn't within the "too close" range
        DispatchQueue.main.async
        {
            if let timer = self.noContactsTimer        // Use timer to determine when lack of reports means device has moved out of range
            {
                timer.invalidate()
            }
            self.noContactsTimer = Timer.scheduledTimer(withTimeInterval: AppConfigurationManager.contactTimeTillReportGone, repeats: false)
            {
                timer in
                self.noContactsTimer = nil
                let keys = self.encounteredContacts.keys
                for key in keys
                {
                    if var contactInfo = self.encounteredContacts[key]
                    {
                        if contactInfo[AppConfigurationManager.contactFieldEndTime] == nil
                        {
                            if let startTime = contactInfo[AppConfigurationManager.contactFieldStartTime] as? Date
                            {
                                if Date().timeIntervalSince(startTime) >= AppConfigurationManager.contactTimeTillRecord
                                {
                                    contactInfo[AppConfigurationManager.contactFieldEndTime] = Date()
                                }
                                else    // Any contanct that hasn't reached the reporting milestone should be reset
                                {
                                    contactInfo[AppConfigurationManager.contactFieldStartTime] = nil
                                }
                            }
                        }
                    }
                }
                self.transmitContactsLeftRange()
            }
        }
//        if distance <= AppConfigurationManager.contactMinDistanceDangerZone
        if distance <= AppConfigurationManager.contactMinDistanceDangerZoneInFeet
        {
            if keys.contains(identifier) && !recordedContacts.contains(identifier)
            {
                let now = Date()
                if var contactInfo = encounteredContacts[identifier]
                {
                    if let contactStartTime = contactInfo[AppConfigurationManager.contactFieldStartTime] as? Date, let totalSamples = contactInfo[AppConfigurationManager.contactFieldTotalSamples] as? Int, let totalDistance = contactInfo[AppConfigurationManager.contactFieldTotalDistance] as? Double
                    {
                        contactInfo[AppConfigurationManager.contactFieldTotalSamples] = totalSamples + 1
                        contactInfo[AppConfigurationManager.contactFieldTotalDistance] = totalDistance + distance
                        if now.timeIntervalSince(contactStartTime) > AppConfigurationManager.contactTimeTillRecord
                        {
                            transmitRecordedContact(identifier, contactInfo)
                            recordedContacts.append(identifier)
                            if let data = dataForIdentifier(identifier: identifier)
                            {
                                logFoundTemporaryContactNumber(with: data, estimatedDistance:  getAverageDistanceForContact(identifier: identifier))
                            }
                        }
                    }
                }
                return false
            }
            else
            {
                encounteredContacts[identifier] = [AppConfigurationManager.contactFieldDistance: distance, AppConfigurationManager.contactFieldStartTime: Date(), AppConfigurationManager.contactFieldTotalSamples: Int(1), AppConfigurationManager.contactFieldTotalDistance: distance]
                return true
            }
        }
        else
        {
            return false
        }
    }

    public func getAverageDistanceForContact(identifier: String) -> Double?
    {
        if let contactInfo = encounteredContacts[identifier]
        {
            if let totalSamples = contactInfo[AppConfigurationManager.contactFieldTotalSamples] as? Int, let totalDistance = contactInfo[AppConfigurationManager.contactFieldTotalDistance] as? Double
            {
                return totalDistance / Double(totalSamples)
            }
        }
        return nil
    }

    public func formatIdentifier(data: Data) -> String
    {
        // For now, just Base64 encode the data to make a readable identifer, primarily for logging
        return data.base64EncodedString()
    }

    public func dataForIdentifier(identifier: String) -> Data?
    {
        // For now, the identifier is just a Base64 encoded version of the TCN data field
        if let data = Data(base64Encoded: identifier)
        {
            return data
        }
        return nil
    }

    // Trying out a new normalization algorithm that averages distance over a period of time
//    public func normalizeDistance(identifier: String, distance: Double) -> Double?
//    {
//        let keys = scannedContacts.keys
//        if keys.contains(identifier)
//        {
//            if let contactSamples = scannedContacts[identifier]
//            {
//                if var contact = scannedContacts[identifier]
//                {
//                    let updatedContact: [String: Any] = [AppConfigurationManager.contactFieldSampleTime: Date(), AppConfigurationManager.contactFieldSampleDistance: distance]
//                    contact.append(updatedContact)
//                    scannedContacts[identifier] = contact
//                }
//                // Only process if the first sample is at least x seconds old
//                if let firstSample = contactSamples.first, let start = firstSample[AppConfigurationManager.contactFieldSampleTime] as? Date
//                {
//                    if Date().timeIntervalSince(start) < AppConfigurationManager.contactTimeSamplesToNormalize
//                    {
//                        return nil
//                    }
//                }
//                // First, filter out readings older than a predetermined age
//                var filteredContactArray = [[String: Any]]()
//                for sample in contactSamples
//                {
//                    if let sampleTime = sample[AppConfigurationManager.contactFieldSampleTime] as? Date
//                    {
//                        if Date().timeIntervalSince(sampleTime) < AppConfigurationManager.contactTimeSamplesToNormalize
//                        {
//                            filteredContactArray.append(sample)
//                        }
//                    }
//                }
//                // Finally, average all of the samples that are within the desired age range
//                var totalDistance = 0.0
//                for sample in filteredContactArray
//                {
//                    if let distance = sample[AppConfigurationManager.contactFieldSampleDistance] as? Double
//                    {
//                        totalDistance += distance
//                    }
//                }
//                let averageDistance = totalDistance / Double(filteredContactArray.count)
//                return averageDistance * AppConfigurationManager.metersToFeetMultiplier
//            }
//        }
//        else
//        {
//            var newContact = [[String: Any]]()
//            newContact.append([AppConfigurationManager.contactFieldSampleTime: Date(), AppConfigurationManager.contactFieldSampleDistance: distance])
//            scannedContacts[identifier] = newContact
//
//        }
//        return nil
//    }

/*
    // Currently, we're only going to report every x times we receive a report from TCN, in which we'll toss the high and low values and average the remaining distances
    public func normalizeDistance(identifier: String, distance: Double) -> Double?
    {
        let keys = scannedContacts.keys
        if keys.contains(identifier)
        {
            if var distanceArray = scannedContacts[identifier] as? [Double]
            {
                distanceArray.append(distance)
                scannedContacts[identifier] = distanceArray
                if distanceArray.count % AppConfigurationManager.contactMinSamplesToProcess == 0
                {
                    distanceArray.sort()
                    distanceArray.removeLast()
                    distanceArray.removeFirst()
                    var totalDistance = 0.0
                    for nextDistance in distanceArray
                    {
                        totalDistance += nextDistance
                    }
                    let averageDistance = totalDistance / Double(distanceArray.count)
                    distanceArray.removeAll()
                    scannedContacts[identifier] = distanceArray
                    // Return distance in feet
                    return averageDistance * AppConfigurationManager.metersToFeetMultiplier
                }
            }
        }
        else
        {
            scannedContacts[identifier] = [distance]
        }
        return nil
    }
*/

    // MARK: Delegate callbacks

    private func transmitRecordedContact(_ identifier: String, _ info: [String: Any])
    {
        delegateList.compact()
        for nextDelegate in delegateList.allObjects
        {
            let delegate = nextDelegate as! ContactManagerDelegate
            delegate.contactManagerRecordedContact(identifier: identifier, info: info)
        }
    }

    private func transmitContactsInRange(_ estimatedDistance: Double)
    {
        delegateList.compact()
        for nextDelegate in delegateList.allObjects
        {
            let delegate = nextDelegate as! ContactManagerDelegate
            delegate.contactInRange(estimatedDistance: estimatedDistance)
        }
        DispatchQueue.main.async
        {
            let appState = UIApplication.shared.applicationState;
            var showNotification = false
//            if appState != .active && estimatedDistance < AppConfigurationManager.contactMinDistanceDangerZone
            if appState != .active && estimatedDistance < AppConfigurationManager.contactMinDistanceDangerZoneInFeet
            {
                if let notificationDate = self.lastLocalNotificationDate
                {
                    if Date().timeIntervalSince(notificationDate) > AppConfigurationManager.minTimeBetweenLocalNotifications
                    {
                        showNotification = true
                    }
                }
                else
                {
                    showNotification = true
                }
                if showNotification
                {
                    self.lastLocalNotificationDate = Date()
                    let content = UNMutableNotificationContent()
                    content.title = "Contact Tracing Alert"
                    content.body = ["Another Person has been detected in your personal space.",
                    "Please practice safe social distancing. ",
                    "Distance: \(estimatedDistance)"].joined()
                    content.sound = UNNotificationSound.default
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                    let request = UNNotificationRequest(identifier: "socialdistancing", content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request) { (error) in
                        if let err = error {
                            print("error\(err)")
                        }
                    }

                }
            }
        }
    }

    private func transmitContactsLeftRange()
    {
        delegateList.compact()
        for nextDelegate in delegateList.allObjects
        {
            let delegate = nextDelegate as! ContactManagerDelegate
            delegate.contactsLeftRange()
        }
    }

    // MARK: Code copied from existing app's TCN integration

    // Do not keep the report authorization key around in memory,
    // since it contains sensitive information.
    // Fetch it every time from our secure store (Keychain).
    private var reportAuthorizationKey: ReportAuthorizationKey {
        do {
            if let storedKey: Curve25519.Signing.PrivateKey = try GenericPasswordStore().readKey(account: "tcn-rak") {
                return ReportAuthorizationKey(reportAuthorizationPrivateKey: storedKey)
            } else {
                let newKey = Curve25519.Signing.PrivateKey()
                do {
                    try GenericPasswordStore().storeKey(newKey, account: "tcn-rak")
                } catch {
                }
                return ReportAuthorizationKey(reportAuthorizationPrivateKey: newKey)
            }
        } catch {
            // Shouldn't get here...
            return ReportAuthorizationKey(reportAuthorizationPrivateKey: Curve25519.Signing.PrivateKey())
        }
    }

    // It is safe to store the temporary contact key in the user defaults,
    // since it does not contain sensitive information.
    private var currentTemporaryContactKey: TemporaryContactKey {
        get {
            if let key = UserDefaults.shared.currentTemporaryContactKey {
                return key
            } else {
                // If there isn't a temporary contact key in the UserDefaults,
                // then use the initial temporary contact key.
                return self.reportAuthorizationKey.initialTemporaryContactKey
            }
        }
        set {
            UserDefaults.shared.currentTemporaryContactKey = newValue
        }
    }
    
    public func associateBeaconToAdvertisedTCN(beaconId: String) {
        //Assign beacon a generated tcn and post to back end
        if let tcn = self.tcnBluetoothService?.tcnGenerator() {
            self.advertisedTcns.append(tcn)
            let tcnBase64 = tcn.base64EncodedString()
            let submitTCNRequest = SubmitTCNRequest(beaconId: beaconId, tcnBase64: tcnBase64)
            Network.request(router: submitTCNRequest) { (result: Result<SubmitTCNModel, Error>) in
                guard case .success(_) = result else { return }
                do {
                    let tcnBase64 = try result.get().tcnBase64
                    LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .info, message: "Posted TCN to back end \(tcnBase64)"))
                } catch {
                    LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Error posting TCN"))
                    
                }
            }
        } else {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Unable to generate TCN"))
        }
       
    }
    public func configureContactTracingService()
    {
        self.tcnBluetoothService = TCNBluetoothService(tcnGenerator: { () -> Data in
                let temporaryContactNumber = self.currentTemporaryContactKey.temporaryContactNumber
                
                // Ratched the key so, we will get a new temporary contact
                // number the next time
                // swiftlint:disable:next todo
                // TODO: Handle the case when the ratcheting returns nil ->
                // Update RAK.
                if let newTemporaryContactKey = self.currentTemporaryContactKey.ratchet() {
                    self.currentTemporaryContactKey = newTemporaryContactKey
                }
            
                self.advertisedTcns.append(temporaryContactNumber.bytes)


                if self.advertisedTcns.count > 65535 {
                    //remove second value to keep beacon value in array
                    self.advertisedTcns.remove(at: 0)
                }
                
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "Configuring TCNBluetoothService with temporaryContactNumber: \(temporaryContactNumber)"))

                return temporaryContactNumber.bytes
                
            }, tcnFinder: { (data, estimatedDistance) in
                let identifier = self.formatIdentifier(data: data)
                let distance = estimatedDistance ?? 0.0

                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: LogManager.LogType.bluetooth, message: "TCN returned contact: \(identifier) at distance: \(distance)"))
                if Date().timeIntervalSince(self.samplingStartTime) >= AppConfigurationManager.contactTimeSamplesToNormalize
                {
                    self.startTrackingContactIfNew(identifier: identifier, distance: distance)
                    LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: LogManager.LogType.bluetooth, message: "Transmitting distance: \(distance) for identifier: \(identifier)"))
                }
//                    if !self.advertisedTcns.contains(data) {
//                        self.logFoundTemporaryContactNumber(with: data, estimatedDistance:  normalizedDistance)
//                    }
            }, errorHandler: { (_) in
                // swiftlint:disable:next todo
                // TODO: Handle errors, like user not giving permission to access Bluetooth, etc.
                ()
            }
        )
        self.tcnBluetoothService?.start()
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: LogManager.LogType.bluetooth, message: "Contact tracking started"))
    }
    
    func logFoundTemporaryContactNumber(with bytes: Data, estimatedDistance: Double?) {
        let now = Date()
        
        let context = PersistentContainer.shared.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.perform {
            do {
                let request: NSFetchRequest<TemporaryContactNumber> = TemporaryContactNumber.fetchRequest()
                request.predicate = NSPredicate(format: "bytes == %@", bytes as CVarArg)
                request.fetchLimit = 1
                let results = try context.fetch(request)
                var temporaryContactNumber: TemporaryContactNumber! = results.first
                if temporaryContactNumber == nil {
                    temporaryContactNumber = TemporaryContactNumber(context: context)
                    temporaryContactNumber.bytes = bytes
                }
                temporaryContactNumber.lastSeenDate = now
                if let estimatedDistance = estimatedDistance {
                    let currentEstimatedDistance: Double =
                        temporaryContactNumber.closestEstimatedDistanceMeters?.doubleValue ?? .infinity
                    if estimatedDistance < currentEstimatedDistance {
                        temporaryContactNumber.closestEstimatedDistanceMeters = NSNumber(value: estimatedDistance)
                    }
                }
                try context.save()
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "Logged TCN=\(bytes.base64EncodedString())"))
            } catch {
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Logging TCN failed: \(error)"))
            }
        }
    }
    
    func generateAndUploadReport() {
        do {
            // Assuming temporary contact numbers were changed at least every
            // 15 minutes, and the user was infectious in the last 14 days,
            // calculate the start period from the end period.
            let endIndex = currentTemporaryContactKey.index
            let minutesIn14Days = 60*24*7*2
            let periods = minutesIn14Days / 15
            let startIndex: UInt16 = UInt16(max(0, Int(endIndex) - periods))
            
            // swiftlint:disable force_unwrapping
            let tcnSignedReport = try self.reportAuthorizationKey.createSignedReport(
                memoType: .CovidWatchV1,
                memoData: "Hello, World!".data(using: .utf8)!,
                startIndex: startIndex,
                endIndex: endIndex
            )
            
            // Create a new Signed Report with `uploadState` set to
            // `.notUploaded` and store it in the local persistent store.
            // This will kick off an observer that watches for signed reports
            // which were not uploaded and will upload it.
            let context = PersistentContainer.shared.viewContext
            let signedReport = SignedReport(context: context)
            signedReport.configure(with: tcnSignedReport)
            signedReport.isProcessed = true
            signedReport.uploadState = UploadState.notUploaded.rawValue
            try context.save()
        } catch {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Generating report failed: \(error)"))
        }
    }

}

