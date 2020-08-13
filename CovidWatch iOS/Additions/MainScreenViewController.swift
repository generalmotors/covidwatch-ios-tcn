/*******************************************************************************
* MainScreenViewController.swift
*
* Author:			Eric Crichlow
*/

import UIKit
import CoreData

class MainScreenViewController: UIViewController, ContactManagerDelegate
{

    @IBOutlet weak var statusLabel: UILabel!
	@IBOutlet weak var statusDetailLabel: UILabel!
	@IBOutlet weak var statusImageView: UIImageView!
	@IBOutlet weak var positiveTestSlider: UISlider!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var todaysContactsLabel: UILabel!
    @IBOutlet weak var todaysExposureMinutesLabel: UILabel!
    @IBOutlet weak var allContactsLabel: UILabel!
    @IBOutlet weak var allExposureMinutesLabel: UILabel!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet var headerViewBottomConstraint: NSLayoutConstraint!
	@IBOutlet weak var registerBeaconButton: UIButton!
    @IBOutlet weak var calibrateInteractionButton: UIButton!
	
    @IBOutlet weak var modelLabel: UILabel!
    @IBOutlet weak var debugLabel: UILabel!

	// Overlays

	var interactionStart: Date?
	var interactions = [[String: [String: Any]]]()
    
    var testLastSubmittedDateObserver: NSKeyValueObservation?
    var mostRecentExposureDateObserver: NSKeyValueObservation?
    var isUserSickObserver: NSKeyValueObservation?
    var isCurrentUserSickObservation: NSKeyValueObservation?
    var signedReportsUploader: SignedReportsUploader?
    var currentUserExposureNotifier: CurrentUserExposureNotifier?
    let globalState = UserDefaults.shared
    var observer: NSObjectProtocol?
    var dist: Double?
    var detectedDeviceId: UInt32 = 0
    
    var currentStatusTooClose = false

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

	// MARK: View Lifecycle

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.debugLabel.isHidden = true

		ContactManager.sharedManager.registerDelegate(delegate: self)
		ContactManager.sharedManager.configureContactTracingService()
        
        self.configureIsCurrentUserSickObserver()
        self.signedReportsUploader = SignedReportsUploader()
        self.currentUserExposureNotifier = CurrentUserExposureNotifier()
    
		positiveTestSlider.addTarget(self, action: #selector(MainScreenViewController.reportPositiveTest), for: UIControl.Event.valueChanged)

        mostRecentExposureDateObserver = globalState.observe(
            \.mostRecentExposureDate,
            options: [],
            changeHandler: { (_, _) in
                self.showBannerIfNecessary()
        })

        updateInteractionLabels()
        showBannerIfNecessary()
    }
    
    private func configureIsCurrentUserSickObserver() {
        self.isCurrentUserSickObservation = UserDefaults.standard.observe(
            \.isUserSick, options: [.new]
        ) { [weak self] (_, change) in
            guard self != nil && change.newValue == true else { return }
            ContactManager.sharedManager.generateAndUploadReport()
        }
    }
    
    private func showBannerIfNecessary() {
        if globalState.isUserAtRiskForCovid && !globalState.isUserSick {
            headerView.isHidden = false
            headerViewBottomConstraint.isActive = true
        } else {
            headerView.isHidden = true
            headerViewBottomConstraint.isActive = false
        }
    }

	// MARK: Business Logic

