/*******************************************************************************
* LogManager.swift
* Author:            Eric Crichlow
* Version:            1.0
********************************************************************************
*    04/14/19        *    EGC    *    File creation date
*******************************************************************************/
import Foundation

public class AppConfigurationManager
{

	public enum Environment
	{
		case Development
		case QA
		case UAT
		case Production
	}

	/* Application */
	public static let interactionsDisplayFullOffset = 20 as CGFloat
	public static let interactionsDisplayPartialOffset = 345 as CGFloat
	public static let interactionsAnimationRunTime = 1.0 as TimeInterval
	public static let defaultEnvironment = Environment.QA
	public static let persistenceFieldInteractions = "reportedInteractions"
	public static let minTimeBetweenLocalNotifications = 180 as TimeInterval
	private var currentEnvironment = defaultEnvironment

	/* Settings */
	public static let persistenceItemCurrentEnvironment = "persistenceItemCurrentEnvironment"

	/* Overlays */
	public static let debuggingTabTitleColor = UIColor.white
	public static let debuggingTabBackgroundColor = UIColor.blue
	public static let debuggingTabContentBackgroundColor = UIColor.blue
	public static let debuggingContentMarginHeight = 48
	public static let debuggingClearButtonWidth = 160
	public static let debuggingClearButtonHeight = 40
	public static let debuggingPauseButtonWidth = 160
	public static let debuggingPauseButtonHeight = 40
	public static let debuggingClearButtonBackgroundColor = UIColor.lightGray
	public static let debuggingClearButtonTextColor = UIColor.black
	public static let debuggingPauseButtonBackgroundColor = UIColor.lightGray
	public static let debuggingPauseButtonTextColor = UIColor.black
	public static let debuggingLogTextColor = UIColor.white
	public static let debuggingLogBackgroundColor = UIColor.clear
	public static let debuggingLogDisplayUpdateDelay = 0.3 as TimeInterval

	/* Contact Management */
	public static let contactFieldDistance = "distance"
	public static let contactFieldStartTime = "startTime"
	public static let contactFieldEndTime = "endTime"
	public static let contactFieldSampleTime = "sampleTime"
	public static let contactFieldSampleDistance = "sampleDistance"
	public static let contactFieldTotalSamples = "totalSamples"
	public static let contactFieldTotalDistance = "totalDistance"
	public static let contactFieldRawSampleArray = "rawSampleArray"
	public static let contactTimeTillRecord = 60.0 as TimeInterval
	public static let contactTimeTillReportGone = 28.0 as TimeInterval
	public static let contactMinDistanceDangerZone = 6.0 as Double
	public static let contactMinDistanceDangerZoneInFeet = 20.0 as Double
	public static let contactMinDistanceWarningZone = 13.0 as Double
	public static let contactMinDistanceWarningZoneInFeet = 30.0 as Double
	public static let contactMinDistanceExitDangerZone = 10.0 as Double
	public static let contactMinDistanceExitDangerZoneInFeet = 30.0 as Double
	public static let contactMinSamplesToProcess = 5
	public static let contactTimeSamplesToNormalize = 30.0 as TimeInterval
	public static let metersToFeetMultiplier = 3.28084
	public static let supportWarningZone = false
	public static let beaconScanPeriod = 5.0 as TimeInterval

	// Web Services
	private static let devBaseURLIdentifier = "DEV_BASE_URL"
	private static let qaBaseURLIdentifier = "QA_BASE_URL"
	private static let uatBaseURLIdentifier = "UAT_BASE_URL"
	private static let prodBaseURLIdentifier = "PROD_BASE_URL"
	public static let webRequestRetryDelay = 1.0
	public static let defaultWebRequestRetries = 3
	public static let devEnvironmentName = "Dev";
	public static let qaEnvironmentName = "QA";
	public static let uatEnvironmentName = "UAT";
	public static let prodEnvironmentName = "Production";
	public static let registerContactFieldUploader = "uploader"
	public static let registerContactFieldContact = "contact"
	public static let registerContactFieldDate = "date"
	public static let registerContactFieldRSSI = "rssi"
	public static let registerContactFieldPower = "power"
	public static let registerContactFieldDistance = "distance"

