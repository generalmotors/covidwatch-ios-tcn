/*******************************************************************************
* MainScreenViewController.swift
*
* Description:	This file contains the view controller for the main screen
* Author:			Eric Crichlow
* Version:			1.0
********************************************************************************
*	05/13/20		*	EGC	*	File creation date
*******************************************************************************/

import UIKit
import CoreData

class MainScreenViewController: UIViewController, OverlayViewCallbackDelegate, ContactManagerDelegate
{

    @IBOutlet weak var statusLabel: UILabel!
	@IBOutlet weak var statusDetailLabel: UILabel!
	@IBOutlet weak var elapsedTimeLabel: UILabel!
	@IBOutlet weak var distanceLabel: UILabel!
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
	
	static let registerContactEndpointString = "/v1/contacts"

	// Overlays
	var debuggingOverlay: ViewOverlay?
	var logTextView: UITextView?
	var logUpdateTimer: Timer?
	var lastLogEntryArray = [LogEntry]()
	var logString = ""
	var pauseResumeButton: UIButton!

	var interactionStart: Date?
	var interactions = [[String: [String: Any]]]()
	var currentInteractions: [[String: [String: Any]]]?		// Temp storage for when we switch to viewing all interactions
    
    var testLastSubmittedDateObserver: NSKeyValueObservation?
    var mostRecentExposureDateObserver: NSKeyValueObservation?
    var isUserSickObserver: NSKeyValueObservation?
    var isCurrentUserSickObservation: NSKeyValueObservation?
    var signedReportsUploader: SignedReportsUploader?
    var currentUserExposureNotifier: CurrentUserExposureNotifier?
    let globalState = UserDefaults.shared
    var observer: NSObjectProtocol?
    
    var currentStatusTooClose = false

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

	// MARK: View Lifecycle