	@IBAction func runPreCheck(_ sender: UIButton)
	{
		if let websiteURL = URL(string: AppConfigurationManager.preCheckDefaultURL)
		{
			if UIApplication.shared.canOpenURL(websiteURL)
			{
				UIApplication.shared.open(websiteURL, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
			}
		}
	}
    //send interaction calibration data to back end
    @IBAction func sendInteractionData(_ sender: UIButton)
    {
        let dialogMessage = UIAlertController(title: "Confirm Physical Distance", message: "Are you are physically 7ft away from the detected contact for this calibration? If not, press \"Cancel\" and try again.", preferredStyle: .alert)
        
        // Create Yes button with action handler
        let yes = UIAlertAction(title: "Yes", style: .default, handler: { (action) -> Void in
            
            let deviceModelNumber = ProfileMapping.shared.deviceModelNumber
            if let distance = self.dist {
                let submitCalibrationDataRequest = SubmitCalibrationDataRequest(deviceModel: Int(deviceModelNumber)!, contactDeviceModel: Int(self.detectedDeviceId), distanceDetected: distance)
                Network.request(router: submitCalibrationDataRequest) { (result: Result<SubmitCalibrationDataModel, Error>) in
                    guard case .success(_) = result else { return }
                    do {
                        let interactionId = try result.get().interactionId
                        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .info, message: "Posted Calibration Data to back end with Id: \(interactionId)"))
                    } catch {
                        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Error posting Calibration Data"))
                    }
                }
            }
        })
        
