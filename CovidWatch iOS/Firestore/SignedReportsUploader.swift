//
//  Created by Zsombor Szabo on 05/04/2020.
//

import Foundation
import CoreData
import Firebase

open class SignedReportsUploader: NSObject, NSFetchedResultsControllerDelegate, URLSessionDataDelegate {
    
    private var fetchedResultsController: NSFetchedResultsController<SignedReport>
    
    private var db: Firestore = AppDelegate.getFirestore()
    
    override init() {
        let managedObjectContext = PersistentContainer.shared.viewContext
        let request: NSFetchRequest<SignedReport> = SignedReport.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SignedReport.uploadState, ascending: false)]
        request.returnsObjectsAsFaults = false
        request.predicate = NSPredicate(format: "uploadState == %d", UploadState.notUploaded.rawValue)
        self.fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        super.init()

        self.fetchedResultsController.delegate = self
        do {
            try self.fetchedResultsController.performFetch()
            self.uploadSignedReportsIfNeeded()
        } catch {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Fetched results controller perform fetch failed: \(error)"))
        }
    }
    
    private func uploadSignedReportsIfNeeded() {
        guard let fetchedObjects = self.fetchedResultsController.fetchedObjects else { return }
        let toUpload = fetchedObjects.filter({ $0.uploadState == UploadState.notUploaded.rawValue })
        self.uploadSignedReports(toUpload)
    }

    // swiftlint:disable:next function_body_length
    private func uploadSignedReports(_ signedReports: [SignedReport]) {
        guard !signedReports.isEmpty else { return }

        signedReports.forEach { (signedReport) in

            let signatureBytesBase64EncodedString = signedReport.signatureBytes?.base64EncodedString() ?? ""
            
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "Uploading signed report (\(signatureBytesBase64EncodedString))..."))
            signedReport.uploadState = UploadState.uploading.rawValue

            // get url to submit to
            let apiUrlString = getAPIUrl(getAppScheme())
            if let submitReportUrl = URL(string: "\(apiUrlString)/submitReport") {
                // build correct payload
                let reportUpload = ReportUpload(
                    temporaryContactKeyBytes: signedReport.temporaryContactKeyBytes,
                    startIndex: signedReport.startIndex,
                    endIndex: signedReport.endIndex,
                    memoData: signedReport.memoData,
                    memoType: signedReport.memoType,
                    signatureBytes: signedReport.signatureBytes,
                    reportVerificationPublicKeyBytes: signedReport.reportVerificationPublicKeyBytes
                )

                // set encoding to base64 and snake_case
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                encoder.dataEncodingStrategy = .base64

                guard let uploadData = try? encoder.encode(reportUpload) else {
                    LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Failed to encode signed report (\(reportUpload))"))
                    signedReport.uploadState = UploadState.notUploaded.rawValue
                    return // failed to encode so bail out
                }

                var request = URLRequest(url: submitReportUrl)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                URLSession.uploadTask(with: request, from: uploadData, delegate: self) { result in
                    switch result {
                    case .failure(let error):
                        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Uploading signed report (\(signatureBytesBase64EncodedString)) failed: \(error)"))
                        signedReport.uploadState = UploadState.notUploaded.rawValue
                    case .success(let (response, data)):
                        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "Uploaded signed report (\(signatureBytesBase64EncodedString))"))
                        signedReport.uploadState = UploadState.uploaded.rawValue

                        if let mimeType = response.mimeType,
                            mimeType == "application/json",
                            let dataString = String(data: data, encoding: .utf8) {
                            print("got data: \(dataString)")
                        }
                    }
                }.resume() // fire request
            }
        }
    }
    
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.uploadSignedReportsIfNeeded()
    }
    
    
    //MARK: URLSessionDataTask functions
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        completionHandler(nil)
    }
    
}

struct ReportUpload: Codable {
    let temporaryContactKeyBytes: Data?
    let startIndex: Int16
    let endIndex: Int16
    let memoData: Data?
    let memoType: Int16
    let signatureBytes: Data?
    let reportVerificationPublicKeyBytes: Data?
}

typealias HTTPResult = Result<(URLResponse, Data), Error>

extension URLSession {
    static func uploadTask(with: URLRequest, from: Data, delegate: URLSessionDataDelegate, result: @escaping (HTTPResult) -> Void) -> URLSessionDataTask {
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: OperationQueue.main)
        return session.uploadTask(with: with, from: from) { data, response, error in
            if let error = error {
                result(.failure(error))
                return
            }
            guard let response = response as? HTTPURLResponse,
            (200...299).contains(response.statusCode), let data = data else {
                let error = NSError(domain: "error", code: 0, userInfo: nil)
                result(.failure(error))
                return
            }
            result(.success((response, data)))
        }
    }
}
