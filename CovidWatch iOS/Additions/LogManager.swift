/*******************************************************************************
* LogManager.swift
* Author:			Eric Crichlow
* Version:			1.0
********************************************************************************
*	04/14/19		*	EGC	*	File creation date
*******************************************************************************/

import Foundation

public struct LogEntry
{
	let eventSource: String
	let eventTime: Date
	let logMessage: String
	let logType: LogManager.LogType
    let logLevel: LogManager.LogLevel

    init(source: NSObject, type: LogManager.LogType = .info, level: LogManager.LogLevel = .debug, message: String)
	{
		eventSource = source.description
        logType = (level == .error) ? .error : type
        logLevel = level
		logMessage = message
		eventTime = Date()
	}
}

public class LogManager
{

	public static let LOG_DESTINATION_SAVE_TO_MEMORY_ONLY = 0x00
	public static let LOG_DESTINATION_CONSOLE = 0x01
	public static let LOG_DESTINATION_LOCAL_FILE = 0x02
	public static let LOG_DESTINATION_REMOTE_SERVICE = 0x03
	public static let LOG_DESTINATION_ALL = LOG_DESTINATION_CONSOLE | LOG_DESTINATION_LOCAL_FILE | LOG_DESTINATION_REMOTE_SERVICE

	public static let defaultLogDestination = LOG_DESTINATION_CONSOLE | LOG_DESTINATION_LOCAL_FILE
	public static let defaultLogOutputDetail = LogOutputDetail.verbose
    public static var defaultLogLevel = LogLevel.debug
	private static let defaultLogFilename = "appLocalLogging"
	private static let logFileMaxLength = 4000000
	private static let logFileOverflowTrimLength = 50000

	public enum LogType
	{
		case error
		case bluetooth			// For Bluetooth communications
		case info
		case transmission		// For network communications
		case reception			// For network communications
		case notification		// For local or push notifications received
		case userAction
	}

	public enum LogOutputDetail
	{
		case simple
		case verbose
	}

    public enum LogLevel: Int
	{
		case error = 0
		case warning = 1
		case info = 2
        case debug = 3
	}

	private var logEntries = [LogEntry]()

	public static let sharedManager = LogManager()

	init()
	{
	}

	public func writeLog(entry: LogEntry)
	{
		writeLog(entry:entry, destination: LogManager.defaultLogDestination, detailLevel: LogManager.defaultLogOutputDetail)
	}

	public func writeLog(entry: LogEntry, destination: Int, detailLevel: LogOutputDetail)
	{
        
        if entry.logLevel.rawValue > LogManager.defaultLogLevel.rawValue {
            return
        }

		let formattedLogEntry = formatEntry(entry, detailLevel: detailLevel)
		// Write log entry to each destination selected
		if destination & LogManager.LOG_DESTINATION_CONSOLE == LogManager.LOG_DESTINATION_CONSOLE
		{
			print(formatEntry(entry, detailLevel: detailLevel))
		}
		if destination & LogManager.LOG_DESTINATION_LOCAL_FILE == LogManager.LOG_DESTINATION_LOCAL_FILE
		{
			let homePathString = NSHomeDirectory()
			let destFilePathString = homePathString + "/" + LogManager.defaultLogFilename
			if !FileManager.default.fileExists(atPath: destFilePathString)
			{
				FileManager.default.createFile(atPath: destFilePathString, contents: formattedLogEntry.data(using: .utf8), attributes: nil)
			}
			else
			{
				let destFileURL = URL(fileURLWithPath: destFilePathString)
				do
				{
					let fileHandle = try FileHandle.init(forUpdating: destFileURL)
					fileHandle.seekToEndOfFile()
					if let data = formattedLogEntry.data(using: .utf8)
					{
						fileHandle.write(data)
						let fileAttributes = try FileManager.default.attributesOfItem(atPath: destFilePathString)
						if let fileSize = fileAttributes[FileAttributeKey.size] as? NSNumber
						{
							let maxLength = NSNumber(value: LogManager.logFileMaxLength)
							if fileSize.compare(maxLength) == .orderedDescending
							{
								fileHandle.seek(toFileOffset: UInt64(LogManager.logFileOverflowTrimLength))
								let persistedData = fileHandle.readDataToEndOfFile()
								fileHandle.seek(toFileOffset: 0)
								fileHandle.write(persistedData)
								fileHandle.truncateFile(atOffset: UInt64(persistedData.count))
							}
						}
						fileHandle.closeFile()
					}
				}
				catch
				{
				}
			}
		}
		if destination & LogManager.LOG_DESTINATION_REMOTE_SERVICE == LogManager.LOG_DESTINATION_REMOTE_SERVICE
		{
			// Remote service logging is project-specific
		}

		logEntries.append(entry)
	}

	public func clearLogs()
	{
		logEntries.removeAll()
	}

	public func getLogEntries(types: [LogType]? = nil) -> [LogEntry]
	{
		if types == nil
		{
			return logEntries
		}
		else
		{
			var filteredEntries = [LogEntry]()
			if let filteredTypes = types
			{
				for nextEntry in logEntries
				{
					if filteredTypes.contains(nextEntry.logType)
					{
						filteredEntries.append(nextEntry)
					}
				}
			}
			return filteredEntries
		}
	}

	private func formatEntry(_ entry: LogEntry, detailLevel: LogOutputDetail) -> String
	{
		if detailLevel == .simple
		{
			return entry.logMessage
		}
		else
		{
			let dateFormatter = DateFormatter()
			dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
			let formattedDate = dateFormatter.string(from: entry.eventTime)
			return "\(formattedDate) \(entry.logMessage) \(entry.eventSource)"
		}
	}
}
