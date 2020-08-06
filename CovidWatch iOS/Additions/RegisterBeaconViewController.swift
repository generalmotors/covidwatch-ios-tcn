/*******************************************************************************
* RegisterBeaconViewController.swift
*
* Title:            Contact Tracing
* Description:        Contact Tracing Monitoring and Reporting App
*                        This file contains the view controller for iBeacon registration screen
* Author:            Eric Crichlow
* Version:            1.0
*******************************************************************************/

import UIKit
import CoreLocation
import Foundation

class RegisterBeaconViewController: UIViewController, BLEManagerDelegate, ContactManagerDelegate
{
    private var registeredBeacons = [String]()
    
    func contactManagerRecordedContact(identifier: String, info: [String : Any]) {
    
    }
    
    func contactInRange(estimatedDistance: Double) {
    
    }
    
    func contactsLeftRange() {
    
    }
    

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var progressIndicator: UIActivityIndicatorView!
    @IBOutlet weak var findBeaconButton: UIButton!
    
    // MARK: View Lifecycle

    override func viewDidLoad()
    {
        super.viewDidLoad()
        statusLabel.isHidden = true
        progressIndicator.isHidden = true
        
    }
    
    // MARK: Business Logic

    @IBAction func findBeacon(_ sender: UIButton)
    {
        statusLabel.isHidden = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimating()
        statusLabel.text = "Scanning for closest iBeacon"
        BLEManager.sharedManager.registerDelegate(delegate: self)
        BLEManager.sharedManager.startBeaconScanning()
    }

    // MARK: BLEManager Delegate

    func BLEBluetoothManagerLogMessage(message: String)
    {
    
    }

    func BLEBluetoothManagerError(error: Error)
    {
    
    }

    func BLEBluetoothManagerDiscoveredDevicesUpdated(devices: [CLBeacon: NSNumber])
    {
    
    }

    func BLEBluetoothManagerDeterminedClosestBeacon(beacon: CLBeacon)
    {
        DispatchQueue.main.async
        {
            self.statusLabel.isHidden = false
            self.progressIndicator.isHidden = false
            self.progressIndicator.stopAnimating()
            
            let major = beacon.major
            let minor = beacon.minor
            let beaconId = minor.stringValue + major.stringValue
            ContactManager.sharedManager.registerDelegate(delegate: self)
            ContactManager.sharedManager.associateBeaconToAdvertisedTCN(beaconId: beaconId)
            self.statusLabel.text = "Found and registered new iBeacon"
            if(!self.registeredBeacons.contains(beaconId)) {
                self.registeredBeacons.append(beaconId)
                FMPersistenceManager.sharedManager.saveValue(name: AppConfigurationManager.persistenceFieldDiscoveredBeacons, value: self.registeredBeacons, type: .Array, destination: .UserDefaults, protection: .Unsecured, lifespan: .Immortal, expiration: nil, overwrite: true)
            }
            //submit registered beacon to the back end
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false)
            {
                timer in
                DispatchQueue.main.async
                {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
}


