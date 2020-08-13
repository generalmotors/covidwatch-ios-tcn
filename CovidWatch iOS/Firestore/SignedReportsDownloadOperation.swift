//
//  Created by Zsombor Szabo on 05/04/2020.
//

import Foundation
import Firebase
import CoreData

class SignedReportsDownloadOperation: Operation {
    
    private let sinceDate: Date
    
    public var querySnapshot: QuerySnapshot?
    public var error: Error?

    private var db: Firestore = AppDelegate.getFirestore()
    
    init(sinceDate: Date) {
        self.sinceDate = sinceDate
        super.init()
    }
    
    override func main() {
        
        let semaphore = DispatchSemaphore(value: 0)
        ProfileMapping.shared.downloadProfiles()
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "Downloading signed reports..."))
        self.db.collection(Firestore.Collections.signedReports)
            .whereField(Firestore.Fields.timestamp, isGreaterThan: Timestamp(date: self.sinceDate))
            // .whereField(Firestore.Fields.isAuthenticatedByHealthOrganization, isEqualTo: true)
            .getDocuments { [weak self] (querySnapshot, error) in
                defer {
                    semaphore.signal()
                }
                guard let self = self else { return }
                if let error = error {
                    self.error = error
                    LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Downloading signed reports failed: \(error)"))
                    return
                }
                guard let querySnapshot = querySnapshot else { return }
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "Downloaded \(querySnapshot.count) signed report(s)"))
                self.querySnapshot = querySnapshot
        }
        if semaphore.wait(timeout: .now() + 20) == .timedOut {
            self.error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        }
    }
    
}