	// Custom Bluetooth management
	static let testServiceUUIDString = "0000FFE0-0000-1000-8000-00805F9B3ABC"
	static let testServiceAbbreviatedUUIDString = "FFE0"
	static let testCharacteristicUUIDString = "0000FFD1-0000-1000-8000-00805F9B3ABC"
	static let testCharacteristicAbbreviatedUUIDString = "FFD1"
	static let testBeaconUUIDString = "426c7565-4368-6172-6d42-6561636f6ABC"
	static let testBeaconAbbreviatedUUIDString = "7565"
	static let testBeaconIdentifier = "SafetyBeaconIdentifier"
	static let persistenceFieldDiscoveredBeacons = "discoveredBeacons"

	public static let sharedManager = AppConfigurationManager()

	static let lwBeaconUUIDString = "f2a52d43-e0ab-489c-b64c-4a8300146ABC"
    static let lwBeaconAbbreviatedUUIDString = "2d43"
    static let lwBeaconIdentifier = "SafetyBeaconIdentifier"

    static let hidBeaconUUIDString = "0000c019-0000-1000-8000-00805f9b3ABC"
    static let hidBeaconAbbreviatedUUIDString = "c019"
    static let hidBeaconIdentifier = "SafetyBeaconIdentifier"


	init()
	{
		// Restore the current environment
		if FMPersistenceManager.sharedManager.checkForValue(name: AppConfigurationManager.persistenceItemCurrentEnvironment, from: .UserDefaults)
		{
			let readResponse = FMPersistenceManager.sharedManager.readValue(name: AppConfigurationManager.persistenceItemCurrentEnvironment, from: .UserDefaults)
			let readResult = readResponse.result
			if readResult == .Success
			{
				let environment = readResponse.value as! String
				if environment == AppConfigurationManager.devEnvironmentName
				{
					currentEnvironment = .Development
				}
				else if environment == AppConfigurationManager.qaEnvironmentName
				{
					currentEnvironment = .QA
				}
				else if environment == AppConfigurationManager.uatEnvironmentName
				{
					currentEnvironment = .UAT
				}
				else if environment == AppConfigurationManager.prodEnvironmentName
				{
					currentEnvironment = .Production
				}
			}
		}
		else	// Establish the default environment
		{
			if currentEnvironment == .Development
			{
				FMPersistenceManager.sharedManager.saveValue(name: AppConfigurationManager.persistenceItemCurrentEnvironment, value: AppConfigurationManager.devEnvironmentName, type: .String, destination: .UserDefaults, protection: .Unsecured, lifespan: .Immortal, expiration: nil, overwrite: true)
			}
			else if currentEnvironment == .QA
			{
				FMPersistenceManager.sharedManager.saveValue(name: AppConfigurationManager.persistenceItemCurrentEnvironment, value: AppConfigurationManager.qaEnvironmentName, type: .String, destination: .UserDefaults, protection: .Unsecured, lifespan: .Immortal, expiration: nil, overwrite: true)
			}
			else if currentEnvironment == .UAT
			{
				FMPersistenceManager.sharedManager.saveValue(name: AppConfigurationManager.persistenceItemCurrentEnvironment, value: AppConfigurationManager.uatEnvironmentName, type: .String, destination: .UserDefaults, protection: .Unsecured, lifespan: .Immortal, expiration: nil, overwrite: true)
			}
			else if currentEnvironment == .Production
			{
				FMPersistenceManager.sharedManager.saveValue(name: AppConfigurationManager.persistenceItemCurrentEnvironment, value: AppConfigurationManager.prodEnvironmentName, type: .String, destination: .UserDefaults, protection: .Unsecured, lifespan: .Immortal, expiration: nil, overwrite: true)
			}
		}
		switch currentEnvironment
		{
			case .Development:
				FMConfigurationManager.sharedManager.setAPIURL(address: Bundle.main.infoDictionary![AppConfigurationManager.devBaseURLIdentifier] as! String)
			case .QA:
				FMConfigurationManager.sharedManager.setAPIURL(address: Bundle.main.infoDictionary![AppConfigurationManager.qaBaseURLIdentifier] as! String)
			case .UAT:
				FMConfigurationManager.sharedManager.setAPIURL(address: Bundle.main.infoDictionary![AppConfigurationManager.uatBaseURLIdentifier] as! String)
			case .Production:
				FMConfigurationManager.sharedManager.setAPIURL(address: Bundle.main.infoDictionary![AppConfigurationManager.prodBaseURLIdentifier] as! String)
		}
	}

