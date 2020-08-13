/*******************************************************************************
* FMConfigurationManager.swift
*
* Author:			Eric Crichlow
*/

import Foundation

public class FMConfigurationManager
{
	// Persistence Manager
	static let persistenceFolderPath = "/Documents/FMPersistence"
	static let persistencElementValue = "Value"
	static let persistencElementType = "Type"
	static let persistencElementSource = "Source"
	static let persistencElementProtection = "Protection"
	static let persistencElementLifespan = "Lifespan"
	static let persistencElementExpiration = "Expiration"
	static let persistenceManagementExpiringItems = "ExpiringItems"
	static let persistenceManagementSessionItems = "SessionItems"
	static let persistenceExpirationItemName = "ExpiringItemName"
	static let persistenceExpirationItemSource = "ExpiringItemSource"
	static let persistenceExpirationItemExpirationDate = "ExpiringItemExpirationDate"
	static let timerPeriodPersistenceExpirationCheck = 60.0
}