        // Create Cancel button with action handlder
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in
            
        }
        //Add OK and Cancel button to dialog message
        dialogMessage.addAction(yes)
        dialogMessage.addAction(cancel)
        
        // Present dialog message to user
        self.present(dialogMessage, animated: true, completion: nil)
    }

	@IBAction func registerBeacon(_ sender: UIButton)
	{
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		let registerBeaconViewController = storyboard.instantiateViewController(withIdentifier: "RegisterBeaconViewController") as! RegisterBeaconViewController
		modalPresentationStyle = .currentContext
		DispatchQueue.main.async
		{
			self.present(registerBeaconViewController, animated: true, completion: nil)
		}
	}

    private func configureStatusDisplay(distance: Double?, contactMinDistance: Double, deviceId: UInt32)
	{
        updateInteractionLabels()
        detectedDeviceId = deviceId;
        let deviceModelName = ProfileMapping.shared.deviceModelName(deviceId: deviceId)
        self.dist = distance
		DispatchQueue.main.async
		{
            guard let dist = distance
				else
				{
					let attributedStatusString = NSMutableAttributedString.init(string: "SAFE")
                    attributedStatusString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(named: "Safe Color")!, range: NSRange.init(location: 0, length: attributedStatusString.length))
					self.statusLabel.attributedText = attributedStatusString
					self.statusDetailLabel.text = "No people detected nearby"
					self.statusImageView.image = UIImage(named: "SafeIcon")
                    self.modelLabel.text = ""
                    #if PILOT
                    self.debugLabel.isHidden = true
                    #endif
					return
				}
			if dist <= contactMinDistance
			{
				let attributedStatusString = NSMutableAttributedString.init(string: "TOO CLOSE")
                attributedStatusString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(named: "Too Close Color")!, range: NSRange.init(location: 0, length: attributedStatusString.length))
				self.statusLabel.attributedText = attributedStatusString
				self.statusDetailLabel.text = "People detected in your space"
				self.statusImageView.image = UIImage(named: "TooClose")
                self.modelLabel.text = "Detected Model: \(deviceModelName)"
				self.currentStatusTooClose = true
                #if PILOT
                self.debugLabel.isHidden = false
                self.debugLabel.text = "Min Dist: \(Int(contactMinDistance))   Dist: \(String(format:"%.2f", dist))"
                #endif
                
			}
			// Because of how flaky distance reporting is, once we determine contact is too close, expand range
			// they have to leave before we consider them not too close anymore
            else if self.currentStatusTooClose && dist < (contactMinDistance + 5.0)
			{
				return
			}
			else
			{
				let attributedStatusString = NSMutableAttributedString.init(string: "SAFE")
				attributedStatusString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.green, range: NSRange.init(location: 0, length: attributedStatusString.length))
				self.statusLabel.attributedText = attributedStatusString
				self.statusDetailLabel.text = "No people detected nearby"
				self.statusImageView.image = UIImage(named: "SafeIcon")
                self.modelLabel.text = ""
				self.currentStatusTooClose = false
                #if PILOT
                self.debugLabel.isHidden = true
                #endif
			}
		}
	}

    @objc func reportPositiveTest(_ sender: UISlider)
    {
        if sender.value > 0.9 {
            performSegue(withIdentifier: "reportScreenSegue", sender: self)
		}
        
        positiveTestSlider.setValue(0, animated: true)
	}

	// MARK: ContactManager delegate methods

	func contactManagerRecordedContact(identifier: String, info: [String: Any])
	{
		interactions.append([identifier: info])
		// Store the interaction locally
		if FMPersistenceManager.sharedManager.checkForValue(name: AppConfigurationManager.persistenceFieldInteractions, from: .UserDefaults)
		{
			let readResponse = FMPersistenceManager.sharedManager.readValue(name: AppConfigurationManager.persistenceFieldInteractions, from: .UserDefaults)
			let readResult = readResponse.result
			if readResult == .Success
			{
				let recordedInteractions = readResponse.value as! [[String: [String: Any]]]
				var updatedInteractions = [[String: [String: Any]]]()
				updatedInteractions.append(contentsOf: recordedInteractions)
				updatedInteractions.append([identifier: info])
				FMPersistenceManager.sharedManager.saveValue(name: AppConfigurationManager.persistenceFieldInteractions, value:updatedInteractions, type: .Array, destination: .UserDefaults, protection: .Unsecured, lifespan: .Immortal, expiration: nil, overwrite: true)
			}
		}
		else
		{
			FMPersistenceManager.sharedManager.saveValue(name: AppConfigurationManager.persistenceFieldInteractions, value: [[identifier: info]], type: .Array, destination: .UserDefaults, protection: .Unsecured, lifespan: .Immortal, expiration: nil, overwrite: true)
		}
		DispatchQueue.main.async
		{
			self.updateInteractionLabels()
		}
	}

    func updateInteractionLabels() {
        let managedContext = PersistentContainer.shared.viewContext
        let fetchRequest: NSFetchRequest<TemporaryContactNumber> = TemporaryContactNumber.fetchRequest()
        guard let contacts = try? managedContext.fetch(fetchRequest) else { return }

        DispatchQueue.main.async {
            let todaysContacts = contacts.filter { contact in
                guard let foundDate = contact.foundDate else { return false }
                return Calendar.current.isDateInToday(foundDate)
            }

            self.todaysContactsLabel.text = "\(todaysContacts.count)"
            self.allContactsLabel.text = "\(contacts.count)"

            let todaysExposureTime = todaysContacts.reduce(0, self.calculateExposureTime)
            let totalExposureTime = contacts.reduce(0, self.calculateExposureTime)

            self.todaysExposureMinutesLabel.text = "\(todaysExposureTime)"
            self.allExposureMinutesLabel.text = "\(totalExposureTime)"
        }
    }

    func calculateExposureTime(partialResult: Int, contact: TemporaryContactNumber) -> Int {
        guard let foundDate = contact.foundDate, let lastSeenDate = contact.lastSeenDate else {
            return partialResult
        }

        let contactTime = Int(lastSeenDate.timeIntervalSince(foundDate) / 60)
        return partialResult + contactTime
    }

    func contactInRange(estimatedDistance: Double, contactMinDistance: Double, deviceId: UInt32)
	{
		if interactionStart == nil
		{
			interactionStart = Date()
		}
        configureStatusDisplay(distance: estimatedDistance, contactMinDistance: contactMinDistance, deviceId: deviceId)
	}

	func contactsLeftRange()
	{
		interactionStart = nil
        configureStatusDisplay(distance: nil, contactMinDistance: 0.0, deviceId: UInt32(0))
	}

	// Helper function inserted by Swift 4.2 migrator.
	fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
		return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
	}
    
    

}

// MARK: - UIScrollViewDelegate
extension MainScreenViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = Int(round(scrollView.contentOffset.x / scrollView.frame.size.width))
        guard page < pageControl.numberOfPages else { return }
        pageControl.currentPage = page
    }
    
}
