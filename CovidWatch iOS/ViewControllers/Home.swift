//
//  share.swift
//  CovidWatch iOS
//
//  Created by Laima Cernius-Ink on 4/8/20.
//  
//

import UIKit

class Home: UIViewController, OverlayViewCallbackDelegate {
    @IBOutlet weak var header: UIView!
    var img = UIImageView(image: UIImage(named: "family"))
    var largeText: LargeText!
    var mainText: MainText!
    var spreadButton: Button!
    var testedButton: Button!
    var infoBanner: InfoBanner!
    var menu: Menu!
    var testLastSubmittedDateObserver: NSKeyValueObservation?
    var mostRecentExposureDateObserver: NSKeyValueObservation?
    var isUserSickObserver: NSKeyValueObservation?
    var observer: NSObjectProtocol?
    var bluetoothPermission: BluetoothPermission?
    let globalState = UserDefaults.shared

	// Overlays
	var debuggingOverlay: ViewOverlay?
	var logTextView: UITextView?
	var logUpdateTimer: Timer?
	var lastLogEntryArray = [LogEntry]()
	var logString = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        self.spreadButton = Button(self, text: "Share the app", subtext: "It works best when everyone uses it.")
        self.testedButton = Button(self, text: "Tested for COVID-19?",
                                   subtext: "Share your result anonymously to help keep your community stay safe.")
        self.infoBanner = InfoBanner(self, text: "You may have been in contact with COVID-19", onClick: {
            self.performSegue(withIdentifier: "test", sender: self)
        })
        //swiftlint:disable:next line_length
        self.mainText = MainText(self, text: "Thank you for helping protect your communities. You will be notified of potential contact with COVID-19.")
        self.largeText = LargeText(self, text: "You're all set!")
        self.menu = Menu(self)
        
        testLastSubmittedDateObserver = globalState.observe(
            \.testLastSubmittedDate,
            options: [],
            changeHandler: { (_, _) in
                self.drawScreen()
        })
        
        mostRecentExposureDateObserver = globalState.observe(
            \.mostRecentExposureDate,
            options: [],
            changeHandler: { (_, _) in
                self.drawScreen()
        })
        
        isUserSickObserver = globalState.observe(
            \.isUserSick,
            options: [],
            changeHandler: { (_, _) in
                self.drawScreen()
        })
        
