/*******************************************************************************
* LogManager.swift
* Author:            Eric Crichlow
*/
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
	public static let preCheckDefaultURL = "http://your-domian.com/precheck"
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
    public static let contactMinDistanceDangerZoneInFeet = 7.0 as Double
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
	static let persistenceFieldDiscoveredBeacons = "discoveredBeacons"
	public static let sharedManager = AppConfigurationManager()
}

