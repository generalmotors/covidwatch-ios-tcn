/*******************************************************************************
* FMPersistenceManager.swift
* Author:			Eric Crichlow
*/

import Foundation

public class FMPersistenceManager
{
	public enum PersistenceSource : Int
	{
		case Memory
		case UserDefaults
	}

	public enum PersistenceProtectionLevel : Int
	{
		case Unsecured
		case Secured
	}

	public enum PersistenceLifespan : Int
	{
		case Immortal
		case Session
		case Expiration
	}

	public enum PersistenceDataType : Int
	{
		case Number
		case String
		case Array
		case Dictionary
		case Data
	}

	public enum PersistenceReadResultCode : Int
	{
		case Success
		case NotFound
		case Expired
	}

	public static let sharedManager = FMPersistenceManager()

	var memoryStore = [String: Dictionary<String, Any>]()

	init()
	{
		Timer.scheduledTimer(withTimeInterval: FMConfigurationManager.timerPeriodPersistenceExpirationCheck, repeats: true) {timer in self.checkForExpiredItems()}
	}

	@discardableResult public func saveValue(name: String, value: Any, type: PersistenceDataType, destination: PersistenceSource, protection: PersistenceProtectionLevel, lifespan: PersistenceLifespan, expiration: Date?, overwrite: Bool) -> Bool
	{
		var savedDataElement = [String: Any]()
		savedDataElement[FMConfigurationManager.persistencElementValue] = value
		savedDataElement[FMConfigurationManager.persistencElementType] = type.rawValue
		savedDataElement[FMConfigurationManager.persistencElementSource] = destination.rawValue
		savedDataElement[FMConfigurationManager.persistencElementProtection] = protection.rawValue
		savedDataElement[FMConfigurationManager.persistencElementLifespan] = lifespan.rawValue
		savedDataElement[FMConfigurationManager.persistencElementExpiration] = expiration
		if lifespan == .Expiration && expiration == nil
		{
			return false
		}
		if destination == .Memory
		{
			if memoryStore[name] == nil || overwrite
			{
				memoryStore[name] = savedDataElement
			}
			else if memoryStore[name] != nil && !overwrite
			{
				return false
			}
		}
		else if destination == .UserDefaults
		{
			if UserDefaults.standard.object(forKey: name) == nil || overwrite
			{
				UserDefaults.standard.set(savedDataElement, forKey: name)
				UserDefaults.standard.synchronize()
			}
			else if UserDefaults.standard.object(forKey: name) != nil && !overwrite
			{
				return false
			}
		}
		if lifespan == .Session
		{
			if UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementSessionItems) == nil
			{
				let sessionItemEntry = [[FMConfigurationManager.persistenceExpirationItemName: name, FMConfigurationManager.persistenceExpirationItemSource: destination.rawValue]]
				UserDefaults.standard.set(sessionItemEntry, forKey: FMConfigurationManager.persistenceManagementSessionItems)
				UserDefaults.standard.synchronize()
			}
			else
			{
				var sessionItems = UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementSessionItems) as! [[String: Any]]
				sessionItems.append([FMConfigurationManager.persistenceExpirationItemName: name, FMConfigurationManager.persistenceExpirationItemSource: destination.rawValue])
				UserDefaults.standard.set(sessionItems, forKey: FMConfigurationManager.persistenceManagementSessionItems)
				UserDefaults.standard.synchronize()
			}
		}
		else if lifespan == .Expiration
		{
			if let expirationDate = expiration
			{
				let dateFormatter = DateFormatter()
				dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
				var dirty = false
				// First, remove any expiring item already existing for the same name
				if UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) != nil
				{
					// Have to be backwards compatible with deployments that use the old expirationDate object format
					if let _ = UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) as? Dictionary<String, [String]>
					{
						UserDefaults.standard.removeObject(forKey: FMConfigurationManager.persistenceManagementExpiringItems)
					}
					var expiringItemEntries = UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) as! Dictionary<String, [[String: Any]]>
					for nextExpirationDate in expiringItemEntries.keys
					{
						if dateFormatter.date(from: nextExpirationDate) != nil
						{
							let expiringItemList = expiringItemEntries[nextExpirationDate]
							var freshItemList = expiringItemList
							var entryDirty = false
							for nextItemIndex in stride(from: expiringItemList!.count-1, through: 0, by: -1)
							{
								let nextItem = expiringItemList![nextItemIndex]
								let nextItemName = nextItem[FMConfigurationManager.persistenceExpirationItemName] as! String
								if nextItemName == name
								{
									freshItemList!.remove(at: nextItemIndex)
									entryDirty = true
									dirty = true
								}
							}
							if entryDirty
							{
								if freshItemList!.count == 0
								{
									expiringItemEntries.removeValue(forKey: nextExpirationDate)
								}
								else
								{
									expiringItemEntries[nextExpirationDate] = freshItemList!
								}
							}
						}
					}
					if dirty
					{
						if expiringItemEntries.count == 0
						{
							UserDefaults.standard.removeObject(forKey: FMConfigurationManager.persistenceManagementExpiringItems)
						}
						else
						{
							UserDefaults.standard.set(expiringItemEntries, forKey: FMConfigurationManager.persistenceManagementExpiringItems)
						}
						UserDefaults.standard.synchronize()
					}
				}
				// Then, add the new expiring item
				let dateString = dateFormatter.string(from: expirationDate)
				if UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) == nil
				{
					let expiringItemEntries = [dateString: [[FMConfigurationManager.persistenceExpirationItemName: name, FMConfigurationManager.persistenceExpirationItemSource: destination.rawValue]]]
					UserDefaults.standard.set(expiringItemEntries, forKey: FMConfigurationManager.persistenceManagementExpiringItems)
					UserDefaults.standard.synchronize()
				}
				else
				{
					// Have to be backwards compatible with deployments that use the old expirationDate object format
					if let _ = UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) as? Dictionary<String, [String]>
					{
						UserDefaults.standard.removeObject(forKey: FMConfigurationManager.persistenceManagementExpiringItems)
					}
					var expiringItemEntries = UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) as! Dictionary<String, [[String: Any]]>
					if var dateExpiringItemList = expiringItemEntries[dateString]
					{
						dateExpiringItemList.append([FMConfigurationManager.persistenceExpirationItemName: name, FMConfigurationManager.persistenceExpirationItemSource: destination.rawValue])
						expiringItemEntries[dateString] = dateExpiringItemList
					}
					else
					{
						expiringItemEntries[dateString] = [[FMConfigurationManager.persistenceExpirationItemName: name, FMConfigurationManager.persistenceExpirationItemSource: destination.rawValue]]
					}
					UserDefaults.standard.set(expiringItemEntries, forKey: FMConfigurationManager.persistenceManagementExpiringItems)
					UserDefaults.standard.synchronize()
				}
			}
			else
			{
				return false
			}
		}
		return true
	}

	public func readValue(name: String, from: PersistenceSource) -> (result: PersistenceReadResultCode, value: Any?)
	{
		if from == .Memory
		{
			if memoryStore[name] == nil
			{
				return (result: .NotFound, value: nil)
			}
			else
			{
                let savedDataElement = memoryStore[name] ?? [String: Any]()
				let value = savedDataElement[FMConfigurationManager.persistencElementValue]
				return (result: .Success, value: value)
			}
		}
		else if from == .UserDefaults
		{
			if UserDefaults.standard.object(forKey: name) == nil
			{
				return (result: .NotFound, value: nil)
			}
			else
			{
				let savedDataElement = UserDefaults.standard.object(forKey: name) as! Dictionary<String, Any>
				let value = savedDataElement[FMConfigurationManager.persistencElementValue]
				return (result: .Success, value: value)
			}
		}
		return (result: .NotFound, value: nil)
	}

	public func checkForValue(name: String, from: PersistenceSource) -> Bool
	{
		if from == .Memory
		{
			if memoryStore[name] == nil
			{
				return false
			}
			else
			{
				return true
			}
		}
		else if from == .UserDefaults
		{
			if UserDefaults.standard.object(forKey: name) == nil
			{
				return false
			}
			else
			{
				return true
			}
		}
		return false
	}

	@discardableResult public func clearValue(name: String, from: PersistenceSource) -> Bool
	{
		if checkForValue(name: name, from: from)
		{
			if from == .Memory
			{
				memoryStore[name] = nil
				return true
			}
			else if from == .UserDefaults
			{
				UserDefaults.standard.removeObject(forKey: name)
				UserDefaults.standard.synchronize()
				return true
			}
			// Then clear any expiring values for the same name
			let dateFormatter = DateFormatter()
			dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
			var dirty = false
			if UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) != nil
			{
				// Have to be backwards compatible with deployments that use the old expirationDate object format
				if let _ = UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) as? Dictionary<String, [String]>
				{
					UserDefaults.standard.removeObject(forKey: FMConfigurationManager.persistenceManagementExpiringItems)
				}
				var expiringItemEntries = UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) as! Dictionary<String, [[String: Any]]>
				for nextExpirationDate in expiringItemEntries.keys
				{
					let expiringItemList = expiringItemEntries[nextExpirationDate]
					var freshItemList = expiringItemList
					var entryDirty = false
					for nextItemIndex in stride(from: expiringItemList!.count-1, through: 0, by: -1)
					{
						let nextItem = expiringItemList![nextItemIndex]
						let nextItemName = nextItem[FMConfigurationManager.persistenceExpirationItemName] as! String
						if nextItemName == name
						{
							freshItemList!.remove(at: nextItemIndex)
							entryDirty = true
							dirty = true
						}
					}
					if entryDirty
					{
						if freshItemList!.count == 0
						{
							expiringItemEntries.removeValue(forKey: nextExpirationDate)
						}
						else
						{
							expiringItemEntries[nextExpirationDate] = freshItemList!
						}
					}
				}
				if dirty
				{
					if expiringItemEntries.count == 0
					{
						UserDefaults.standard.removeObject(forKey: FMConfigurationManager.persistenceManagementExpiringItems)
					}
					else
					{
						UserDefaults.standard.set(expiringItemEntries, forKey: FMConfigurationManager.persistenceManagementExpiringItems)
					}
					UserDefaults.standard.synchronize()
				}
			}
		}
		return false
	}

	public func checkForExpiredItems()
	{
		if UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) != nil
		{
			// Have to be backwards compatible with deployments that use the old expirationDate object format
			if let _ = UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) as? Dictionary<String, [String]>
			{
				UserDefaults.standard.removeObject(forKey: FMConfigurationManager.persistenceManagementExpiringItems)
			}
			let expiringItemEntries = UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementExpiringItems) as! Dictionary<String, [[String: Any]]>
			var freshItemEntries = expiringItemEntries
			let dateFormatter = DateFormatter()
			dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
			for nextExpirationDateString in expiringItemEntries.keys
			{
				let nextExpirationDate = dateFormatter.date(from: nextExpirationDateString)
				if let expirationDate = nextExpirationDate
				{
					if expirationDate.timeIntervalSinceNow < 0
					{
						let expiringItemList = expiringItemEntries[nextExpirationDateString]
						for nextItem in expiringItemList!
						{
							let source = PersistenceSource(rawValue: nextItem[FMConfigurationManager.persistenceExpirationItemSource] as! Int)
							let name = nextItem[FMConfigurationManager.persistenceExpirationItemName] as! String
							if let src = source
							{
								clearValue(name: name, from: src)
							}
						}
						freshItemEntries.removeValue(forKey: nextExpirationDateString)
					}
				}
			}
			UserDefaults.standard.set(freshItemEntries, forKey: FMConfigurationManager.persistenceManagementExpiringItems)
			UserDefaults.standard.synchronize()
		}
	}

	public func removeSessionItems()
	{
		if UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementSessionItems) != nil
		{
			let sessionItemEntries = UserDefaults.standard.object(forKey: FMConfigurationManager.persistenceManagementSessionItems) as! [[String: Any]]
			for nextSessionItem in sessionItemEntries
			{
				let source = PersistenceSource(rawValue: nextSessionItem[FMConfigurationManager.persistenceExpirationItemSource] as! Int)
				let name = nextSessionItem[FMConfigurationManager.persistenceExpirationItemName] as! String
				if let src = source
				{
					clearValue(name: name, from: src)
				}
			}
		}
		UserDefaults.standard.removeObject(forKey: FMConfigurationManager.persistenceManagementSessionItems)
		UserDefaults.standard.synchronize()
	}
}