        self.observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: OperationQueue.main
        ) { [weak self] _ in
            self?.checkNotificationPersmission()
        }
        self.checkNotificationPersmission()

		setupOverlays()
		LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "App set up and running"))
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let header = segue.destination as? HeaderViewController {
            header.delegate = self
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        drawScreen()
    }
    
    @objc func goToTest() {
        self.performSegue(withIdentifier: "test", sender: self)
    }
    
    // bluetooth and notification permissions
    enum AuthorizedPermissions {
        case bluetooth
        case notifications
    }
    
    func checkNotificationPersmission(_ requiredPermissions: [AuthorizedPermissions] = []) {
        var morePermissions = requiredPermissions
        _ = NotificationPermission { [weak self] (result) in
            switch result {
            case .success:
                self?.checkBluetoothPermission(morePermissions)
            case .failure(let error):
                morePermissions.append(.notifications)
                self?.checkBluetoothPermission(morePermissions)
                print("Please go insto settings and enable Notifications", error)
            }
        }
    }
    
    func checkBluetoothPermission(_ requiredPermissions: [AuthorizedPermissions] = []) {
        self.bluetoothPermission = BluetoothPermission { [weak self] (result) in
            var morePermissions = requiredPermissions
            switch result {
            case .success:
                // nothing to do
                print("Bluetooth is still enabled")
                self?.showPermissionsAlert(morePermissions)
            case .failure:
                morePermissions.append(.bluetooth)
                self?.showPermissionsAlert(morePermissions)
            }
        }
    }
    
    func showPermissionsAlert(_ requiredPermissions: [AuthorizedPermissions] = []) {
        if requiredPermissions.count > 0 {
            var permissionTitle = "Permission Required"
            var permissionText = "Bluetooth and Notifications"
            if requiredPermissions.count == 1 {
                for permission in requiredPermissions {
                    switch permission {
                    case .bluetooth:
                        permissionTitle = "Bluetooth Required"
                        permissionText = "Bluetooth"
                    case .notifications:
                        permissionTitle = "Notifications Required"
                        permissionText = "Notifications"
                    }
                }
            }
            
            let permissionsAlert = UIAlertController(
                title: NSLocalizedString(permissionTitle, comment: ""),
                message: "Please turn on \(permissionText) in Settings", preferredStyle: .alert
            )
            permissionsAlert.addAction(
                UIAlertAction(
                    title: NSLocalizedString("Open Settings", comment: ""),
                    style: .default,
                    handler: { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                }
                )
            )
            self.present(permissionsAlert, animated: true)
        }
    }
    
    @objc func share() {
        // text to share
        let text = "Become a Covid Watcher and help your community stay safe."
        let url = NSURL(string: "https://www.covid-watch.org")
        
        // set up activity view controller
        let itemsToShare: [Any] = [ text, url as Any ]
        let activityViewController = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        
        // so that iPads won't crash
        activityViewController.popoverPresentationController?.sourceView = self.view
        
        // present the view controller
        self.present(activityViewController, animated: true, completion: nil)
    }
    // swiftlint:disable:next function_body_length
    private func drawScreen() {
        //        optionally draw the info banner and determine the coordinate for the top of the image
        var imgTop: CGFloat = 0
        if globalState.isUserAtRiskForCovid || globalState.isUserSick {
            infoBanner.isHidden = false
            if globalState.isUserSick {
                infoBanner.isInteractive = false
                infoBanner.text.text = "You reported that you tested positive for COVID-19"
            } else {
                infoBanner.isInteractive = true
                infoBanner.text.text = "You may have been in contact with COVID-19"
            }
            infoBanner.draw(centerX: view.center.x, originY: header.frame.maxY)
            imgTop = infoBanner.frame.maxY + 21.0 * figmaToiOSVerticalScalingFactor
        } else {
            infoBanner.isHidden = true
            imgTop = header.frame.maxY
        }
        //        determine image size
        img.frame.size.height = 280.0 * figmaToiOSVerticalScalingFactor
        img.frame.size.width = (1350.0/1175.0) * img.frame.size.height
        if screenHeight <= 667 {
            img.frame.size.width /= 1.2
            img.frame.size.height /= 1.2
        }
        img.center.x = view.center.x - 5 * figmaToiOSHorizontalScalingFactor
        img.frame.origin.y = imgTop
        self.view.addSubview(img)
        
        let largeTextTop = img.frame.maxY + (10.0 * figmaToiOSVerticalScalingFactor)
        var mainTextTop: CGFloat
        if globalState.isFirstTimeUser {
            largeText.isHidden = false
            largeText.text = "You're all set!"
            largeText.draw(centerX: view.center.x,
                            originY: largeTextTop)
            mainTextTop = largeText.frame.maxY
        } else if !globalState.isUserAtRiskForCovid && !globalState.isUserSick {
            largeText.isHidden = false
            largeText.text = "Welcome Back!"
            largeText.draw(centerX: view.center.x,
                            originY: largeTextTop)
            mainTextTop = largeText.frame.maxY
        } else {
            //            userState.hasBeenInContact
            largeText.isHidden = true
            mainTextTop = img.frame.maxY
        }
        
        //        draw mainText with respect to largeText or img or not at all
        if globalState.isFirstTimeUser {
            // swiftlint:disable:next line_length
            mainText.text = "Thank you for helping protect your communities. You will be notified of potential contact with COVID-19."
            mainText.draw(centerX: view.center.x, originY: mainTextTop)
        } else if !globalState.isUserAtRiskForCovid && !globalState.isUserSick {
            // swiftlint:disable:next line_length
            mainText.text = "Covid Watch has not detected exposure to COVID-19. Share the app with family and friends to help your community stay safe."
            mainText.draw(centerX: view.center.x, originY: mainTextTop)
        } else {
            mainText.text = "Thank you for helping your community stay safe, anonymously."
            mainText.draw(centerX: view.center.x, originY: mainTextTop)
        }

        //            Clunky, but easier than messing with button internals
        spreadButton.text.removeFromSuperview()
        spreadButton.subtext?.removeFromSuperview()
        spreadButton.removeFromSuperview()
        spreadButton = Button(self, text: "Share the app", subtext: "It works best when everyone uses it.")
        //        spreadButton drawn below because its position depends on whether testedButton is drawn
        spreadButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.share)))
        
        if globalState.isEligibleToSubmitTest {
            self.testedButton.addGestureRecognizer(
                UITapGestureRecognizer(
                    target: self, action: #selector(self.goToTest)
                )
            )
            let testedButtonTop: CGFloat = 668.0 * figmaToiOSVerticalScalingFactor
            testedButton.draw(centerX: view.center.x, originY: testedButtonTop)
            spreadButton.drawBetween(top: mainText.frame.maxY,
                                      bottom: testedButtonTop,
                                      centerX: view.center.x)
            testedButton.isHidden = false
            testedButton.text.isHidden = false
            testedButton.subtext?.isHidden = false
        } else {
            testedButton.isHidden = true
            testedButton.text.isHidden = true
            testedButton.subtext?.isHidden = true
            spreadButton.drawBetween(top: mainText.frame.maxY,
                                      bottom: screenHeight - self.view.safeAreaInsets.bottom,
                                      centerX: view.center.x)
        }
