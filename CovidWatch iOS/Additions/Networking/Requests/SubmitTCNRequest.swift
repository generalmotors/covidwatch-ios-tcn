//
//  SubmitTCNRequest.swift
//  CovidWatch iOS
//
//  Created by Zane Schepke on 6/23/20.
//  Copyright © 2020 IZE. All rights reserved.
//

struct SubmitTCNRequest: Request {
    let beaconId: String
    let tcnBase64: String

    var path: String { "/api/v1/beacon_report" }
    var method: String { "POST" }

    var body: RequestBody? {
        return SubmitTCNRequestBody(beaconId: beaconId,
                                            tcnBase64: tcnBase64)
    }
}

struct SubmitTCNRequestBody: RequestBody {

    let beaconId: String
    let tcnBase64: String

    enum CodingKeys: String, CodingKey {
        case beaconId = "beacon_id"
        case tcnBase64 = "tcn_base64"
    }

    func toJSONData() -> Data? {
        let encoder = JSONEncoder()

        return try? encoder.encode(self)
    }
}