	// MARK: Business Logic

	func setEnvironment(environment: Environment)
	{
		currentEnvironment = environment
		switch currentEnvironment
		{
			case .Development:
				FMConfigurationManager.sharedManager.setAPIURL(address: Bundle.main.infoDictionary![AppConfigurationManager.devBaseURLIdentifier] as! String)
				FMPersistenceManager.sharedManager.saveValue(name: AppConfigurationManager.persistenceItemCurrentEnvironment, value: AppConfigurationManager.devEnvironmentName, type: .String, destination: .UserDefaults, protection: .Unsecured, lifespan: .Immortal, expiration: nil, overwrite: true)
			case .QA:
				FMConfigurationManager.sharedManager.setAPIURL(address: Bundle.main.infoDictionary![AppConfigurationManager.qaBaseURLIdentifier] as! String)
				FMPersistenceManager.sharedManager.saveValue(name: AppConfigurationManager.persistenceItemCurrentEnvironment, value: AppConfigurationManager.qaEnvironmentName, type: .String, destination: .UserDefaults, protection: .Unsecured, lifespan: .Immortal, expiration: nil, overwrite: true)
			case .UAT:
				FMConfigurationManager.sharedManager.setAPIURL(address: Bundle.main.infoDictionary![AppConfigurationManager.uatBaseURLIdentifier] as! String)
				FMPersistenceManager.sharedManager.saveValue(name: AppConfigurationManager.persistenceItemCurrentEnvironment, value: AppConfigurationManager.uatEnvironmentName, type: .String, destination: .UserDefaults, protection: .Unsecured, lifespan: .Immortal, expiration: nil, overwrite: true)
			case .Production:
				FMConfigurationManager.sharedManager.setAPIURL(address: Bundle.main.infoDictionary![AppConfigurationManager.prodBaseURLIdentifier] as! String)
				FMPersistenceManager.sharedManager.saveValue(name: AppConfigurationManager.persistenceItemCurrentEnvironment, value: AppConfigurationManager.prodEnvironmentName, type: .String, destination: .UserDefaults, protection: .Unsecured, lifespan: .Immortal, expiration: nil, overwrite: true)
		}
	}

	func getCurrentEnvironment() -> Environment
	{
		return currentEnvironment
	}

	func getCurrentEnvironmentName() -> String
	{
		switch currentEnvironment
		{
			case .Development:
				return AppConfigurationManager.devEnvironmentName
			case .QA:
				return AppConfigurationManager.qaEnvironmentName
			case .UAT:
				return AppConfigurationManager.uatEnvironmentName
			case .Production:
				return AppConfigurationManager.prodEnvironmentName
		}
	}

	func getCurrentEnvironmentURLString() -> String
	{
		switch currentEnvironment
		{
			case .Development:
				return "https://" + (Bundle.main.infoDictionary![AppConfigurationManager.devBaseURLIdentifier] as! String)
			case .QA:
				return "https://" + (Bundle.main.infoDictionary![AppConfigurationManager.qaBaseURLIdentifier] as! String)
			case .UAT:
				return "https://" + (Bundle.main.infoDictionary![AppConfigurationManager.uatBaseURLIdentifier] as! String)
			case .Production:
				return "https://" + (Bundle.main.infoDictionary![AppConfigurationManager.prodBaseURLIdentifier] as! String)
		}
	}

	func getCurrentEnvironmentURL() -> URL?
	{
		switch currentEnvironment
		{
			case .Development:
				return URL(string: "https://" + (Bundle.main.infoDictionary![AppConfigurationManager.devBaseURLIdentifier] as! String))
			case .QA:
				return URL(string: "https://" + (Bundle.main.infoDictionary![AppConfigurationManager.qaBaseURLIdentifier] as! String))
			case .UAT:
				return URL(string: "https://" + (Bundle.main.infoDictionary![AppConfigurationManager.uatBaseURLIdentifier] as! String))
			case .Production:
				return URL(string: "https://" + (Bundle.main.infoDictionary![AppConfigurationManager.prodBaseURLIdentifier] as! String))
		}
	}
}

