//
//  GetDistanceProfileRequest.swift
//  CovidWatch
//
//  Created by Joseph Licari on 7/1/20.
//

import Foundation

struct GetDistanceProfileRequest: Request {
    
    let modelId: String

    var path: String { "/api/v1/phone_profile/\(self.modelId)" }
    var method: String { "GET" }

    var body: RequestBody? {
        return nil
    }
    
}
