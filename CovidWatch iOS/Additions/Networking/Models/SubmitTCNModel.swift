//
//  SubmitTCNModel.swift
//  CovidWatch iOS
//
//  Created by Zane Schepke on 6/23/20.
//  Copyright © 2020 IZE. All rights reserved.
//

struct SubmitTCNModel: Codable {
    let beaconId: String
    let tcnBase64: String

    enum CodingKeys: String, CodingKey {
        case beaconId = "beacon_id"
        case tcnBase64 = "tcn_base64"
    }
}
