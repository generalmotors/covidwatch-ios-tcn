//
//  GetTCNRequest.swift
//  CovidWatch iOS
//
//  Created by Zane Schepke on 6/23/20.
//  Copyright © 2020 IZE. All rights reserved.
//

struct GetTCNRequest: Request {
    let beaconId: String

    var path: String { "/api/v1/beacon_report/" + beaconId }
    var method: String { "GET" }

    var body: RequestBody? {
        return nil
    }
}
