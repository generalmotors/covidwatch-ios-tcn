//
//  GetTCNModel.swift
//  CovidWatch iOS
//
//  Created by Jennifer Moll on 6/23/20.
//

struct GetTCNModel: Codable {
    let beaconId: String
    let tcnBase64: String

    enum CodingKeys: String, CodingKey {
        case beaconId = "beacon_id"
        case tcnBase64 = "tcn_base64"
    }
}
