//
//  Created by Zsombor Szabo on 25/03/2020.
//

import Foundation

extension TCNBluetoothServiceImpl {
    
    func didFindTCN(_ tcn: Data, estimatedDistance: Double? = nil, deviceId: UInt32?) {
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Did find TCN=\(tcn.base64EncodedString()) at estimated distance=\(String(format: "%.2f", estimatedDistance ?? -1.0))"))
        self.service?.tcnFinder(tcn, estimatedDistance, deviceId ?? 0)
    }
    
    func generateTCN() -> Data {
        let tcn = self.service?.tcnGenerator()
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, type: .bluetooth, message: "Did generate TCN=\(tcn?.base64EncodedString() ?? "")"))
        return tcn ?? Data()
    }
    
}