//        Draw the menu last, so it's registered as "above" all other components in the layout hierarchy
        self.menu.draw()

		if let overlayView = debuggingOverlay
		{
			self.view.bringSubviewToFront(overlayView)
		}

        globalState.isFirstTimeUser = false
        
    }
    
	// MARK: Begin New Contact Tracing Code

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
			let pauseButton = UIButton(frame: CGRect(x: buttonBufferArea * 2 + AppConfigurationManager.debuggingClearButtonWidth, y: Int(contentFrame.size.height) - AppConfigurationManager.debuggingContentMarginHeight - AppConfigurationManager.debuggingPauseButtonHeight, width: AppConfigurationManager.debuggingPauseButtonWidth, height: AppConfigurationManager.debuggingPauseButtonHeight))
			logTextView = UITextView(frame: CGRect(x: 0, y: 0, width: Int(contentFrame.size.width), height: Int(contentFrame.size.height) - (AppConfigurationManager.debuggingContentMarginHeight * 2 + AppConfigurationManager.debuggingClearButtonHeight)))
			clearButton.backgroundColor = AppConfigurationManager.debuggingClearButtonBackgroundColor
			clearButton.setTitleColor(AppConfigurationManager.debuggingClearButtonTextColor, for: .normal)
			clearButton.setTitle(NSLocalizedString("Clear", comment: ""), for: .normal)
			clearButton.addTarget(self, action: #selector(Home.clearLogs), for: .touchUpInside)
			pauseButton.backgroundColor = AppConfigurationManager.debuggingPauseButtonBackgroundColor
			pauseButton.setTitleColor(AppConfigurationManager.debuggingPauseButtonTextColor, for: .normal)
			pauseButton.setTitle(NSLocalizedString("Pause", comment: ""), for: .normal)
			pauseButton.addTarget(self, action: #selector(Home.pauseLogs), for: .touchUpInside)
			logTextView?.backgroundColor = AppConfigurationManager.debuggingTabContentBackgroundColor
			logTextView?.textColor = AppConfigurationManager.debuggingLogTextColor
			logTextView?.layoutManager.allowsNonContiguousLayout = false
			loggingContent.addSubview(clearButton)
			loggingContent.addSubview(pauseButton)
			loggingContent.addSubview(logTextView!)
		}
	}

	@objc func clearLogs()
	{
	}

	@objc func pauseLogs()
	{
	}

	// ViewOverlay Delegate methods

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

}

// MARK: - Protocol HeaderViewControllerDelegate
extension Home: HeaderViewControllerDelegate {
    func menuWasTapped() {
        self.menu.toggleMenu()
    }
}