    override func viewDidLoad()
    {
        super.viewDidLoad()
//        #if !PRODUCTION
//		setupOverlays()
//        #endif
		ContactManager.sharedManager.registerDelegate(delegate: self)
		ContactManager.sharedManager.configureContactTracingService()
        
        self.configureIsCurrentUserSickObserver()
        self.signedReportsUploader = SignedReportsUploader()
        self.currentUserExposureNotifier = CurrentUserExposureNotifier()
    
        
		self.elapsedTimeLabel.isHidden = true
		self.distanceLabel.isHidden = true
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

	@IBAction func registerBeacon(_ sender: UIButton)
	{
//		self.performSegue(withIdentifier: "registerBeaconSegue", sender: self)
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		let registerBeaconViewController = storyboard.instantiateViewController(withIdentifier: "RegisterBeaconViewController") as! RegisterBeaconViewController
		modalPresentationStyle = .currentContext
		DispatchQueue.main.async
		{
			self.present(registerBeaconViewController, animated: true, completion: nil)
		}
	}
	
	private func setupOverlays()
	{

		debuggingOverlay = ViewOverlay(forParentViewController: self, with: ViewOverlayTabPosition.rightEdgeCenter, contentType: ViewOverlayType.list, andTitle: "Debug")
		debuggingOverlay?.tabBackgroundColor = AppConfigurationManager.debuggingTabBackgroundColor
		debuggingOverlay?.tabTitleColor = AppConfigurationManager.debuggingTabTitleColor
		debuggingOverlay?.contentBackgroundColor = AppConfigurationManager.debuggingTabContentBackgroundColor
		debuggingOverlay?.delegate = self
		debuggingOverlay?.show()

		if let loggingContent = debuggingOverlay?.contentView
		{
			let contentFrame = loggingContent.frame
			let buttonBufferArea = Int((contentFrame.size.width - (CGFloat(AppConfigurationManager.debuggingClearButtonWidth + AppConfigurationManager.debuggingPauseButtonWidth))) / 3)
			let clearButton = UIButton(frame: CGRect(x: buttonBufferArea, y: Int(contentFrame.size.height) - AppConfigurationManager.debuggingContentMarginHeight - AppConfigurationManager.debuggingClearButtonHeight, width: AppConfigurationManager.debuggingClearButtonWidth, height: AppConfigurationManager.debuggingClearButtonHeight))
			pauseResumeButton = UIButton(frame: CGRect(x: buttonBufferArea * 2 + AppConfigurationManager.debuggingClearButtonWidth, y: Int(contentFrame.size.height) - AppConfigurationManager.debuggingContentMarginHeight - AppConfigurationManager.debuggingPauseButtonHeight, width: AppConfigurationManager.debuggingPauseButtonWidth, height: AppConfigurationManager.debuggingPauseButtonHeight))
			logTextView = UITextView(frame: CGRect(x: 0, y: 0, width: Int(contentFrame.size.width), height: Int(contentFrame.size.height) - (AppConfigurationManager.debuggingContentMarginHeight * 2 + AppConfigurationManager.debuggingClearButtonHeight)))
			clearButton.backgroundColor = AppConfigurationManager.debuggingClearButtonBackgroundColor
			clearButton.setTitleColor(AppConfigurationManager.debuggingClearButtonTextColor, for: .normal)
			clearButton.setTitle(NSLocalizedString("Clear", comment: ""), for: .normal)
			clearButton.addTarget(self, action: #selector(MainScreenViewController.clearLogs), for: .touchUpInside)
			pauseResumeButton.backgroundColor = AppConfigurationManager.debuggingPauseButtonBackgroundColor
			pauseResumeButton.setTitleColor(AppConfigurationManager.debuggingPauseButtonTextColor, for: .normal)
			pauseResumeButton.setTitle(NSLocalizedString("Pause", comment: ""), for: .normal)
			pauseResumeButton.addTarget(self, action: #selector(MainScreenViewController.pauseResumeLogs), for: .touchUpInside)
			logTextView?.backgroundColor = AppConfigurationManager.debuggingTabContentBackgroundColor
			logTextView?.textColor = AppConfigurationManager.debuggingLogTextColor
			logTextView?.layoutManager.allowsNonContiguousLayout = false
			loggingContent.addSubview(clearButton)
			loggingContent.addSubview(pauseResumeButton)
			loggingContent.addSubview(logTextView!)
		}
	}

	private func configureStatusDisplay(distance: Double?)
	{
        updateInteractionLabels()
		DispatchQueue.main.async
		{
			guard let dist = distance
				else
				{
					let attributedStatusString = NSMutableAttributedString.init(string: "SAFE")
                    attributedStatusString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(named: "Safe Color")!, range: NSRange.init(location: 0, length: attributedStatusString.length))
					self.statusLabel.attributedText = attributedStatusString
					self.statusDetailLabel.text = "No people detected nearby"
					self.elapsedTimeLabel.isHidden = true
					self.distanceLabel.isHidden = true
					self.statusImageView.image = UIImage(named: "SafeIcon")
					return
				}
//			if dist <= AppConfigurationManager.contactMinDistanceDangerZone
			if dist <= AppConfigurationManager.contactMinDistanceDangerZoneInFeet
			{
				let attributedStatusString = NSMutableAttributedString.init(string: "TOO CLOSE")
                attributedStatusString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(named: "Too Close Color")!, range: NSRange.init(location: 0, length: attributedStatusString.length))
				self.statusLabel.attributedText = attributedStatusString
				self.statusDetailLabel.text = "People detected in your space"
				self.elapsedTimeLabel.isHidden = false
				self.distanceLabel.isHidden = false
				self.statusImageView.image = UIImage(named: "TooClose")
				self.currentStatusTooClose = true
				if let start = self.interactionStart
				{
					let timeElapsed = Date().timeIntervalSince(start)
					let hours = Int(timeElapsed / 3600)
					let minutes = Int((Int(timeElapsed) - (hours * 3600)) / 60)
					let seconds = Int(Int(timeElapsed) - (hours * 3600 + minutes * 60))
					self.elapsedTimeLabel.text = String(format:"Elapsed Interaction Time: %02d:%02d:%02d", hours, minutes, seconds)
					self.distanceLabel.text = String(format:"Debug current distance: %f", dist)
				}
			}
			// Because of how flaky distance reporting is, once we determine contact is too close, expand range
			// they have to leave before we consider them not too close anymore
//			else if self.currentStatusTooClose && dist < AppConfigurationManager.contactMinDistanceExitDangerZone
			else if self.currentStatusTooClose && dist < AppConfigurationManager.contactMinDistanceExitDangerZoneInFeet
			{
				return
			}
//			else if AppConfigurationManager.supportWarningZone && dist <= AppConfigurationManager.contactMinDistanceWarningZone
			else if AppConfigurationManager.supportWarningZone && dist <= AppConfigurationManager.contactMinDistanceWarningZoneInFeet
			{
				let attributedStatusString = NSMutableAttributedString.init(string: "GETTING CLOSE")
                attributedStatusString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(named: "Button Color")!, range: NSRange.init(location: 0, length: attributedStatusString.length))
				self.statusLabel.attributedText = attributedStatusString
				self.statusDetailLabel.text = "People detected nearby"
				self.elapsedTimeLabel.isHidden = true
				self.distanceLabel.isHidden = true
				self.statusImageView.image = UIImage(named: "GettingCloseIcon")
			}
			else
			{
				let attributedStatusString = NSMutableAttributedString.init(string: "SAFE")
				attributedStatusString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.green, range: NSRange.init(location: 0, length: attributedStatusString.length))
				self.statusLabel.attributedText = attributedStatusString
				self.statusDetailLabel.text = "No people detected nearby"
				self.elapsedTimeLabel.isHidden = true
				self.distanceLabel.isHidden = true
				self.statusImageView.image = UIImage(named: "SafeIcon")
				self.currentStatusTooClose = false
			}
		}
	}

	func overlayViewDisplayed(_ title: String!)
	{
		if title == "Debug"
		{
			logUpdateTimer = Timer.scheduledTimer(withTimeInterval: AppConfigurationManager.debuggingLogDisplayUpdateDelay, repeats: true)
			{
				timer in
				let logManager = LogManager.sharedManager
				let logEntries = logManager.getLogEntries()
				let differential = logEntries.count - self.lastLogEntryArray.count
				if differential > 0
				{
					for index in self.lastLogEntryArray.count..<logEntries.count
					{
						let nextEntry = logEntries[index]
						self.lastLogEntryArray.append(nextEntry)
						self.logString.append(nextEntry.logMessage + "\n\n")
					}
					DispatchQueue.main.async
					{
						self.logTextView?.text = self.logString
						let stringLength:Int = self.logTextView!.text.count
						self.logTextView?.scrollRangeToVisible(NSMakeRange(stringLength-1, 0))
					}
				}
			}
		}
	}

	func overlayViewContracted(_ title: String!)
	{
		if let logTimer = logUpdateTimer
		{
			logTimer.invalidate()
			logUpdateTimer = nil
		}
	}

	@objc func clearLogs()
	{
		LogManager.sharedManager.clearLogs()
		self.lastLogEntryArray.removeAll()
		DispatchQueue.main.async
		{
			self.logTextView?.text = ""
		}
	}

	@objc func pauseResumeLogs()
	{

		if let timer = logUpdateTimer
		{
			timer.invalidate()
			logUpdateTimer = nil
			DispatchQueue.main.async
			{
				self.pauseResumeButton.setTitle(NSLocalizedString("Resume", comment: ""), for: .normal)
			}
		}
		else
		{
			logUpdateTimer = Timer.scheduledTimer(withTimeInterval: AppConfigurationManager.debuggingLogDisplayUpdateDelay, repeats: true)
			{
				timer in
				let logManager = LogManager.sharedManager
				let logEntries = logManager.getLogEntries()
				let differential = logEntries.count - self.lastLogEntryArray.count
				if differential > 0
				{
					for index in self.lastLogEntryArray.count..<logEntries.count
					{
						let nextEntry = logEntries[index]
						self.lastLogEntryArray.append(nextEntry)
						self.logString.append(nextEntry.logMessage + "\n\n")
					}
					DispatchQueue.main.async
					{
						self.logTextView?.text = self.logString
						let stringLength:Int = self.logTextView!.text.count
						self.logTextView?.scrollRangeToVisible(NSMakeRange(stringLength-1, 0))
					}
				}
			}
			DispatchQueue.main.async
			{
				self.pauseResumeButton.setTitle(NSLocalizedString("Pause", comment: ""), for: .normal)
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

	func contactInRange(estimatedDistance: Double)
	{
		if interactionStart == nil
		{
			interactionStart = Date()
		}
		configureStatusDisplay(distance: estimatedDistance)
	}

	func contactsLeftRange()
	{
		interactionStart = nil
		configureStatusDisplay(distance: nil)
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
