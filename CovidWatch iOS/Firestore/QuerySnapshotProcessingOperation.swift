//
//  Created by Zsombor Szabo on 30/03/2020.
//

import Foundation
import Firebase
import CoreData

// swiftlint:disable:next todo
// TODO: split this operation into an add to core data and a process signed reports operation
class QuerySnapshotProcessingOperation: Operation {
    var querySnapshot: QuerySnapshot?
    private let context: NSManagedObjectContext
    private let mergingContexts: [NSManagedObjectContext]?
    
    init(context: NSManagedObjectContext, mergingContexts: [NSManagedObjectContext]? = nil) {
        self.context = context
        self.mergingContexts = mergingContexts
        super.init()
    }
    
    override func main() {
        guard let querySnapshot = self.querySnapshot else { return }
        let addedDocuments = querySnapshot.documentChanges.filter({ $0.type == .added }).map({ $0.document })
        guard !isCancelled else { return }
        self.markTCNsAsPotentiallyInfectious(from: addedDocuments)
    }

    // swiftlint:disable:next function_body_length
    private func markTCNsAsPotentiallyInfectious(
        from queryDocumentSnapshots: [QueryDocumentSnapshot]
    ) {
        guard !queryDocumentSnapshots.isEmpty else { return }
        self.context.performAndWait { [weak self] in
            do {
                guard let self = self else { return }
                
                try queryDocumentSnapshots.forEach { (snapshot) in
                    guard !self.isCancelled else { return }
                    
                    let snapshotData = snapshot.data()
                    
                    if let temporaryContactKeyBytes = snapshotData[Firestore.Fields.temporaryContactKeyBytes] as? Data,
                        let endIndex = snapshotData[Firestore.Fields.endIndex] as? UInt16,
                        let memoData = snapshotData[Firestore.Fields.memoData] as? Data,
                        let memoType = snapshotData[Firestore.Fields.memoType] as? UInt8,
                        let reportVerificationPublicKeyBytes = snapshotData[Firestore.Fields
                            .reportVerificationPublicKeyBytes] as? Data,
                        let signatureBytes = snapshotData[Firestore.Fields.signatureBytes] as? Data,
                        let startIndex = snapshotData[Firestore.Fields.startIndex] as? UInt16 {
                        
                        let report = Report(
                            reportVerificationPublicKeyBytes: reportVerificationPublicKeyBytes,
                            temporaryContactKeyBytes: temporaryContactKeyBytes,
                            startIndex: startIndex,
                            endIndex: endIndex,
                            memoType: MemoType(rawValue: memoType
                                ) ?? MemoType.CovidWatchV1, memoData: memoData)
                        
                        let signedReport = TCNSignedReport(report: report, signatureBytes: signatureBytes)
                        
                        let signatureBytesBase64EncodedString = signedReport.signatureBytes.base64EncodedString()
                        do {
                            _ = try signedReport.verify()
                            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "Source integrity verification for signed report (\(signatureBytesBase64EncodedString)) succeeded"))
                        } catch {
                            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Source integrity verification for signed report (\(signatureBytesBase64EncodedString) failed: \(error)"))
                            return
                        }
                        
                        let managedSignedReport = SignedReport(context: context)
                        managedSignedReport.isProcessed = false
                        managedSignedReport.configure(with: signedReport)
                        
                        // Long-running operation
                        let recomputedTemporaryContactNumbers = signedReport.report.getTemporaryContactNumbers()
                        
                        guard !self.isCancelled else { return }
                        
                        let identifiers: [Data] = recomputedTemporaryContactNumbers.compactMap({ $0.bytes })
                        
                        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "Marking \(identifiers.count) temporary contact numbers(s) as potentially infectious=true ..."))
                        
                        var allUpdatedObjectIDs = [NSManagedObjectID]()
                        try identifiers.chunked(into: 300000).forEach { (identifiers) in
                            guard !self.isCancelled else { return }
                            let batchUpdateRequest = NSBatchUpdateRequest(entity: TemporaryContactNumber.entity())
                            batchUpdateRequest.predicate = NSPredicate(format: "bytes IN %@", identifiers, true)
                            batchUpdateRequest.resultType = .updatedObjectIDsResultType
                            batchUpdateRequest.propertiesToUpdate = [
                                "wasPotentiallyInfectious": true
                            ]
                            if let batchUpdateResult = try context.execute(batchUpdateRequest) as? NSBatchUpdateResult,
                                let updatedObjectIDs = batchUpdateResult.result as? [NSManagedObjectID] {
                                allUpdatedObjectIDs.append(contentsOf: updatedObjectIDs)
                            }
                        }
                        
                        managedSignedReport.isProcessed = true
                        
                        if !allUpdatedObjectIDs.isEmpty, let mergingContexts = self.mergingContexts {
                            NSManagedObjectContext.mergeChanges(
                                fromRemoteContextSave: [NSUpdatedObjectsKey: allUpdatedObjectIDs],
                                into: mergingContexts
                            )
                        }
                        
                        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "Marked \(identifiers.count) temporary contact number(s) as potentially infectious=true"))
                    }
                }
            } catch {
                if let self = self {
                    LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Marking temporary contact number(s) as potentially infectious=true failed: \(error)"))
                }
            }
        }
    }
}
